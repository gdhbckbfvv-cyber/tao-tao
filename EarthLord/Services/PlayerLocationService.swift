//
//  PlayerLocationService.swift
//  EarthLord
//
//  玩家位置服务
//  负责位置上报、附近玩家查询和密度计算
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 玩家密度等级

/// 玩家密度等级
enum PlayerDensityLevel: String {
    case solo = "独行者"      // 0人
    case low = "低密度"       // 1-5人
    case medium = "中密度"    // 6-20人
    case high = "高密度"      // 20人以上

    /// 根据附近玩家数量返回建议的POI显示数量
    var suggestedPOICount: Int {
        switch self {
        case .solo: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 20  // 或更多
        }
    }

    /// 从玩家数量创建密度等级
    static func from(playerCount: Int) -> PlayerDensityLevel {
        switch playerCount {
        case 0: return .solo
        case 1...5: return .low
        case 6...20: return .medium
        default: return .high
        }
    }
}

// MARK: - RPC 参数结构体

/// 查询附近玩家的参数
private struct NearbyPlayersParams: @unchecked Sendable {
    let p_latitude: Double
    let p_longitude: Double
    let p_radius_meters: Int
    let p_exclude_player_id: String
}

extension NearbyPlayersParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
        try container.encode(p_radius_meters, forKey: .p_radius_meters)
        try container.encode(p_exclude_player_id, forKey: .p_exclude_player_id)
    }

    private enum CodingKeys: String, CodingKey {
        case p_latitude, p_longitude, p_radius_meters, p_exclude_player_id
    }
}

// MARK: - 玩家位置服务

/// 玩家位置服务 - 负责位置上报和附近玩家查询
@MainActor
class PlayerLocationService: ObservableObject {

    // MARK: - 单例

    static let shared = PlayerLocationService()

    // MARK: - Published 属性

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityLevel: PlayerDensityLevel = .solo

    /// 是否正在上报
    @Published var isReporting: Bool = false

    /// 最后上报时间
    @Published var lastReportTime: Date?

    /// 最后错误信息
    @Published var lastError: String?

    // MARK: - 私有属性

    /// 位置上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// Supabase 客户端
    private let supabase = SupabaseConfig.shared

    /// 是否处于后台模式
    private var isBackgroundMode: Bool = false

    // MARK: - 常量配置

    /// 前台上报间隔（秒）
    private let reportIntervalSeconds: TimeInterval = 30

    /// 后台上报间隔（秒）
    private let backgroundReportIntervalSeconds: TimeInterval = 60

    /// 显著移动距离阈值（米）
    private let significantDistanceMeters: Double = 50

    /// 默认查询半径（米）
    private let defaultRadiusMeters: Int = 1000

    // MARK: - 初始化

    private init() {
        print("📍 [PlayerLocationService] 初始化")
    }

    // MARK: - 位置上报

