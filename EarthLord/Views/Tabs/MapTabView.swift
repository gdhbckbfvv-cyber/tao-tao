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

    /// 已保存的领地列表（Day19）
    @State private var savedTerritories: [Territory] = []

    /// 是否正在加载领地（Day19）
    @State private var isLoadingTerritories = false

    /// 当前用户ID（Day19：用于区分自己的领地和别人的领地）
    @State private var currentUserId: String = ""

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 探索结果数据
    @State private var explorationResult: ExplorationResult?

    /// POI 列表（物品点）
    @State private var pois: [POI] = []

    /// 建筑管理器（Day29：主地图显示建筑）
    @StateObject private var buildingManager = BuildingManager.shared

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
                    isPathClosed: locationManager.isPathClosed, // Day16: 传入闭环状态
                    savedTerritories: $savedTerritories, // Day19: 传入已保存的领地
                    currentUserId: currentUserId, // Day19: 传入当前用户ID
                    pois: $pois, // POI 列表（物品点）
                    buildings: $buildingManager.playerBuildings, // Day29: 建筑列表
                    buildingTemplates: buildingManager.templateDict // Day29: 建筑模板
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

                // Day19: 冲突检测中横幅
                if locationManager.isCheckingConflict {
                    conflictCheckingBanner
                }

                // Day19: 冲突警告横幅（最高优先级）
                if locationManager.hasConflict, let error = locationManager.conflictError {
                    conflictWarningBanner(error: error)
                }

                // Day19: 分级预警横幅（圈地中显示）
                if locationManager.isTracking && !locationManager.hasConflict {
                    warningLevelBanner
                }

                // Day16: 速度警告横幅（圈地）
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // 探索速度警告横幅
                if explorationManager.isExploring && explorationManager.speedWarning != nil {
                    explorationSpeedWarningBanner
                }

                // Day17: 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                }

                // Day18: 确认登记按钮（验证通过后显示）
                if locationManager.territoryValidationPassed &&
                   !locationManager.isUploadingTerritory &&
                   !locationManager.territoryUploadSuccess {
                    confirmTerritoryButton
                }

                // Day18: 上传状态横幅
                if locationManager.isUploadingTerritory {
                    uploadingBanner
                } else if locationManager.territoryUploadSuccess {
                    uploadSuccessBanner
                } else if let error = locationManager.territoryUploadError {
                    uploadErrorBanner(error: error)
                }

                Spacer()
            }

            // 左上角坐标显示框
            if locationManager.isAuthorized, let location = locationManager.userLocation {
                VStack {
                    HStack {
                        coordinateDisplay(location: location)
                        Spacer()
                    }
                    .padding(.top, 100) // 在顶部标题栏下方
                    .padding(.horizontal, 16)
                    Spacer()
                }
            }

            // 底部按钮组（圈地、定位、探索）- 仅在未探索时显示
            if locationManager.isAuthorized && !explorationManager.isExploring {
                VStack {
                    Spacer()

                    HStack(spacing: 20) {
                        // 左侧：圈地按钮
                        territoryButton

                        // 中间：定位按钮
                        locationButton

                        // 右侧：探索按钮
                        exploreButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }

            // 底部探索状态卡片（探索中时显示）
            if explorationManager.isExploring {
                VStack {
                    Spacer()
                    explorationStatusCard
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
            loadCurrentUserId() // Day19: 加载当前用户ID
            loadSavedTerritories() // Day19: 加载已保存的领地
            loadPOIs() // 加载 POI 数据
        }
        // 监听用户位置变化，首次获取到位置时加载附近 POI
        .onReceive(locationManager.$userLocation) { newLocation in
            // 只在首次获取到位置且 POI 列表为空时加载
            if newLocation != nil && pois.isEmpty && !explorationManager.isExploring {
                loadPOIs()
            }
        }
        // Day19: 监听上传成功，重新加载领地
        .onReceive(locationManager.$territoryUploadSuccess) { success in
            if success {
                loadSavedTerritories()
            }
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

            // 🆕 POI 接近弹窗（高优先级覆盖层）
            if explorationManager.showProximityPopup, let poi = explorationManager.nearbyPOI {
                POIProximityPopup(
                    poi: poi,
                    onScavenge: {
                        try await explorationManager.scavengePOI(poi)
                    },
                    onDismiss: {
                        explorationManager.showProximityPopup = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        // 探索结果页面 sheet
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(result: result)
            } else {
                // 备用：显示假数据（防止崩溃）
                ExplorationResultView(result: MockExplorationData.mockExplorationResult)
            }
        }
        // 🆕 POI 搜刮结果 sheet
        .sheet(isPresented: $explorationManager.showScavengeResult) {
            if let poi = explorationManager.nearbyPOI {
                ScavengeResultView(
                    poi: poi,
                    items: explorationManager.scavengedItems
                )
            }
        }
        // 监听探索失败（超速）
        .onChange(of: explorationManager.explorationResult) { result in
            if let error = result?.error {
                // 如果是超速失败，自动弹出结果页面
                if error.code == "OVERSPEED" {
                    explorationResult = result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showExplorationResult = true
                    }
                }
            }
        }
        // 🆕 监听 POI 列表变化，自动更新地图标记
        .onReceive(explorationManager.$discoveredPOIs) { newPOIs in
            pois = newPOIs
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

    /// 左上角坐标显示框
    private func coordinateDisplay(location: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("当前坐标")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Text("\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
        )
    }

    /// 底部探索状态卡片
    private var explorationStatusCard: some View {
        VStack(spacing: 0) {
            // 上半部分：探索信息
            VStack(spacing: 16) {
                // 第一行：状态 + 时间
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("探索进行中")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatDuration(explorationManager.currentDuration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }

                // 第二行：距离（大字体）+ 奖励等级
                HStack(alignment: .bottom) {
                    // 左侧：行走距离
                    VStack(alignment: .leading, spacing: 4) {
                        Text("行走距离")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        HStack(alignment: .bottom, spacing: 2) {
                            Text("\(Int(explorationManager.currentDistance))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("m")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.bottom, 8)
                        }
                    }

                    Spacer()

                    // 右侧：奖励等级 + 物品数
                    VStack(alignment: .trailing, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("奖励等级")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(currentRewardTier.rawValue)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(rewardTierColor)
                        }

                        Text("\(currentItemCount) 件物品")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // 进度条
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))

                            // 进度
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rewardTierColor)
                                .frame(width: geo.size.width * progressToNextTier)
                        }
                    }
                    .frame(height: 8)

                    // 进度提示文字
                    Text(progressHintText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.1, green: 0.15, blue: 0.1))
            )

            // 停止探索按钮
            Button(action: {
                performExploration()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.body)
                    Text("停止探索")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
            }
            .cornerRadius(0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // 留出 tab bar 空间
    }

    /// 格式化时长为 m:ss 格式
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 当前奖励等级
    private var currentRewardTier: RewardTier {
        let distance = explorationManager.currentDistance
        switch distance {
        case 0..<200: return .none
        case 200..<500: return .bronze
        case 500..<1000: return .silver
        case 1000..<2000: return .gold
        default: return .diamond
        }
    }

    /// 当前物品数（根据等级预估）
    private var currentItemCount: Int {
        switch currentRewardTier {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 奖励等级颜色
    private var rewardTierColor: Color {
        switch currentRewardTier {
        case .none: return .gray
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2) // 铜色
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8) // 银色
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0) // 金色
        case .diamond: return Color(red: 0.6, green: 0.8, blue: 1.0) // 钻石蓝
        }
    }

    /// 到下一等级的进度（0-1）
    private var progressToNextTier: CGFloat {
        let distance = explorationManager.currentDistance
        switch distance {
        case 0..<200: return CGFloat(distance / 200)
        case 200..<500: return CGFloat((distance - 200) / 300)
        case 500..<1000: return CGFloat((distance - 500) / 500)
        case 1000..<2000: return CGFloat((distance - 1000) / 1000)
        default: return 1.0
        }
    }

    /// 进度提示文字
    private var progressHintText: String {
        let distance = explorationManager.currentDistance
        switch distance {
        case 0..<200:
            return "再走 \(Int(200 - distance)) 米升级到 铜级"
        case 200..<500:
            return "再走 \(Int(500 - distance)) 米升级到 银级"
        case 500..<1000:
            return "再走 \(Int(1000 - distance)) 米升级到 金级"
        case 1000..<2000:
            return "再走 \(Int(2000 - distance)) 米升级到 钻石级"
        default:
            return "已达最高等级！"
        }
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

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            centerMapToUserLocation()
        }) {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
    }

    /// 探索按钮
    private var exploreButton: some View {
        Button(action: {
            performExploration()
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: explorationManager.isExploring ? "stop.fill" : "binoculars.fill")
                        .font(.body)
                        .foregroundColor(.white)

                    Text(explorationManager.isExploring ? "探索" : "探索")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                // 显示当前距离（探索时显示）
                if explorationManager.isExploring && explorationManager.currentDistance > 0 {
                    Text("\(Int(explorationManager.currentDistance))m")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(explorationManager.isExploring ? Color.orange : ApocalypseTheme.primary)
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

    /// 冲突检测中横幅（Day19）
    private var conflictCheckingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)

            Text("正在检测领地冲突...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: locationManager.isCheckingConflict)
    }

    /// 分级预警横幅（Day19）
    @ViewBuilder
    private var warningLevelBanner: some View {
        let level = locationManager.warningLevel
        let distance = locationManager.distanceToNearestTerritory

        // 只在非安全状态下显示横幅
        if level != .safe {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: iconForLevel(level))
                    .font(.title3)
                    .foregroundColor(.white)

                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleForLevel(level))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if distance != Double.infinity && distance != 0 {
                        Text("距离他人领地 \(String(format: "%.0f", distance))m")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorForLevel(level))
            )
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: level)
        }
    }

    /// 根据预警级别返回图标（Day19: 5 级系统）
    private func iconForLevel(_ level: WarningLevel) -> String {
        switch level {
        case .safe: return "checkmark.shield.fill"
        case .notice: return "info.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        case .violation: return "xmark.octagon.fill"
        }
    }

    /// 根据预警级别返回标题（Day19: 5 级系统）
    private func titleForLevel(_ level: WarningLevel) -> String {
        switch level {
        case .safe: return "安全区域"
        case .notice: return "提醒：发现附近领地"
        case .caution: return "警告：接近他人领地"
        case .danger: return "危险：距离过近"
        case .violation: return "违规：进入他人领地"
        }
    }

    /// 根据预警级别返回颜色（Day19: 5 级系统）
    private func colorForLevel(_ level: WarningLevel) -> Color {
        switch level {
        case .safe: return Color.green
        case .notice: return Color.blue
        case .caution: return Color.yellow
        case .danger: return Color.orange
        case .violation: return Color.red
        }
    }

    /// 冲突警告横幅（Day19）
    private func conflictWarningBanner(error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title3)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("领地冲突")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: locationManager.hasConflict)
    }

    /// 速度警告横幅（Day16 - 圈地）
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

    /// 探索速度警告横幅
    private var explorationSpeedWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.white)

            if let warning = explorationManager.speedWarning {
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
                .fill(explorationManager.isOverSpeed ? Color.red : Color.orange)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: explorationManager.speedWarning)
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

    /// 上传中横幅（Day18）
    private var uploadingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            Text("正在上传领地...")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.blue)
        .padding(.top, 100)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 上传成功横幅（Day18）
    private var uploadSuccessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)

            Text("领地上传成功！")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.green)
        .padding(.top, 100)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // 3秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    locationManager.territoryUploadSuccess = false
                }
            }
        }
    }

    /// 确认登记按钮（Day18）
    private var confirmTerritoryButton: some View {
        Button(action: {
            // 再次检查验证状态
            guard locationManager.territoryValidationPassed else {
                return
            }

            // 调用上传方法
            locationManager.uploadTerritory()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)

                Text("确认登记领地")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: Color.green.opacity(0.5), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 130)
        .transition(.scale.combined(with: .opacity))
    }

    /// 上传失败横幅（Day18）
    private func uploadErrorBanner(error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.body)

            Text("上传失败: \(error)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.red)
        .padding(.top, 100)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // 5秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    locationManager.territoryUploadError = nil
                }
            }
        }
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

    /// 加载当前用户ID（Day19）
    private func loadCurrentUserId() {
        Task {
            do {
                let userId = try await TerritoryManager.shared.getCurrentUserId()
                await MainActor.run {
                    currentUserId = userId
                    print("✅ 地图页面：获取当前用户ID - \(userId)")
                }
            } catch {
                print("❌ 地图页面：获取当前用户ID失败 - \(error.localizedDescription)")
            }
        }
    }

    /// 加载已保存的领地（Day19: 加载所有玩家的领地）
    private func loadSavedTerritories() {
        guard !isLoadingTerritories else { return }

        isLoadingTerritories = true

        Task {
            do {
                // 加载所有玩家的激活领地（包括自己的和别人的）
                let territories = try await TerritoryManager.shared.loadAllPlayersActiveTerritories()
                await MainActor.run {
                    savedTerritories = territories
                    isLoadingTerritories = false
                    print("✅ 地图页面：加载了所有玩家的 \(territories.count) 块领地")
                }
            } catch {
                await MainActor.run {
                    savedTerritories = []
                    isLoadingTerritories = false
                    print("❌ 地图页面：加载领地失败 - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 加载 POI 数据（基于用户当前位置搜索附近真实 POI）
    private func loadPOIs() {
        print("📍 加载POI数据...")

        // 需要用户位置才能搜索附近 POI
        guard let userLocation = locationManager.userLocation else {
            print("⚠️ 用户位置未知，等待定位后再加载 POI")
            return
        }

        Task {
            do {
                let nearbyPOIs = try await POISearchManager.shared.searchNearbyPOIs(
                    center: userLocation,
                    radius: 1000 // 搜索 1km 范围
                )
                await MainActor.run {
                    pois = nearbyPOIs
                    print("✅ 已加载 \(pois.count) 个附近 POI")
                }
            } catch {
                print("❌ POI搜索失败: \(error.localizedDescription)")
                // 搜索失败时使用空列表
                await MainActor.run {
                    pois = []
                }
            }
        }
    }

    /// 执行探索
    private func performExploration() {
        if explorationManager.isExploring {
            // 结束探索
            print("🔍 结束探索...")

            explorationManager.stopExploration { [self] result in
                // 保存探索结果
                self.explorationResult = result

                // 延迟一点点再弹出 sheet，让按钮状态先恢复
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.showExplorationResult = true
                    print("✅ 探索完成，显示探索结果")
                }
            }
        } else {
            // 开始探索
            print("🔍 开始探索附近区域...")
            explorationManager.startExploration()
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
