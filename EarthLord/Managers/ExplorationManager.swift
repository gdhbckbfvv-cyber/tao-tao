//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责追踪玩家行走距离、生成奖励、保存探索记录
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 探索管理器
class ExplorationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - Published 属性

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 探索结果（用于显示结果页面）
    @Published var explorationResult: ExplorationResult?

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - POI 搜刮相关属性

    /// 本次探索发现的所有 POI
    @Published var discoveredPOIs: [POI] = []

    /// 当前接近的 POI
    @Published var nearbyPOI: POI? = nil

    /// 是否显示接近弹窗
    @Published var showProximityPopup: Bool = false

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 当前搜刮的物品
    @Published var scavengedItems: [ExplorationResult.ItemLoot] = []

    // MARK: - 私有属性

    /// 探索开始时间
    private var explorationStartTime: Date?

    /// 探索开始位置
    private var explorationStartLocation: CLLocationCoordinate2D?

    /// 上次记录的位置（用于距离计算）
    private var lastRecordedLocation: CLLocation?

    /// 计时器（每秒更新时长）
    private var durationTimer: Timer?

    /// 超速开始时间（用于10秒倒计时）
    private var overSpeedStartTime: Date?

    /// 超速检测定时器
    private var overSpeedCheckTimer: Timer?

    /// LocationManager 引用
    private let locationManager = LocationManager.shared

    /// Supabase 客户端
    private let supabase = SupabaseConfig.shared

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    /// 已弹出提示的 POI ID集合（防止重复弹窗）
    private var alertedPOIIds: Set<String> = []

    /// 已搜刮的 POI ID集合
    private var scavengedPOIIds: Set<String> = []

    /// 上次检查接近度的时间（节流）
    private var lastProximityCheck: Date?

    // MARK: - 常量配置

    /// GPS 精度过滤阈值（米）
    private let accuracyThreshold: Double = 50.0

    /// 距离跳变过滤阈值（米）
    private let jumpDistanceThreshold: Double = 100.0

    /// 最大允许速度（米/秒）30km/h = 8.33 m/s
    private let maxAllowedSpeed: Double = 8.33

    /// 超速警告持续时长（秒）
    private let overSpeedWarningDuration: TimeInterval = 10.0

    // MARK: - 初始化

    private override init() {
        super.init()

        // 监听 LocationManager 的完整位置更新（包含精度、速度、时间戳）
        locationManager.$lastCLLocation
            .sink { [weak self] _ in
                self?.updateDistance()
            }
            .store(in: &cancellables)
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() {
        guard !isExploring else {
            print("⚠️ 探索已在进行中")
            return
        }

        guard locationManager.isAuthorized else {
            print("❌ 未授权定位，无法开始探索")
            return
        }

        guard let currentLocation = locationManager.userLocation else {
            print("❌ 当前位置不可用，无法开始探索")
            return
        }

        print("")
        print("🔍 ========== 开始探索 ==========")
        print("🔍 [探索] 起始点: (\(String(format: "%.6f", currentLocation.latitude)), \(String(format: "%.6f", currentLocation.longitude)))")
        print("🔍 [探索] 开始时间: \(Date())")
        print("================================")

        // 重置状态
        isExploring = true
        currentDistance = 0
        currentDuration = 0
        explorationStartTime = Date()
        explorationStartLocation = currentLocation
        lastRecordedLocation = locationManager.lastCLLocation  // 使用完整的 CLLocation
        explorationResult = nil
        speedWarning = nil
        isOverSpeed = false
        overSpeedStartTime = nil

        // ⚠️ 关键：启动 GPS 位置更新
        locationManager.startUpdatingLocation()
        print("📍 [探索] 已启动GPS位置更新")

        // 启动计时器（每秒更新时长）
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }

        // 🆕 搜索附近 POI（基于玩家密度）
        Task {
            do {
                // Step 1: 上报当前位置（确保自己被计入在线）
                await PlayerLocationService.shared.reportLocation(
                    latitude: currentLocation.latitude,
                    longitude: currentLocation.longitude
                )

                // Step 2: 获取密度信息
                let densityInfo = await PlayerLocationService.shared.getDensityInfo()
                let maxPOICount = densityInfo.suggestedPOICount

                print("🔍 [密度] 附近玩家: \(PlayerLocationService.shared.nearbyPlayerCount)人")
                print("🔍 [密度] 密度等级: \(densityInfo.level.rawValue), 建议POI数: \(maxPOICount)")

                // Step 3: 搜索 POI
                let allPOIs = try await POISearchManager.shared.searchNearbyPOIs(
                    center: currentLocation,
                    radius: 1000
                )

                // Step 4: 按距离排序，取前N个
                let sortedPOIs = allPOIs.sorted {
                    ($0.distanceFromUser ?? .infinity) < ($1.distanceFromUser ?? .infinity)
                }

                // 如果是独行者但附近没有POI，扩大搜索范围
                var displayPOIs: [POI]
                if sortedPOIs.isEmpty && densityInfo.level == .solo {
                    print("🔍 [POI] 附近无POI，扩大搜索范围到2公里")
                    let expandedPOIs = try await POISearchManager.shared.searchNearbyPOIs(
                        center: currentLocation,
                        radius: 2000
                    )
                    displayPOIs = Array(expandedPOIs.sorted {
                        ($0.distanceFromUser ?? .infinity) < ($1.distanceFromUser ?? .infinity)
                    }.prefix(1))
                } else {
                    displayPOIs = Array(sortedPOIs.prefix(maxPOICount))
                }

                await MainActor.run {
                    self.discoveredPOIs = displayPOIs
                    print("🔍 [POI] 显示 \(displayPOIs.count) / \(allPOIs.count) 个POI")
                }
            } catch {
                print("⚠️ [POI] 搜索失败: \(error.localizedDescription)")
            }
        }

        print("✅ [探索] 探索已开始，开始追踪GPS位置")
    }

    /// 停止探索并生成结果
    func stopExploration(completion: @escaping (ExplorationResult) -> Void) {
        guard isExploring else {
            print("⚠️ 探索未在进行中")
            return
        }

        print("")
        print("🛑 ========== 结束探索 ==========")
        print("🛑 [探索] 总距离: \(String(format: "%.1f", currentDistance))m")
        print("🛑 [探索] 总时长: \(Int(currentDuration))秒 (\(Int(currentDuration / 60))分\(Int(currentDuration) % 60)秒)")
        print("🛑 [探索] 结束时间: \(Date())")
        print("================================")

        // 停止所有计时器
        durationTimer?.invalidate()
        durationTimer = nil
        overSpeedCheckTimer?.invalidate()
        overSpeedCheckTimer = nil

        // 获取必要数据
        guard let startTime = explorationStartTime,
              let startLocation = explorationStartLocation,
              let endLocation = locationManager.userLocation else {
            print("❌ 缺少必要数据，无法生成探索结果")
            isExploring = false
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // 计算奖励等级
        let rewardTier = calculateRewardTier(distance: currentDistance)

        // 生成奖励物品
        let rewardItems = generateRewardItems(tier: rewardTier)

        print("🎁 [奖励] 奖励等级: \(rewardTier.rawValue)")
        print("🎁 [奖励] 奖励物品: \(rewardItems.count)种")
        for item in rewardItems {
            let qualityStr = item.quality?.rawValue ?? "无品质"
            print("🎁 [奖励]   - \(item.itemName) x\(item.quantity) [\(qualityStr)]")
        }

        // 构建探索结果
        let result = ExplorationResult(
            sessionId: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            duration: duration,

            // 行走数据
            distanceWalked: currentDistance,
            totalDistanceWalked: currentDistance, // TODO: 后续累加历史数据
            distanceRanking: Int.random(in: 10...100), // 假排名

            // 获得物品
            itemsFound: rewardItems,

            // 探索路径（暂时为空）
            pathCoordinates: [],

            // 无错误
            error: nil
        )

        self.explorationResult = result

        // 异步保存探索记录和添加物品到背包
        Task {
            do {
                // 保存探索记录
                try await saveExplorationSession(
                    startTime: startTime,
                    endTime: endTime,
                    duration: Int(duration),
                    startLat: startLocation.latitude,
                    startLon: startLocation.longitude,
                    endLat: endLocation.latitude,
                    endLon: endLocation.longitude,
                    totalDistance: currentDistance,
                    rewardTier: rewardTier.rawValue,
                    itemsRewarded: rewardItems
                )

                // 添加物品到背包
                try await InventoryManager.shared.addItems(rewardItems)

                print("✅ [数据库] 探索记录已保存")
                print("✅ [数据库] 物品已添加到背包")

            } catch {
                print("❌ [数据库] 保存探索记录失败: \(error.localizedDescription)")
            }
        }

        // 重置状态
        isExploring = false
        currentDistance = 0
        currentDuration = 0
        explorationStartTime = nil
        explorationStartLocation = nil
        lastRecordedLocation = nil

        // 🆕 清理 POI 状态
        discoveredPOIs = []
        nearbyPOI = nil
        showProximityPopup = false
        showScavengeResult = false
        scavengedItems = []
        alertedPOIIds.removeAll()
        scavengedPOIIds.removeAll()
        lastProximityCheck = nil

        // 停止 GPS 位置更新（节省电池）
        locationManager.stopUpdatingLocation()
        print("📍 [探索] 已停止GPS位置更新")

        // 回调结果
        completion(result)
    }

    // MARK: - 私有方法

    /// 更新距离（每次 GPS 更新时调用）
    private func updateDistance() {
        guard isExploring else { return }

        guard let newLocation = locationManager.lastCLLocation else {
            print("⚠️ [GPS] 当前位置为空")
            return
        }

        print("📍 [GPS] 收到位置更新: (\(String(format: "%.6f", newLocation.coordinate.latitude)), \(String(format: "%.6f", newLocation.coordinate.longitude)))")
        print("📍 [GPS] 精度: \(String(format: "%.1f", newLocation.horizontalAccuracy))m, 速度: \(String(format: "%.2f", newLocation.speed))m/s (\(String(format: "%.1f", newLocation.speed * 3.6))km/h)")

        // GPS 精度过滤
        guard newLocation.horizontalAccuracy > 0 && newLocation.horizontalAccuracy <= accuracyThreshold else {
            print("⚠️ [GPS] GPS 精度太差（\(String(format: "%.1f", newLocation.horizontalAccuracy))m），忽略此点")
            return
        }

        // 速度检测（使用 GPS 原生速度）
        checkSpeed(location: newLocation)

        // 如果是第一个点，直接记录
        guard let lastLocation = lastRecordedLocation else {
            lastRecordedLocation = newLocation
            print("✅ [GPS] 记录第一个探索点")
            return
        }

        // 计算距离
        let distance = newLocation.distance(from: lastLocation)
        let timeDiff = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)

        print("📍 [GPS] 与上一点距离: \(String(format: "%.1f", distance))m, 时间间隔: \(String(format: "%.1f", timeDiff))秒")

        // 距离跳变过滤
        guard distance <= jumpDistanceThreshold else {
            print("⚠️ [GPS] 距离跳变过大（\(String(format: "%.0f", distance))m > \(Int(jumpDistanceThreshold))m），忽略此点")
            return
        }

        // 时间间隔检查（至少1秒）
        guard timeDiff >= 1.0 else {
            print("⚠️ [GPS] 时间间隔太短（\(String(format: "%.1f", timeDiff))秒），忽略此点")
            return
        }

        // 累加距离（至少移动1米才累加）
        if distance >= 1.0 {
            currentDistance += distance
            lastRecordedLocation = newLocation
            print("✅ [距离] 累计距离: \(String(format: "%.1f", currentDistance))m (本次: +\(String(format: "%.1f", distance))m)")

            // 🆕 检查 POI 接近度
            checkPOIProximity(currentLocation: newLocation.coordinate)
        } else {
            print("⏭️ [距离] 移动距离不足1米（\(String(format: "%.1f", distance))m），跳过累加")
        }
    }

    /// 检测速度（防作弊）
    /// - Parameter location: 新位置
    private func checkSpeed(location: CLLocation) {
        // 使用 GPS 原生速度（单位：米/秒）
        guard location.speed >= 0 else {
            print("⚠️ [速度] GPS 速度无效，跳过检测")
            return
        }

        let speedKmh = location.speed * 3.6 // 转换为 km/h

        // 检测是否超速（> 30 km/h）
        if location.speed > maxAllowedSpeed {
            isOverSpeed = true
            speedWarning = "速度过快 (\(String(format: "%.1f", speedKmh)) km/h)，请减速慢行"

            print("⚠️ [速度] 检测到超速！当前速度: \(String(format: "%.1f", speedKmh)) km/h")

            // 如果是第一次超速，记录开始时间并启动倒计时
            if overSpeedStartTime == nil {
                overSpeedStartTime = Date()
                print("⚠️ [速度] 开始超速倒计时（10秒）")

                // 启动超速检测定时器（每秒检查一次）
                overSpeedCheckTimer?.invalidate()
                overSpeedCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.checkOverSpeedTimeout()
                }
            }
        } else {
            // 速度正常
            if isOverSpeed {
                print("✅ [速度] 速度已恢复正常: \(String(format: "%.1f", speedKmh)) km/h")
            }

            isOverSpeed = false
            speedWarning = nil
            overSpeedStartTime = nil

            // 停止超速检测定时器
            overSpeedCheckTimer?.invalidate()
            overSpeedCheckTimer = nil
        }
    }

    /// 检测超速是否超时（10秒）
    private func checkOverSpeedTimeout() {
        guard let startTime = overSpeedStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = overSpeedWarningDuration - elapsed

        print("⏱️ [速度] 超速持续: \(String(format: "%.0f", elapsed))秒，剩余: \(String(format: "%.0f", max(0, remaining)))秒")

        if elapsed >= overSpeedWarningDuration {
            // 超时，停止探索
            print("❌ [速度] 超速持续10秒，停止探索")

            // 停止计时器
            overSpeedCheckTimer?.invalidate()
            overSpeedCheckTimer = nil

            // 生成失败结果
            stopExplorationDueToOverSpeed()
        } else {
            // 更新警告信息，显示剩余时间
            speedWarning = "速度过快！\(Int(remaining))秒后将停止探索"
        }
    }

    /// 因超速停止探索
    private func stopExplorationDueToOverSpeed() {
        guard isExploring else { return }

        print("")
        print("🛑 ========== 探索失败（超速） ==========")
        print("❌ [探索] 原因：速度持续超过30km/h")
        print("❌ [探索] 行走距离: \(String(format: "%.1f", currentDistance))m")
        print("❌ [探索] 探索时长: \(Int(currentDuration))秒")
        print("================================")

        // 停止所有计时器
        durationTimer?.invalidate()
        durationTimer = nil
        overSpeedCheckTimer?.invalidate()
        overSpeedCheckTimer = nil

        // 获取必要数据
        guard let startTime = explorationStartTime,
              let startLocation = explorationStartLocation,
              let endLocation = locationManager.userLocation else {
            isExploring = false
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // 构建失败结果
        let result = ExplorationResult(
            sessionId: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            duration: duration,

            // 行走数据
            distanceWalked: currentDistance,
            totalDistanceWalked: currentDistance,
            distanceRanking: 0, // 失败时排名为0

            // 未获得物品
            itemsFound: [],

            // 探索路径（暂时为空）
            pathCoordinates: [],

            // 错误信息
            error: ExplorationResult.ExplorationError(
                code: "OVERSPEED",
                message: "速度持续超过30km/h，探索已中止",
                recoverable: true
            )
        )

        self.explorationResult = result

        // 重置状态
        isExploring = false
        currentDistance = 0
        currentDuration = 0
        explorationStartTime = nil
        explorationStartLocation = nil
        lastRecordedLocation = nil
        speedWarning = nil
        isOverSpeed = false
        overSpeedStartTime = nil

        // 停止 GPS 位置更新（节省电池）
        locationManager.stopUpdatingLocation()
        print("📍 [探索] 已停止GPS位置更新")

        print("✅ [探索] 状态已重置")
    }

    /// 更新时长（每秒调用）
    private func updateDuration() {
        guard let startTime = explorationStartTime else { return }
        currentDuration = Date().timeIntervalSince(startTime)
    }

    /// 根据距离计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    private func calculateRewardTier(distance: Double) -> RewardTier {
        switch distance {
        case 0..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 根据等级生成奖励物品
    /// - Parameter tier: 奖励等级
    /// - Returns: 奖励物品列表
    private func generateRewardItems(tier: RewardTier) -> [ExplorationResult.ItemLoot] {
        guard tier != .none else { return [] }

        let config = TierConfig.configs[tier]!
        var items: [ExplorationResult.ItemLoot] = []

        for _ in 0..<config.itemCount {
            // 掷骰子决定稀有度
            let random = Double.random(in: 0...1)
            let rarity: ItemRarity

            if random < config.epicChance {
                rarity = .epic
            } else if random < (config.epicChance + config.rareChance) {
                rarity = .rare
            } else {
                rarity = .common
            }

            // 从对应物品池随机抽取
            if let item = randomItem(from: rarity) {
                items.append(item)
            }
        }

        return items
    }

    /// 从指定稀有度物品池随机抽取一个物品
    /// - Parameter rarity: 稀有度
    /// - Returns: 物品掉落数据
    private func randomItem(from rarity: ItemRarity) -> ExplorationResult.ItemLoot? {
        // 从 MockExplorationData 的物品定义中筛选对应稀有度的物品
        let items = MockExplorationData.itemDefinitions.filter { $0.rarity == rarity }

        guard !items.isEmpty else { return nil }

        // 随机选择一个物品
        let randomIndex = Int.random(in: 0..<items.count)
        let itemDef = items[randomIndex]

        // 随机品质（如果物品有品质系统）
        let quality: ItemQuality? = itemDef.hasQuality ? randomQuality() : nil

        return ExplorationResult.ItemLoot(
            itemId: itemDef.id,
            itemName: itemDef.name,
            quantity: 1,
            quality: quality
        )
    }

    /// 随机生成品质
    /// - Returns: 品质
    private func randomQuality() -> ItemQuality {
        let random = Double.random(in: 0...1)

        if random < 0.05 {
            return .excellent  // 5% 优秀
        } else if random < 0.25 {
            return .good       // 20% 良好
        } else if random < 0.85 {
            return .normal     // 60% 普通
        } else {
            return .poor       // 15% 破损
        }
    }

    /// 保存探索记录到数据库
    private func saveExplorationSession(
        startTime: Date,
        endTime: Date,
        duration: Int,
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double,
        totalDistance: Double,
        rewardTier: String,
        itemsRewarded: [ExplorationResult.ItemLoot]
    ) async throws {
        // 获取当前用户 ID
        let userId = try await supabase.auth.session.user.id.uuidString

        // 构建插入数据结构
        struct InsertData: Encodable {
            let user_id: String
            let start_time: String
            let end_time: String
            let duration: Int
            let start_lat: Double
            let start_lon: Double
            let end_lat: Double
            let end_lon: Double
            let total_distance: Double
            let area_explored: Double
            let reward_tier: String
            let items_rewarded: [ExplorationResult.ItemLoot]
            let status: String
        }

        let data = InsertData(
            user_id: userId,
            start_time: ISO8601DateFormatter().string(from: startTime),
            end_time: ISO8601DateFormatter().string(from: endTime),
            duration: duration,
            start_lat: startLat,
            start_lon: startLon,
            end_lat: endLat,
            end_lon: endLon,
            total_distance: totalDistance,
            area_explored: 0,
            reward_tier: rewardTier,
            items_rewarded: itemsRewarded,
            status: "completed"
        )

        // 插入数据库
        try await supabase
            .from("exploration_sessions")
            .insert(data)
            .execute()

        print("✅ 探索记录已保存到数据库")
    }

    // MARK: - POI 接近检测方法

    /// 检查 POI 接近度（节流：每 5 秒检查一次）
    private func checkPOIProximity(currentLocation: CLLocationCoordinate2D) {
        // 节流：每 5 秒检查一次
        if let lastCheck = lastProximityCheck,
           Date().timeIntervalSince(lastCheck) < 5.0 {
            return
        }
        lastProximityCheck = Date()

        // 过滤：只检查未搜刮的 POI
        let availablePOIs = discoveredPOIs.filter { poi in
            poi.status != .looted && !scavengedPOIIds.contains(poi.id)
        }

        guard !availablePOIs.isEmpty else { return }

        // 计算距离，找最近的 POI
        var closestPOI: POI?
        var closestDistance = Double.infinity

        for poi in availablePOIs {
            let distance = calculateDistance(
                from: currentLocation,
                to: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            )

            if distance < closestDistance {
                closestDistance = distance
                closestPOI = poi
            }
        }

        // 50m 内触发弹窗
        if let poi = closestPOI, closestDistance <= 50 {
            guard !alertedPOIIds.contains(poi.id) else { return }

            alertedPOIIds.insert(poi.id)

            // 创建新的 POI 实例（因为 estimatedLoot 是 let 常量）
            let updatedPOI = POI(
                id: poi.id,
                name: poi.name,
                type: poi.type,
                coordinate: poi.coordinate,
                status: .discovered,
                dangerLevel: poi.dangerLevel,
                estimatedLoot: generateEstimatedLoot(for: poi.type),
                description: poi.description,
                distanceFromUser: poi.distanceFromUser
            )

            if let index = discoveredPOIs.firstIndex(where: { $0.id == poi.id }) {
                discoveredPOIs[index] = updatedPOI
            }

            nearbyPOI = updatedPOI
            showProximityPopup = true

            print("🔍 [POI] 发现附近POI: \(poi.name)，距离 \(String(format: "%.0f", closestDistance))m")
        }

        // 重置：>100m 清除提醒状态
        if closestDistance > 100 {
            alertedPOIIds = alertedPOIIds.filter { id in
                guard let poi = discoveredPOIs.first(where: { $0.id == id }) else { return false }
                let dist = calculateDistance(
                    from: currentLocation,
                    to: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
                )
                return dist <= 100
            }
        }
    }

    /// 生成 POI 预估物品（进入 50m 时调用）
    private func generateEstimatedLoot(for type: POIType) -> [String] {
        let lootMapping: [POIType: [String]] = [
            .supermarket: ["矿泉水", "罐头食品", "压缩饼干", "绳子", "塑料"],
            .hospital: ["绷带", "药品", "急救包", "手电筒"],
            .pharmacy: ["绷带", "药品", "矿泉水"],
            .gasStation: ["手电筒", "绳子", "废金属", "矿泉水"],
            .factory: ["木材", "废金属", "绳子", "多功能工具刀"],
            .warehouse: ["木材", "废金属", "塑料", "绳子", "罐头食品"],
            .school: ["矿泉水", "绳子", "手电筒", "木材"]
        ]

        let items = lootMapping[type] ?? ["矿泉水", "绳子"]
        return Array(items.shuffled().prefix(3))  // 随机显示 3 个
    }

    /// 计算两点距离（米）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    // MARK: - POI 搜刮方法

    /// 执行搜刮（用户点击"立即搜刮"）
    /// 优先使用 AI 生成物品，失败时降级使用预设物品
    @MainActor
    func scavengePOI(_ poi: POI) async throws {
        guard let index = discoveredPOIs.firstIndex(where: { $0.id == poi.id }) else {
            throw NSError(domain: "POI not found", code: 404, userInfo: nil)
        }

        print("🎁 [POI] 开始搜刮: \(poi.name)")

        // ===== 尝试 AI 生成物品 =====
        var lootItems: [ExplorationResult.ItemLoot]

        do {
            // 根据危险等级决定物品数量
            let itemCount = calculateItemCount(dangerLevel: poi.dangerLevel)

            print("🤖 [POI] 尝试 AI 生成 \(itemCount) 个物品...")

            // 调用 AI 生成
            lootItems = try await AIItemGenerator.shared.generateItems(
                for: poi,
                itemCount: itemCount
            )

            print("✅ [POI] AI 生成成功")

        } catch {
            // ===== 降级：使用预设物品 =====
            print("⚠️ [POI] AI 生成失败: \(error.localizedDescription)")
            print("⚠️ [POI] 降级使用预设物品")

            lootItems = generateLootItems(for: poi.type)
        }

        // 创建已搜空的新 POI 实例
        let lootedPOI = POI(
            id: poi.id,
            name: poi.name,
            type: poi.type,
            coordinate: poi.coordinate,
            status: .looted,
            dangerLevel: poi.dangerLevel,
            estimatedLoot: nil,
            description: poi.description,
            distanceFromUser: poi.distanceFromUser
        )

        // 更新 POI 状态为已搜空
        discoveredPOIs[index] = lootedPOI
        scavengedPOIIds.insert(poi.id)

        // 添加物品到背包
        try await InventoryManager.shared.addItems(lootItems)

        // 存储供显示
        self.scavengedItems = lootItems
        self.showProximityPopup = false
        self.showScavengeResult = true
        self.nearbyPOI = poi  // 保持 POI 引用用于结果页面

        print("✅ [POI] 搜刮完成: \(poi.name), 获得 \(lootItems.count) 种物品")
        for item in lootItems {
            let qualityStr = item.quality?.rawValue ?? "无品质"
            let rarityStr = item.rarity?.rawValue ?? "未知"
            let aiStr = item.isAIGenerated ? "🤖" : "📦"
            print("🎁 [POI]   \(aiStr) \(item.itemName) x\(item.quantity) [\(qualityStr)] [\(rarityStr)]")
        }
    }

    /// 根据危险等级计算物品数量
    private func calculateItemCount(dangerLevel: Int) -> Int {
        switch dangerLevel {
        case 1:
            return Int.random(in: 1...2)
        case 2:
            return Int.random(in: 1...3)
        case 3:
            return Int.random(in: 2...3)
        case 4:
            return Int.random(in: 2...4)
        case 5:
            return Int.random(in: 3...5)
        default:
            return 2
        }
    }

    /// 生成实际物品（POI 类型关联）
    private func generateLootItems(for type: POIType) -> [ExplorationResult.ItemLoot] {
        // POI 类型 → 物品 ID 映射表
        let lootTables: [POIType: [(itemId: String, rarity: ItemRarity)]] = [
            .supermarket: [
                ("item_water_001", .common),
                ("item_food_001", .common),
                ("item_food_002", .uncommon),
                ("item_material_002", .common),  // 塑料
                ("item_material_003", .common),  // 绳子
                ("item_tool_002", .uncommon)     // 多功能工具刀
            ],
            .hospital: [
                ("item_medical_001", .common),   // 绷带
                ("item_medical_002", .uncommon), // 药品
                ("item_medical_003", .rare),     // 急救包
                ("item_tool_001", .uncommon)     // 手电筒
            ],
            .pharmacy: [
                ("item_medical_001", .common),
                ("item_medical_002", .uncommon),
                ("item_water_001", .common)
            ],
            .gasStation: [
                ("item_tool_001", .uncommon),    // 手电筒
                ("item_material_003", .common),  // 绳子
                ("item_material_004", .uncommon),// 废金属
                ("item_water_001", .common)
            ],
            .factory: [
                ("item_material_001", .common),  // 木材
                ("item_material_004", .uncommon),// 废金属
                ("item_material_003", .common),  // 绳子
                ("item_tool_002", .uncommon)     // 多功能工具刀
            ],
            .warehouse: [
                ("item_material_001", .common),
                ("item_material_004", .uncommon),
                ("item_material_002", .common),
                ("item_material_003", .common),
                ("item_food_001", .common)
            ],
            .school: [
                ("item_water_001", .common),
                ("item_material_003", .common),
                ("item_tool_001", .uncommon),
                ("item_material_001", .common)
            ]
        ]

        let itemPool = lootTables[type] ?? [
            ("item_water_001", .common),
            ("item_material_003", .common)
        ]

        // 每次搜刮生成 1-3 个物品
        let itemCount = Int.random(in: 1...3)
        var items: [ExplorationResult.ItemLoot] = []

        for _ in 0..<itemCount {
            let roll = Double.random(in: 0...1)

            // 根据权重决定稀有度
            let targetRarity: ItemRarity
            if roll < 0.1 {
                targetRarity = .rare       // 10%
            } else if roll < 0.4 {
                targetRarity = .uncommon   // 30%
            } else {
                targetRarity = .common     // 60%
            }

            // 从对应池子随机选择
            let candidateItems = itemPool.filter { $0.rarity == targetRarity }

            // 如果没有该稀有度的物品，随机选一个
            let selectedItem = candidateItems.isEmpty ? itemPool.randomElement()! : candidateItems.randomElement()!

            // 获取物品定义
            guard let itemDef = MockExplorationData.itemDefinitions.first(where: { $0.id == selectedItem.itemId }) else {
                print("⚠️ [POI] 物品定义不存在: \(selectedItem.itemId)")
                continue
            }

            // 每个物品数量 1-3 个
            let quantity = Int.random(in: 1...3)

            // 品质
            let quality = itemDef.hasQuality ? randomQuality() : nil

            items.append(ExplorationResult.ItemLoot(
                itemId: itemDef.id,
                itemName: itemDef.name,
                quantity: quantity,
                quality: quality
            ))
        }

        return items
    }
}

// MARK: - 奖励等级枚举

/// 奖励等级
enum RewardTier: String {
    case none = "无奖励"
    case bronze = "铜级"
    case silver = "银级"
    case gold = "金级"
    case diamond = "钻石级"
}

// MARK: - 等级配置

/// 等级配置
struct TierConfig {
    let itemCount: Int
    let commonChance: Double
    let rareChance: Double
    let epicChance: Double

    static let configs: [RewardTier: TierConfig] = [
        .bronze: TierConfig(itemCount: 1, commonChance: 0.9, rareChance: 0.1, epicChance: 0),
        .silver: TierConfig(itemCount: 2, commonChance: 0.7, rareChance: 0.25, epicChance: 0.05),
        .gold: TierConfig(itemCount: 3, commonChance: 0.5, rareChance: 0.35, epicChance: 0.15),
        .diamond: TierConfig(itemCount: 5, commonChance: 0.3, rareChance: 0.4, epicChance: 0.3)
    ]
}
