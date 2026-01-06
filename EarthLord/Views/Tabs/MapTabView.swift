//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示真实地图、用户位置、定位功能
//

import SwiftUI
import MapKit
import CoreLocation

struct MapTabView: View {

    // MARK: - 状态管理

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 是否已完成首次定位居中
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅（Day17）
    @State private var showValidationBanner = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 地图视图
            if locationManager.isAuthorized {
                MapViewRepresentable(
                    userLocation: $locationManager.userLocation,
                    hasLocatedUser: $hasLocatedUser,
                    trackingPath: $locationManager.pathCoordinates,
                    pathUpdateVersion: locationManager.pathUpdateVersion,
                    isTracking: locationManager.isTracking,
                    isPathClosed: locationManager.isPathClosed // Day16: 传入闭环状态
                )
                .ignoresSafeArea()
            } else {
                // 未授权时显示占位视图
                unauthorizedView
            }

            // 顶部标题栏
            VStack {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("地图")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    // 定位状态指示器
                    if locationManager.isAuthorized {
                        locationStatusIndicator
                    }
                }
                .padding()
                .background(
                    ApocalypseTheme.background
                        .opacity(0.9)
                        .blur(radius: 10)
                )

                // Day16: 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // Day17: 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                }

                Spacer()
            }

            // 右下角定位按钮
            if locationManager.isAuthorized {
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        locationButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 100) // 为圈地按钮留出空间
                    }
                }
            }

            // 底部中间圈地按钮
            if locationManager.isAuthorized {
                VStack {
                    Spacer()

                    HStack {
                        Spacer()
                        territoryButton
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            }

            // 圈地状态卡片（圈地中时显示）
            if locationManager.isTracking {
                trackingStatusCard
            }

            // 权限被拒绝时的提示卡片
            if locationManager.isDenied {
                permissionDeniedCard
            }
        }
        .onAppear {
            handleLocationPermission()
        }
        // Day17: 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - 子视图

    /// 未授权时的占位视图
    private var unauthorizedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.primary)

            Text("需要定位权限")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("《地球新主》需要获取您的位置\n来显示您在末日世界中的坐标")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: {
                locationManager.requestPermission()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("授予定位权限")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    /// 定位状态指示器
    private var locationStatusIndicator: some View {
        HStack(spacing: 6) {
            // 定位精度图标
            if locationManager.userLocation != nil {
                Circle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: 8, height: 8)

                Text("定位中")
                    .font(.caption)
                    .foregroundColor(.white)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .scaleEffect(0.8)

                Text("搜索位置...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
        )
    }

    /// 右下角定位按钮
    private var locationButton: some View {
        Button(action: {
            centerMapToUserLocation()
        }) {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.title2)
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
    }

    /// 圈地按钮（胶囊型）
    private var territoryButton: some View {
        Button(action: {
            toggleTerritoryTracking()
        }) {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.body)
                    .foregroundColor(.white)

                if locationManager.isTracking {
                    Text("停止圈地")
                        .font(.headline)
                        .foregroundColor(.white)

                    // 显示当前点数
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("开始圈地")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.success)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
    }

    /// 速度警告横幅（Day16）
    private var speedWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.white)

            if let warning = locationManager.speedWarning {
                Text(warning)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(locationManager.isTracking ? Color.orange : Color.red)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: locationManager.speedWarning)
        .onAppear {
            // 3 秒后自动隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                locationManager.speedWarning = nil
            }
        }
    }

    /// 验证结果横幅（Day17：根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 圈地状态卡片
    private var trackingStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("圈地中...")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // 路径点数量
                Text("\(locationManager.pathCoordinates.count) 点")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // 进度指示器
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ApocalypseTheme.primary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(locationManager.pathUpdateVersion % 3 == index ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: locationManager.pathUpdateVersion)
                }

                Text("每 2 秒记录位置")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // 提示信息
            Text("沿着您想要圈定的区域边界行走")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// 权限被拒绝时的提示卡片
    private var permissionDeniedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.warning)

            Text("定位权限被拒绝")
                .font(.headline)
                .foregroundColor(.white)

            Text("无法显示您在地图上的位置\n请在设置中允许定位权限")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: {
                openAppSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("前往设置")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }

    // MARK: - 方法

    /// 处理定位权限逻辑
    private func handleLocationPermission() {
        print("🗺️ MapTabView 加载，检查定位权限...")

        if locationManager.authorizationStatus == .notDetermined {
            // 首次打开，请求权限
            print("📍 首次打开，请求定位权限")
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            // 已授权，开始定位
            print("✅ 已授权，开始定位")
            locationManager.startUpdatingLocation()
        } else {
            // 被拒绝或受限
            print("⚠️ 定位权限被拒绝")
        }
    }

    /// 将地图居中到用户位置
    private func centerMapToUserLocation() {
        print("🎯 用户点击定位按钮，尝试居中地图...")

        guard locationManager.userLocation != nil else {
            print("⚠️ 用户位置为空，无法居中")
            return
        }

        // 通过修改 hasLocatedUser 触发地图重新居中
        // （这是一个技巧：临时设置为 false，让 MapViewRepresentable 重新居中）
        hasLocatedUser = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hasLocatedUser = true
        }

        print("✅ 已触发地图居中")
    }

    /// 打开系统设置
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// 切换圈地追踪状态
    private func toggleTerritoryTracking() {
        if locationManager.isTracking {
            // 正在追踪，点击停止
            print("🛑 用户点击停止圈地")
            locationManager.stopPathTracking()
        } else {
            // 未追踪，点击开始
            print("🎯 用户点击开始圈地")
            locationManager.startPathTracking()
        }
    }

    /// 计算当前位置到起点的距离
    private func calculateDistanceToStart() -> Double {
        guard let startPoint = locationManager.pathCoordinates.first,
              let currentPoint = locationManager.pathCoordinates.last else {
            return 0
        }

        let fromLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let toLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
