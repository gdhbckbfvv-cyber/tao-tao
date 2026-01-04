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

    // MARK: - 私有属性

    private let locationManager = CLLocationManager()

    /// 路径追踪定时器
    private var trackingTimer: Timer?

    /// 上次记录的位置（用于距离判断）
    private var lastRecordedLocation: CLLocationCoordinate2D?

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
            return
        }

        print("")
        print("🎯 ========== 开始圈地 ==========")
        print("   清空路径坐标")
        print("   启动 2 秒定时器")
        print("================================")

        // 重置路径数据
        pathCoordinates = []
        lastRecordedLocation = nil
        pathUpdateVersion = 0
        isTracking = true

        // 如果当前有位置，立即添加第一个点
        if let currentLocation = userLocation {
            pathCoordinates.append(currentLocation)
            lastRecordedLocation = currentLocation
            pathUpdateVersion += 1
            print("📍 添加起点: (\(currentLocation.latitude), \(currentLocation.longitude))")
        }

        // 启动定时器（每 2 秒检查一次）
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("✅ 圈地已开始")
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

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 检查当前位置
        guard let currentLocation = userLocation else {
            print("⚠️ Timer 回调：当前位置为空，跳过记录")
            return
        }

        // 如果是第一个点，直接记录
        guard let lastLocation = lastRecordedLocation else {
            pathCoordinates.append(currentLocation)
            lastRecordedLocation = currentLocation
            pathUpdateVersion += 1
            print("📍 记录第一个路径点: (\(currentLocation.latitude), \(currentLocation.longitude))")
            return
        }

        // 计算距离（单位：米）
        let distance = calculateDistance(from: lastLocation, to: currentLocation)

        // 如果距离 > 10 米，记录新点
        if distance > 10 {
            pathCoordinates.append(currentLocation)
            lastRecordedLocation = currentLocation
            pathUpdateVersion += 1

            print("📍 记录新路径点:")
            print("   坐标: (\(currentLocation.latitude), \(currentLocation.longitude))")
            print("   距离上一点: \(String(format: "%.1f", distance))m")
            print("   总路径点数: \(pathCoordinates.count)")
        } else {
            print("⏭️ Timer 回调：距离不足 10 米(\(String(format: "%.1f", distance))m)，跳过记录")
        }
    }

    /// 计算两点之间的距离（米）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
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
