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
import UIKit

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

    // MARK: - 验证状态属性（Day17）

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 上传状态属性（Day18）

    /// 是否正在上传领地
    @Published var isUploadingTerritory: Bool = false

    /// 上传成功标志
    @Published var territoryUploadSuccess: Bool = false

    /// 上传错误信息
    @Published var territoryUploadError: String? = nil

    // MARK: - 冲突检测属性（Day19）

    /// 是否正在检测冲突
    @Published var isCheckingConflict: Bool = false

    /// 是否检测到领地冲突
    @Published var hasConflict: Bool = false

    /// 冲突错误信息
    @Published var conflictError: String? = nil

    /// 领地预警级别（Day19: 使用新的 5 级系统）
    @Published var warningLevel: WarningLevel = .safe

    /// 距离最近领地的距离（米）
    @Published var distanceToNearestTerritory: Double = Double.infinity

    /// 最近的领地信息
    @Published var nearestTerritory: Territory? = nil

    // MARK: - 私有属性

    private let locationManager = CLLocationManager()

    /// 当前位置（Timer 采点用）
    private var currentLocation: CLLocation?

    /// 最新的完整位置信息（供 ExplorationManager 使用，包含精度、速度、时间戳）
    @Published var lastCLLocation: CLLocation?

    /// 路径追踪定时器（每2秒记录一次路径点）
    private var trackingTimer: Timer?

    /// 碰撞检测定时器（Day19: 每10秒检测一次预警级别）
    private var collisionCheckTimer: Timer?

    /// 上次记录的位置（用于距离判断）
    private var lastRecordedLocation: CLLocationCoordinate2D?

    /// 震动反馈生成器（Day19）
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// 上次预警级别（用于判断是否需要震动）
    private var lastWarningLevel: WarningLevel = .safe

    /// 上次位置的时间戳（用于速度检测）
    private var lastLocationTimestamp: Date?

    /// 开始圈地的时间（Day18，用于上传）
    private var territoryStartTime: Date?

    // MARK: - 常量配置

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数（闭环检测前提）
    private let minimumPathPoints: Int = 10

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 初始化

    private override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度
        locationManager.distanceFilter = 10 // 移动 10 米才更新位置

        // 🆕 后台定位配置
        // 注意：allowsBackgroundLocationUpdates = true 需要在 Xcode 中启用
        // "Background Modes" -> "Location updates" 能力，否则会崩溃
        // locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

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

    /// 请求定位权限（始终允许，支持后台定位）
    func requestPermission() {
        print("📍 请求定位权限...")
        // 先请求 WhenInUse，然后请求 Always（iOS 要求的流程）
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse {
            // 已有 WhenInUse 权限，请求升级到 Always
            locationManager.requestAlwaysAuthorization()
        }
    }

    /// 请求始终定位权限（用于后台位置上报）
    func requestAlwaysPermission() {
        print("📍 请求始终定位权限...")
        locationManager.requestAlwaysAuthorization()
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

        // 检查当前位置是否存在
        guard let currentCoordinate = userLocation else {
            print("⚠️ 当前位置不可用，无法开始圈地")
            locationError = "定位信息不可用，请稍候重试"
            TerritoryLogger.shared.log("当前位置不可用，无法开始圈地", type: .error)
            return
        }

        print("")
        print("🎯 ========== 开始圈地 ==========")
        print("   起始点: (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")
        print("   开始检测领地冲突...")
        print("================================")

        // Day19: 检测起始点是否在他人领地内（使用新的 CollisionDetector）
        isCheckingConflict = true
        hasConflict = false
        conflictError = nil

        Task { @MainActor in
            // 加载他人的领地
            guard let otherTerritories = try? await TerritoryManager.shared.loadOthersActiveTerritories() else {
                print("⚠️ 无法加载他人领地，允许圈地")
                isCheckingConflict = false
                startTrackingAfterConflictCheck()
                return
            }

            // 使用新的 CollisionDetector 检测起点
            let result = CollisionDetector.checkPointCollision(
                point: currentCoordinate,
                territories: otherTerritories
            )

            isCheckingConflict = false

            if result.warningLevel == .violation {
                // 检测到冲突，阻止圈地
                hasConflict = true
                conflictError = "起始点位于他人领地内，无法在此圈地"

                print("❌ 检测到领地冲突，取消圈地")
                print("   冲突领地 ID: \(result.nearestTerritory?.id ?? "未知")")
                TerritoryLogger.shared.log(
                    "起始点位于他人领地内（ID: \(result.nearestTerritory?.id ?? "未知")），圈地已取消",
                    type: .error
                )

                // 5秒后自动隐藏错误提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.hasConflict = false
                    self.conflictError = nil
                }

                return
            }

            // 未检测到冲突，继续圈地
            print("✅ 起点检测通过，开始圈地")
            if result.distance != Double.infinity {
                print("   距离最近领地: \(String(format: "%.1f", result.distance))m（级别: \(result.warningLevel.description)）")
            }
            TerritoryLogger.shared.log("起点碰撞检测通过，开始圈地追踪", type: .info)

            startTrackingAfterConflictCheck()
        }
    }

    /// 冲突检测通过后开始追踪（Day19）
    private func startTrackingAfterConflictCheck() {
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

        // 重置验证状态（Day17）
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置上传状态（Day18）
        isUploadingTerritory = false
        territoryUploadSuccess = false
        territoryUploadError = nil
        territoryStartTime = Date() // 记录开始时间

        // 重置冲突检测状态（Day19）
        hasConflict = false
        conflictError = nil
        warningLevel = .safe
        distanceToNearestTerritory = Double.infinity
        nearestTerritory = nil
        lastWarningLevel = .safe

        // 准备震动反馈生成器（Day19）
        hapticGenerator.prepare()

        // 启动路径追踪定时器（每 2 秒记录一次路径点）
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        // 启动碰撞检测定时器（Day19: 每 10 秒检测一次预警级别）
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkCollision()
        }

        // 立即进行一次碰撞检测
        checkCollision()

        print("✅ 圈地已开始，等待第一次定位...")
        print("   路径追踪：每2秒记录一次")
        print("   碰撞检测：每10秒检测一次")
    }

    /// 停止路径追踪（结束圈地）
    func stopPathTracking() {
        print("")
        print("🛑 ========== 结束圈地 ==========")
        print("   路径点数量: \(pathCoordinates.count)")
        print("   停止定时器并重置所有状态")
        print("================================")

        // 停止追踪
        isTracking = false
        trackingTimer?.invalidate()
        trackingTimer = nil

        // 停止碰撞检测定时器（Day19）
        stopCollisionCheckTimer()

        // 清空路径数据
        pathCoordinates = []
        lastRecordedLocation = nil
        pathUpdateVersion = 0
        isPathClosed = false

        // 重置速度检测数据
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置上传状态
        isUploadingTerritory = false
        territoryUploadSuccess = false
        territoryUploadError = nil
        territoryStartTime = nil

        // 重置冲突检测状态（Day19）
        isCheckingConflict = false
        hasConflict = false
        conflictError = nil

        // 重置预警状态
        warningLevel = .safe
        distanceToNearestTerritory = Double.infinity
        nearestTerritory = nil

        print("✅ 圈地已结束，所有状态已重置")
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

        // 清除验证状态（Day17）
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

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

        // Day19: 实时路径碰撞检测（使用新的 CollisionDetector）
        Task { @MainActor in
            // 加载他人的领地
            guard let otherTerritories = try? await TerritoryManager.shared.loadOthersActiveTerritories() else {
                // 无法加载领地，继续记录点（不阻塞圈地）
                recordPointAfterConflictCheck(coordinate: currentCoordinate, location: location)
                return
            }

            // ✅ 改进：同时检测点的预警级别和路径冲突
            // 先检测当前点的预警级别
            let pointResult = CollisionDetector.checkPointCollision(
                point: currentCoordinate,
                territories: otherTerritories
            )

            // 更新预警状态（即使在圈地过程中也显示预警）
            warningLevel = pointResult.warningLevel
            distanceToNearestTerritory = pointResult.distance
            nearestTerritory = pointResult.nearestTerritory

            // 根据预警级别决定是否停止
            if pointResult.warningLevel == .violation {
                // 违规：立即停止圈地
                let errorMsg = "路径进入他人领地，圈地已停止"

                print("❌ 路径冲突检测：进入他人领地！")
                print("   当前点: (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")
                print("   冲突领地 ID: \(pointResult.nearestTerritory?.id ?? "未知")")

                TerritoryLogger.shared.log(
                    "路径进入他人领地（ID: \(pointResult.nearestTerritory?.id ?? "未知")），圈地已停止",
                    type: .error
                )

                // 触发震动反馈
                triggerHapticFeedback(for: .violation)

                // 先停止圈地（会清除冲突状态）
                stopPathTracking()

                // 再设置冲突状态（这样才不会被清除）
                hasConflict = true
                conflictError = errorMsg

                // 5秒后自动隐藏错误提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.hasConflict = false
                    self.conflictError = nil
                }

                return
            }

            // ✅ 如果有预警（danger/caution/notice），显示预警但继续记录
            switch pointResult.warningLevel {
            case .danger:
                print("⚠️ 路径检测：危险区域，距离他人领地 \(String(format: "%.1f", pointResult.distance))m")
                triggerHapticFeedback(for: .danger)
            case .caution:
                print("⚠️ 路径检测：警告区域，距离他人领地 \(String(format: "%.1f", pointResult.distance))m")
                triggerHapticFeedback(for: .caution)
            case .notice:
                print("ℹ️ 路径检测：发现附近领地，距离 \(String(format: "%.1f", pointResult.distance))m")
                triggerHapticFeedback(for: .notice)
            case .safe:
                // 安全，不显示预警
                break
            case .violation:
                // 已经在上面处理了
                break
            }

            // ✅ 只有在非安全区时，才检测路径穿越
            if pointResult.warningLevel != .safe && pointResult.warningLevel != .violation {
                // 检测路径是否穿越领地边界
                if let lastPoint = lastRecordedLocation {
                    let pathResult = CollisionDetector.checkPathCrossTerritory(
                        lineStart: lastPoint,
                        lineEnd: currentCoordinate,
                        territories: otherTerritories
                    )

                    if pathResult.hasCollision && pathResult.crossesTerritory {
                        // 路径穿越边界，立即停止
                        let errorMsg = "路径穿越他人领地边界，圈地已停止"

                        print("❌ 路径冲突检测：穿越领地边界！")
                        print("   线段: (\(lastPoint.latitude), \(lastPoint.longitude)) → (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")
                        print("   冲突领地 ID: \(pathResult.conflictTerritory?.id ?? "未知")")

                        TerritoryLogger.shared.log(
                            "路径穿越他人领地边界（ID: \(pathResult.conflictTerritory?.id ?? "未知")），圈地已停止",
                            type: .error
                        )

                        // 触发震动反馈
                        triggerHapticFeedback(for: .violation)

                        // 先停止圈地
                        stopPathTracking()

                        // 再设置冲突状态
                        hasConflict = true
                        conflictError = errorMsg

                        // 5秒后自动隐藏错误提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.hasConflict = false
                            self.conflictError = nil
                        }

                        return
                    }
                }
            }

            // 未检测到冲突，继续记录点
            recordPointAfterConflictCheck(coordinate: currentCoordinate, location: location)
        }
    }

    /// 冲突检测通过后记录路径点
    private func recordPointAfterConflictCheck(coordinate: CLLocationCoordinate2D, location: CLLocation) {
        // 如果是第一个点，直接记录
        guard let lastLocation = lastRecordedLocation else {
            pathCoordinates.append(coordinate)
            lastRecordedLocation = coordinate
            lastLocationTimestamp = location.timestamp
            pathUpdateVersion += 1
            print("📍 记录第一个路径点: (\(coordinate.latitude), \(coordinate.longitude))")

            // 记录日志：记录起点
            TerritoryLogger.shared.log("记录起点（第1个点）", type: .info)
            return
        }

        // 计算距离（单位：米）
        let distance = calculateDistance(from: lastLocation, to: coordinate)

        // 如果距离 > 10 米，记录新点
        if distance > 10 {
            pathCoordinates.append(coordinate)
            lastRecordedLocation = coordinate
            lastLocationTimestamp = location.timestamp
            pathUpdateVersion += 1

            print("📍 记录新路径点:")
            print("   坐标: (\(coordinate.latitude), \(coordinate.longitude))")
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

            // Day17: 闭环成功后，自动进行领地验证
            let validationResult = validateTerritory()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage

            // 如果验证通过，保存面积（不自动上传，等待用户确认）
            if validationResult.isValid {
                calculatedArea = calculatePolygonArea()
                print("✅ 领地验证通过，面积: \(String(format: "%.0f", calculatedArea))m²")
                print("   等待用户确认登记...")
            } else {
                // 验证失败：停止追踪，防止继续记录点
                calculatedArea = 0
                print("❌ 领地验证失败，自动停止圈地")
                print("   失败原因: \(validationResult.errorMessage ?? "未知错误")")

                TerritoryLogger.shared.log(
                    "领地验证失败: \(validationResult.errorMessage ?? "未知错误")，已停止圈地",
                    type: .error
                )

                // 延迟 3 秒后停止追踪（让用户看到错误提示）
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    // 只停止追踪，保留路径数据供用户查看
                    self.isTracking = false
                    self.trackingTimer?.invalidate()
                    self.trackingTimer = nil
                    print("🛑 追踪已停止（保留路径数据）")
                }
            }
        } else {
            print("⏭️ 闭环检测失败：距离起点 \(String(format: "%.1f", distanceToStart))m > \(closureDistanceThreshold)m")
        }
    }

    /// 验证移动速度（防作弊）（Day16）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // ✅ 使用 GPS 原生速度（单位：米/秒）
        // 注意：speed < 0 表示无效数据
        guard newLocation.speed >= 0 else {
            print("⚠️ 速度检测：GPS 速度无效，跳过")
            return true
        }

        // 转换为 km/h（米/秒 * 3.6 = 公里/小时）
        let speedKmh = newLocation.speed * 3.6

        print("🚗 速度检测（GPS原生）:")
        print("   瞬时速度: \(String(format: "%.1f", speedKmh)) km/h")
        print("   位置时间: \(newLocation.timestamp)")

        // 速度 > 30 km/h：严重超速，停止追踪
        if speedKmh > 30 {
            speedWarning = "速度过快 (\(String(format: "%.1f", speedKmh)) km/h)，已暂停圈地"
            isOverSpeed = true
            print("❌ 严重超速 (>30 km/h)，停止追踪")

            // 记录日志：超速停止
            TerritoryLogger.shared.log(
                "超速 \(String(format: "%.1f", speedKmh)) km/h，已自动停止圈地",
                type: .error
            )

            stopPathTracking()
            return false
        }

        // 速度 > 15 km/h：轻度超速，显示警告但继续追踪
        if speedKmh > 15 {
            speedWarning = "移动速度过快 (\(String(format: "%.1f", speedKmh)) km/h)，请慢行"
            isOverSpeed = true
            print("⚠️ 轻度超速 (>15 km/h)，显示警告")

            // 记录日志：速度警告
            TerritoryLogger.shared.log(
                "速度较快 \(String(format: "%.1f", speedKmh)) km/h，请慢行",
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

    // MARK: - 距离与面积计算（Day17）

    /// 计算路径总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 计算多边形面积（平方米，使用鞋带公式，考虑地球曲率）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000 // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count] // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测（Day17）

    /// 判断两条线段是否相交（CCW 算法 + 容错机制）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                    p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {

        // ✅ 容错阈值：如果交点距离任意端点太近，不算真正的自交（米）
        // 这可以过滤掉 GPS 精度导致的"抖动"误判
        let toleranceDistance: Double = 5.0

        /// CCW 辅助函数：判断三点是否呈逆时针方向
        /// - Parameters:
        ///   - A: 第一个点
        ///   - B: 第二个点
        ///   - C: 第三个点
        /// - Returns: 叉积 > 0 则为逆时针
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Double {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct
        }

        // ✅ 增强的 CCW 判断：引入容差避免浮点数精度问题
        func ccwSign(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Int {
            let cp = ccw(A, B, C)
            let epsilon = 1e-10  // 浮点数容差
            if abs(cp) < epsilon {
                return 0  // 共线
            }
            return cp > 0 ? 1 : -1
        }

        // 判断逻辑：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        let d1 = ccwSign(p1, p3, p4)
        let d2 = ccwSign(p2, p3, p4)
        let d3 = ccwSign(p1, p2, p3)
        let d4 = ccwSign(p1, p2, p4)

        // 基本相交判断
        let basicIntersect = (d1 != d2 && d1 != 0 && d2 != 0) && (d3 != d4 && d3 != 0 && d4 != 0)

        if !basicIntersect {
            return false
        }

        // ✅ 容错检查：如果线段端点距离太近，不算自交（可能是 GPS 抖动）
        let distances = [
            calculateDistance(from: p1, to: p3),
            calculateDistance(from: p1, to: p4),
            calculateDistance(from: p2, to: p3),
            calculateDistance(from: p2, to: p4)
        ]

        let minDistance = distances.min() ?? Double.infinity

        if minDistance < toleranceDistance {
            // 距离太近，不算真正的自交
            print("🔍 自交容错：线段距离太近（\(String(format: "%.1f", minDistance))m < \(toleranceDistance)m），忽略")
            return false
        }

        return true
    }

    /// 检测路径是否自相交（画"8"字形则失败）
    /// - Returns: true 表示有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（增加到3，更宽松）
        let skipHeadCount = 3
        let skipTailCount = 3

        print("🔍 开始自交检测：共 \(segmentCount) 条线段")

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // ✅ 必须间隔至少2条线段才比较（避免相邻线段）
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 修复：正确跳过首尾线段的比较
                // 如果 i 是前面的线段，并且 j 是后面的线段，应该跳过
                // 因为闭环时首尾本来就应该接近
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                // ✅ 修复逻辑：只要是首尾线段的组合就跳过
                if isHeadSegment && isTailSegment {
                    print("  ⏭️ 跳过首尾线段比较：线段\(i)-\(i+1) vs 线段\(j)-\(j+1)")
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    print("❌ 检测到自交：线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交")
                    print("   线段1: (\(String(format: "%.6f", p1.latitude)), \(String(format: "%.6f", p1.longitude))) → (\(String(format: "%.6f", p2.latitude)), \(String(format: "%.6f", p2.longitude)))")
                    print("   线段2: (\(String(format: "%.6f", p3.latitude)), \(String(format: "%.6f", p3.longitude))) → (\(String(format: "%.6f", p4.latitude)), \(String(format: "%.6f", p4.longitude)))")

                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        print("✅ 自交检测通过：无交叉")
        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证（Day17）

    /// 综合验证领地是否符合规则
    /// - Returns: (isValid: 验证是否通过, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let errorMsg = "点数不足: \(pointCount)个点 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(errorMsg) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(errorMsg) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        // 注意：hasPathSelfIntersection 内部已经记录了日志

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(errorMsg) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 全部通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }

    // MARK: - 领地上传（Day18）

    // MARK: - 碰撞检测（Day19）

    /// 碰撞检测（定时器回调，每10秒检测一次）
    private func checkCollision() {
        guard let currentCoordinate = userLocation else {
            print("⚠️ 碰撞检测：当前位置为空，跳过")
            return
        }

        print("🔍 ========== 碰撞检测 ==========")
        print("   当前位置: (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")

        Task { @MainActor in
            // 加载他人的领地
            guard let otherTerritories = try? await TerritoryManager.shared.loadOthersActiveTerritories() else {
                print("⚠️ 无法加载他人领地，跳过检测")
                return
            }

            // 使用新的 CollisionDetector 进行点碰撞检测
            let result = CollisionDetector.checkPointCollision(
                point: currentCoordinate,
                territories: otherTerritories
            )

            // 更新预警状态
            warningLevel = result.warningLevel
            distanceToNearestTerritory = result.distance
            nearestTerritory = result.nearestTerritory

            // 根据预警级别采取行动
            switch result.warningLevel {
            case .violation:
                // 违规：立即停止圈地
                print("❌ 违规！立即停止圈地")
                TerritoryLogger.shared.log(
                    "碰撞检测：进入他人领地（ID: \(result.nearestTerritory?.id ?? "未知")），圈地已停止",
                    type: .error
                )

                // 触发震动反馈
                triggerHapticFeedback(for: .violation)

                // 先停止圈地（会清除冲突状态）
                stopPathTracking()

                // 再设置冲突状态（这样才不会被清除）
                hasConflict = true
                conflictError = "进入他人领地，圈地已停止"

                // 5秒后自动隐藏错误提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.hasConflict = false
                    self.conflictError = nil
                }

            case .danger:
                print("⚠️ 危险：距离他人领地仅 \(String(format: "%.1f", result.distance))m")
                TerritoryLogger.shared.log(
                    "碰撞检测：距离他人领地 \(String(format: "%.1f", result.distance))m，请注意",
                    type: .warning
                )
                // 触发震动反馈
                triggerHapticFeedback(for: .danger)

            case .caution:
                print("⚠️ 警告：距离他人领地 \(String(format: "%.1f", result.distance))m")
                // 触发震动反馈
                triggerHapticFeedback(for: .caution)

            case .notice:
                print("ℹ️ 提醒：发现附近领地，距离 \(String(format: "%.1f", result.distance))m")
                // 触发震动反馈
                triggerHapticFeedback(for: .notice)

            case .safe:
                if result.distance != Double.infinity {
                    print("✅ 安全：距离他人领地 \(String(format: "%.1f", result.distance))m")
                } else {
                    print("✅ 安全：附近无他人领地")
                }
                // safe 级别不需要震动
            }

            print("================================")
        }
    }

    /// 停止碰撞检测定时器（Day19）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        print("⏹️ 碰撞检测定时器已停止")
    }

    /// 触发震动反馈（Day19）
    /// - Parameter level: 预警级别
    private func triggerHapticFeedback(for level: WarningLevel) {
        // 只有级别变化时才触发震动（避免重复震动）
        guard level != lastWarningLevel else { return }

        lastWarningLevel = level

        // 准备震动生成器
        hapticGenerator.prepare()

        // 根据级别强度触发震动
        let intensity = CGFloat(level.hapticIntensity)

        if intensity > 0 {
            hapticGenerator.impactOccurred(intensity: intensity)
            print("📳 触发震动反馈：\(level.description)（强度: \(String(format: "%.1f", intensity))）")
        }
    }

    /// 上传领地到数据库（供外部调用）
    func uploadTerritory() {
        // 检查必要条件
        guard let startTime = territoryStartTime else {
            print("⚠️ 缺少开始时间，无法上传")
            return
        }

        guard !pathCoordinates.isEmpty else {
            print("⚠️ 路径为空，无法上传")
            return
        }

        guard calculatedArea > 0 else {
            print("⚠️ 面积为0，无法上传")
            return
        }

        // 标记正在上传
        isUploadingTerritory = true
        territoryUploadError = nil

        print("📤 开始上传领地到数据库...")
        TerritoryLogger.shared.log("开始上传领地到数据库", type: .info)

        // 异步上传
        Task { @MainActor in
            do {
                try await TerritoryManager.shared.uploadTerritory(
                    coordinates: pathCoordinates,
                    area: calculatedArea,
                    startTime: startTime
                )

                // 上传成功
                isUploadingTerritory = false
                territoryUploadSuccess = true
                territoryUploadError = nil

                print("✅ 领地上传成功！")
                TerritoryLogger.shared.log("领地上传成功！面积: \(Int(self.calculatedArea))m²", type: .success)

                // 延迟 2 秒后自动停止追踪（让用户看到成功提示）
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.stopPathTracking()
                }

            } catch {
                // 上传失败
                isUploadingTerritory = false
                territoryUploadSuccess = false
                territoryUploadError = error.localizedDescription

                print("❌ 领地上传失败: \(error.localizedDescription)")
                TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            }
        }
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
            self.lastCLLocation = location  // 更新完整的位置信息
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
