//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置坐标
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = LocationManager()

    // MARK: - Published 属性

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位权限状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪属性

    /// 是否正在追踪路径（圈地中）
    @Published var isTracking: Bool = false

    /// 路径坐标点数组
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用）
    @Published var isPathClosed: Bool = false

    /// 速度警告信息（Day16）
    @Published var speedWarning: String?

    /// 是否超速（Day16）
    @Published var isOverSpeed: Bool = false

    // MARK: - 私有属性

    private let locationManager = CLLocationManager()

    /// 当前位置（Timer 采点用）
    private var currentLocation: CLLocation?

    /// 路径追踪定时器
    private var trackingTimer: Timer?

    /// 上次记录的位置（用于距离判断）
    private var lastRecordedLocation: CLLocationCoordinate2D?

    /// 上次位置的时间戳（用于速度检测）
    private var lastLocationTimestamp: Date?

    // MARK: - 常量配置

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数（闭环检测前提）
    private let minimumPathPoints: Int = 10

    // MARK: - 初始化

    private override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度
        locationManager.distanceFilter = 10 // 移动 10 米才更新位置

        // 获取当前授权状态（延迟获取，避免初始化时崩溃）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = self.locationManager.authorizationStatus
            print("🌍 LocationManager 初始化完成")
            print("   当前授权状态: \(self.authorizationStatus.description)")
        }
    }

    // MARK: - 计算属性

    /// 是否已授权定位
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse ||
               authorizationStatus == .authorizedAlways
    }

    /// 是否被拒绝定位权限
    var isDenied: Bool {
        return authorizationStatus == .denied ||
               authorizationStatus == .restricted
    }

    // MARK: - 公开方法

    /// 请求定位权限（使用 App 期间）
    func requestPermission() {
        print("📍 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始更新位置")
            locationError = "定位权限未授权"
            return
        }

        print("📍 开始更新位置...")
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("📍 停止更新位置")
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪（开始圈地）
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ 未授权定位，无法开始圈地")
            locationError = "定位权限未授权"
            TerritoryLogger.shared.log("未授权定位，无法开始圈地", type: .error)
            return
        }

        print("")
        print("🎯 ========== 开始圈地 ==========")
        print("   清空路径坐标")
        print("   启动 2 秒定时器")
        print("================================")

        // 记录日志：开始圈地
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 重置路径数据
        pathCoordinates = []
        lastRecordedLocation = nil
        pathUpdateVersion = 0
        isTracking = true
        isPathClosed = false

        // 重置速度检测数据（Day16）
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // 启动定时器（每 2 秒检查一次）
        // 注意：不在这里立即添加起点，让定时器第一次回调时添加，确保有完整的 CLLocation 对象（含时间戳）
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("✅ 圈地已开始，等待第一次定位...")
    }

    /// 停止路径追踪（结束圈地）
    func stopPathTracking() {
        print("")
        print("🛑 ========== 结束圈地 ==========")
        print("   路径点数量: \(pathCoordinates.count)")
        print("   停止定时器")
        print("================================")

        isTracking = false
        trackingTimer?.invalidate()
        trackingTimer = nil

        print("✅ 圈地已结束")
    }

    /// 清除路径数据
    func clearPath() {
        print("🧹 清除路径数据")
        pathCoordinates = []
        lastRecordedLocation = nil
        pathUpdateVersion = 0
        isPathClosed = false

        // 清除速度检测数据（Day16）
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        print("✅ 路径已清除")
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 检查当前位置（使用 currentLocation 而不是 userLocation）
        guard let location = currentLocation else {
            print("⚠️ Timer 回调：当前位置为空，跳过记录")
            return
        }

        // Day16: 速度检测（如果超速则不记录）
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ 速度检测失败，跳过记录此点")
            return
        }

        let currentCoordinate = location.coordinate

        // 如果是第一个点，直接记录
        guard let lastLocation = lastRecordedLocation else {
            pathCoordinates.append(currentCoordinate)
            lastRecordedLocation = currentCoordinate
            lastLocationTimestamp = location.timestamp // Day16: 记录时间戳
            pathUpdateVersion += 1
            print("📍 记录第一个路径点: (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")

            // 记录日志：记录起点
            TerritoryLogger.shared.log("记录起点（第1个点）", type: .info)
            return
        }

        // 计算距离（单位：米）
        let distance = calculateDistance(from: lastLocation, to: currentCoordinate)

        // 如果距离 > 10 米，记录新点
        if distance > 10 {
            pathCoordinates.append(currentCoordinate)
            lastRecordedLocation = currentCoordinate
            lastLocationTimestamp = location.timestamp // Day16: 更新时间戳
            pathUpdateVersion += 1

            print("📍 记录新路径点:")
            print("   坐标: (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")
            print("   距离上一点: \(String(format: "%.1f", distance))m")
            print("   总路径点数: \(pathCoordinates.count)")

            // 记录日志：记录新点
            TerritoryLogger.shared.log(
                "记录第\(pathCoordinates.count)个点，距上点 \(String(format: "%.1f", distance))m",
                type: .info
            )
        } else {
            print("⏭️ Timer 回调：距离不足 10 米(\(String(format: "%.1f", distance))m)，跳过记录")
        }

        // Day16: 无论是否记录新点，都检查闭环（重要！回到起点时距离可能<10米）
        checkPathClosure()
    }

    /// 计算两点之间的距离（米）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 检查路径是否形成闭环（Day16）
    private func checkPathClosure() {
        // 如果已经闭环，不重复检查
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("⏭️ 闭环检测：路径点不足 \(minimumPathPoints) 个（当前 \(pathCoordinates.count) 个）")
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let distanceToStart = calculateDistance(from: currentPoint, to: startPoint)

        print("🔍 闭环检测:")
        print("   起点: (\(startPoint.latitude), \(startPoint.longitude))")
        print("   当前点: (\(currentPoint.latitude), \(currentPoint.longitude))")
        print("   距离起点: \(String(format: "%.1f", distanceToStart))m")
        print("   阈值: \(closureDistanceThreshold)m")

        // 判断是否形成闭环
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1 // 触发 UI 更新

            print("✅ 闭环检测成功！")
            print("   路径已形成闭环")
            print("   总路径点数: \(pathCoordinates.count)")

            // 记录日志：闭环成功
            TerritoryLogger.shared.log(
                "闭环成功！距起点 \(String(format: "%.1f", distanceToStart))m，共 \(pathCoordinates.count) 个点",
                type: .success
            )
        } else {
            print("⏭️ 闭环检测失败：距离起点 \(String(format: "%.1f", distanceToStart))m > \(closureDistanceThreshold)m")
        }
    }

    /// 验证移动速度（防作弊）（Day16）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点，直接通过
        guard let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = lastRecordedLocation else {
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = lastLocation.distance(from: newLocation)

        // 计算时间差（秒）
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)

        // 防止除零错误
        guard timeInterval > 0 else {
            print("⚠️ 速度检测：时间差为 0，跳过")
            return true
        }

        // 计算速度（km/h）
        let speed = (distance / timeInterval) * 3.6

        print("🚗 速度检测:")
        print("   距离: \(String(format: "%.1f", distance))m")
        print("   时间差: \(String(format: "%.1f", timeInterval))s")
        print("   速度: \(String(format: "%.1f", speed)) km/h")

        // 速度 > 30 km/h：严重超速，停止追踪
        if speed > 30 {
            speedWarning = "速度过快 (\(String(format: "%.1f", speed)) km/h)，已暂停圈地"
            isOverSpeed = true
            print("❌ 严重超速 (>\(30) km/h)，停止追踪")

            // 记录日志：超速停止
            TerritoryLogger.shared.log(
                "超速 \(String(format: "%.1f", speed)) km/h，已自动停止圈地",
                type: .error
            )

            stopPathTracking()
            return false
        }

        // 速度 > 15 km/h：轻度超速，显示警告但继续追踪
        if speed > 15 {
            speedWarning = "移动速度过快 (\(String(format: "%.1f", speed)) km/h)，请慢行"
            isOverSpeed = true
            print("⚠️ 轻度超速 (>\(15) km/h)，显示警告")

            // 记录日志：速度警告
            TerritoryLogger.shared.log(
                "速度较快 \(String(format: "%.1f", speed)) km/h，请慢行",
                type: .warning
            )

            return false
        }

        // 速度正常，清除警告
        speedWarning = nil
        isOverSpeed = false
        print("✅ 速度正常")
        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            print("🌍 定位授权状态变化: \(self.authorizationStatus.description)")

            // 如果已授权，自动开始定位
            if self.isAuthorized {
                self.startUpdatingLocation()
            }
        }
    }

    /// 位置更新成功
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            // ⚠️ 关键：必须更新 currentLocation，Timer 需要用这个！
            self.currentLocation = location
            self.userLocation = location.coordinate
            self.locationError = nil

            print("📍 位置更新成功:")
            print("   纬度: \(location.coordinate.latitude)")
            print("   经度: \(location.coordinate.longitude)")
            print("   精度: \(location.horizontalAccuracy)m")
        }
    }

    /// 位置更新失败
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
            print("❌ 定位失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLAuthorizationStatus 扩展

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用期间允许"
        @unknown default:
            return "未知状态"
        }
    }
}