    /// 开始定期位置上报
    func startLocationReporting() {
        print("📍 [PlayerLocationService] 开始位置上报")

        // 停止现有定时器
        stopLocationReporting()

        // 立即上报一次
        Task {
            await reportCurrentLocation()
        }

        // 设置定时器
        let interval = isBackgroundMode ? backgroundReportIntervalSeconds : reportIntervalSeconds
        reportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reportCurrentLocation()
            }
        }

        print("📍 [PlayerLocationService] 定时器已启动，间隔: \(interval)秒")
    }

    /// 停止位置上报
    func stopLocationReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
        print("📍 [PlayerLocationService] 位置上报已停止")
    }

    /// 设置后台模式
    func setBackgroundMode(_ enabled: Bool) {
        print("📍 [PlayerLocationService] 后台模式: \(enabled)")
        isBackgroundMode = enabled

        // 重新设置定时器以调整上报频率
        if reportTimer != nil {
            startLocationReporting()
        }
    }

    /// 上报当前位置
    func reportCurrentLocation() async {
        guard let location = LocationManager.shared.userLocation else {
            lastError = "无法获取当前位置"
            print("⚠️ [PlayerLocationService] 无法获取当前位置")
            return
        }

        // 检查是否移动超过50米（如果不是首次上报）
        if let lastLocation = lastReportedLocation {
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude))

            // 未移动超过50米，跳过上报（除非是定时强制上报）
            if distance < significantDistanceMeters {
                print("📍 [PlayerLocationService] 未移动超过50米，跳过上报")
                return
            }
        }

        await reportLocation(latitude: location.latitude, longitude: location.longitude)
    }

    /// 上报指定位置
    func reportLocation(latitude: Double, longitude: Double) async {
        isReporting = true
        defer { isReporting = false }

        do {
            // 获取当前用户 ID
            let session = try await supabase.auth.session
            let userId = session.user.id

            print("📍 [PlayerLocationService] 上报位置: (\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)))")

            // 构建上报数据
            struct LocationData: Encodable {
                let player_id: String
                let latitude: Double
                let longitude: Double
                let location: String
                let is_online: Bool
                let last_updated: String
            }

            let data = LocationData(
                player_id: userId.uuidString,
                latitude: latitude,
                longitude: longitude,
                location: "POINT(\(longitude) \(latitude))",
                is_online: true,
                last_updated: ISO8601DateFormatter().string(from: Date())
            )

            // 使用 upsert 更新或插入位置
            try await supabase
                .from("player_locations")
                .upsert(data)
                .execute()

            // 更新状态
            lastReportedLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            lastReportTime = Date()
            lastError = nil

            print("✅ [PlayerLocationService] 位置上报成功")

        } catch {
            lastError = "位置上报失败: \(error.localizedDescription)"
            print("❌ [PlayerLocationService] 位置上报失败: \(error)")
        }
    }

    /// 标记玩家离线
    func markOffline() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            try await supabase
                .from("player_locations")
                .update(["is_online": false])
                .eq("player_id", value: userId.uuidString)
                .execute()

            print("✅ [PlayerLocationService] 已标记为离线")

        } catch {
            print("❌ [PlayerLocationService] 标记离线失败: \(error)")
        }
    }

    // MARK: - 附近玩家查询

    /// 查询附近玩家数量
    func queryNearbyPlayerCount(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int? = nil
    ) async -> Int {
        let radius = radiusMeters ?? defaultRadiusMeters

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            print("🔍 [PlayerLocationService] 查询附近玩家: 位置(\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))), 半径\(radius)m")

            // 构建 RPC 参数
            let params = NearbyPlayersParams(
                p_latitude: latitude,
                p_longitude: longitude,
                p_radius_meters: radius,
                p_exclude_player_id: userId.uuidString
            )

            // 调用数据库函数
            let response = try await supabase
                .rpc("count_nearby_players", params: params)
                .execute()

            // 解析返回的数量
            if let count = try? JSONDecoder().decode(Int.self, from: response.data) {
                nearbyPlayerCount = count
                densityLevel = PlayerDensityLevel.from(playerCount: count)
                print("✅ [PlayerLocationService] 附近玩家数量: \(count), 密度等级: \(densityLevel.rawValue)")
                return count
            }

            return 0

        } catch {
            print("❌ [PlayerLocationService] 查询附近玩家失败: \(error)")
            lastError = "查询失败: \(error.localizedDescription)"
            return 0
        }
    }

    /// 获取当前位置的密度等级和建议POI数量
    func getDensityInfo() async -> (level: PlayerDensityLevel, suggestedPOICount: Int) {
        guard let location = LocationManager.shared.userLocation else {
            print("⚠️ [PlayerLocationService] 无法获取位置，返回默认密度")
            return (.solo, 1)
        }

        let count = await queryNearbyPlayerCount(
            latitude: location.latitude,
            longitude: location.longitude
        )

        let level = PlayerDensityLevel.from(playerCount: count)
        return (level, level.suggestedPOICount)
    }
}
