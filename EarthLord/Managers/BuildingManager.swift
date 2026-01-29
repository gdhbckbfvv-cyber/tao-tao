//
//  BuildingManager.swift
//  EarthLord
//
//  第28天：建筑管理器
//  负责建筑模板加载、建造检查、开始建造、完成建造、升级建筑
//

import Foundation
import Combine
import Supabase

/// 建筑管理器
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 可观察属性

    /// 建筑模板列表（从本地配置加载）
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 当前领地的玩家建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// 数据库客户端
    private let supabase = SupabaseConfig.shared

    /// 建造计时器字典 [建筑ID: 计时器]
    private var buildTimers: [UUID: Timer] = [:]

    // MARK: - 资源名称映射

    /// 资源可读名称 → 物品编号的映射
    /// 配置模板中使用 "wood"、"stone" 等可读名称
    /// 背包管理器使用 "item_material_001" 等物品编号
    static let resourceNameToItemId: [String: String] = [
        "wood":  "item_material_001",   // 木材
        "stone": "item_material_004",   // 石头
        "metal": "item_material_002",   // 废金属
        "glass": "item_material_005",   // 玻璃
    ]

    /// 物品编号 → 资源可读名称 的反向映射
    static let itemIdToResourceName: [String: String] = {
        var reversed: [String: String] = [:]
        for (name, itemId) in resourceNameToItemId {
            reversed[itemId] = name
        }
        return reversed
    }()

    // MARK: - 初始化

    private init() {}

    // MARK: - 计算属性

    /// 模板字典（templateId -> BuildingTemplate）
    var templateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingTemplates.map { ($0.templateId, $0) })
    }

    // MARK: - 模板加载

    /// 从本地配置文件加载建筑模板
    func loadTemplates() {
        print("")
        print("🏗️ ========== 加载建筑模板 ==========")

        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ [建筑] 未找到 building_templates.json 文件")
            errorMessage = "建筑模板文件缺失"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // 不使用自动转换，因为编码键已经处理了字段映射
            let templateData = try decoder.decode(BuildingTemplateData.self, from: data)
            buildingTemplates = templateData.templates

            print("✅ [建筑] 成功加载 \(buildingTemplates.count) 个建筑模板")
            for template in buildingTemplates {
                print("🏗️ [建筑]   - \(template.name) [\(template.category.displayName)] T\(template.tier)")
            }
        } catch {
            print("❌ [建筑] 解析建筑模板失败: \(error.localizedDescription)")
            errorMessage = "建筑模板加载失败: \(error.localizedDescription)"
        }

        print("================================")
    }

    // MARK: - 建造检查

    /// 检查是否可以建造指定建筑
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    ///   - playerResources: 玩家拥有的资源（键：资源可读名称，值：数量）
    /// - Returns: (是否可以建造，错误信息)
    func canBuild(
        template: BuildingTemplate,
        territoryId: String,
        playerResources: [String: Int]
    ) -> (canBuild: Bool, error: BuildingError?) {
        print("🏗️ [建筑] 检查是否可以建造: \(template.name)")

        // 1. 检查资源是否足够
        var missingResources: [String: Int] = [:]
        for (resourceName, requiredAmount) in template.requiredResources {
            let playerAmount = playerResources[resourceName] ?? 0
            if playerAmount < requiredAmount {
                missingResources[resourceName] = requiredAmount - playerAmount
            }
        }

        if !missingResources.isEmpty {
            print("❌ [建筑] 资源不足: \(missingResources)")
            return (false, .insufficientResources(missingResources))
        }

        // 2. 检查数量是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count

        if existingCount >= template.maxPerTerritory {
            print("❌ [建筑] 已达到最大数量: \(template.maxPerTerritory)")
            return (false, .maxBuildingsReached(template.maxPerTerritory))
        }

        // 3. 全部通过
        print("✅ [建筑] 可以建造 \(template.name)")
        return (true, nil)
    }

    // MARK: - 开始建造

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID（如 "campfire"）
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置坐标（可选）
    /// - Returns: 成功返回新建筑，失败返回错误信息
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: (lat: Double, lon: Double)?
    ) async -> Result<PlayerBuilding, BuildingError> {
        print("")
        print("🏗️ ========== 开始建造 ==========")

        // 0. 确保模板已加载
        if buildingTemplates.isEmpty {
            print("⚠️ [建筑] 模板列表为空，重新加载...")
            loadTemplates()
        }

        // 1. 查找模板
        print("🏗️ [建筑] 当前已加载模板数量: \(buildingTemplates.count)")
        print("🏗️ [建筑] 查找模板ID: \(templateId)")
        print("🏗️ [建筑] 可用模板ID列表: \(buildingTemplates.map { $0.templateId })")

        guard let template = buildingTemplates.first(where: { $0.templateId == templateId }) else {
            print("❌ [建筑] 模板未找到: \(templateId)，已加载模板数: \(buildingTemplates.count)")
            return .failure(.templateNotFound)
        }

        print("🏗️ [建筑] 建造: \(template.name)")

        // 2. 从背包构建资源字典（物品编号 -> 资源可读名称 -> 数量）
        let inventory = InventoryManager.shared.inventoryItems
        var playerResources: [String: Int] = [:]
        for item in inventory {
            if let resourceName = BuildingManager.itemIdToResourceName[item.itemId] {
                playerResources[resourceName, default: 0] += item.quantity
            }
        }

        // 3. 安全重检：canBuild
        let (canBuildResult, buildError) = canBuild(
            template: template,
            territoryId: territoryId,
            playerResources: playerResources
        )

        guard canBuildResult else {
            return .failure(buildError!)
        }

        // 4. 扣除资源（通过 InventoryManager）
        do {
            for (resourceName, amount) in template.requiredResources {
                guard let itemId = BuildingManager.resourceNameToItemId[resourceName] else {
                    print("❌ [建筑] 未知资源名称: \(resourceName)，可用映射: \(BuildingManager.resourceNameToItemId.keys.sorted())")
                    return .failure(.databaseError("未知资源名称: \(resourceName)"))
                }

                try await InventoryManager.shared.removeItem(
                    itemId: itemId,
                    quantity: amount,
                    quality: nil  // 建筑材料没有品质
                )
                print("🏗️ [建筑] 扣除资源: \(resourceName) x\(amount)")
            }
        } catch {
            print("❌ [建筑] 扣除资源失败: \(error.localizedDescription)")
            errorMessage = "扣除资源失败: \(error.localizedDescription)"
            return .failure(.insufficientResources([:]))
        }

        // 5. 获取用户 ID
        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch {
            print("❌ [建筑] 获取用户 ID 失败: \(error.localizedDescription)")
            errorMessage = "获取用户信息失败"
            return .failure(.notAuthenticated)
        }

        // 6. 创建建筑记录
        let now = Date()
        let buildingId = UUID()
        let completedAt = now.addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        let uploadData = PlayerBuildingUploadData(
            id: buildingId.uuidString.lowercased(),
            userId: userId.uuidString.lowercased(),
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: location?.lat,
            locationLon: location?.lon,
            buildStartedAt: now.ISO8601Format(),
            buildCompletedAt: completedAt.ISO8601Format()
        )

        // 7. 插入数据库
        do {
            try await supabase
                .from("player_buildings")
                .insert(uploadData)
                .execute()

            print("✅ [建筑] 数据库记录已创建")
        } catch {
            print("❌ [建筑] 数据库写入失败: \(error.localizedDescription)")
            errorMessage = "建筑创建失败: \(error.localizedDescription)"
            return .failure(.databaseError(error.localizedDescription))
        }

        // 8. 更新本地状态
        let newBuilding = PlayerBuilding(
            id: buildingId,
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: .constructing,
            level: 1,
            locationLat: location?.lat,
            locationLon: location?.lon,
            buildStartedAt: now,
            buildCompletedAt: completedAt
        )

        playerBuildings.append(newBuilding)

        // 9. 启动建造计时器
        startBuildingTimer(buildingId: buildingId, duration: template.buildTimeSeconds)

        print("✅ [建筑] 建造已开始: \(template.name)")
        print("⏱️ [建筑] 建造时间: \(template.buildTimeSeconds)秒")
        print("================================")

        return .success(newBuilding)
    }

    // MARK: - 完成建造

    /// 完成建造（更新状态为运行中）
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async {
        print("🏗️ [建筑] 完成建造: \(buildingId)")

        // 1. 查找本地建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            print("❌ [建筑] 未找到建筑: \(buildingId)")
            return
        }

        let now = Date()

        // 2. 更新数据库
        do {
            struct UpdateData: Encodable {
                let status: String
                let build_completed_at: String
            }

            let updateData = UpdateData(
                status: BuildingStatus.active.rawValue,
                build_completed_at: now.ISO8601Format()
            )

            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString.lowercased())
                .execute()

            // 3. 更新本地状态
            playerBuildings[index].status = .active
            playerBuildings[index].buildCompletedAt = now

            print("✅ [建筑] 建造完成: \(playerBuildings[index].buildingName)")
        } catch {
            print("❌ [建筑] 更新建造状态失败: \(error.localizedDescription)")
            errorMessage = "更新建造状态失败: \(error.localizedDescription)"
        }

        // 4. 清理计时器
        buildTimers[buildingId]?.invalidate()
        buildTimers.removeValue(forKey: buildingId)
    }

    // MARK: - 升级建筑

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 成功返回升级后的建筑，失败返回错误信息
    func upgradeBuilding(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {
        print("🏗️ [建筑] 升级建筑: \(buildingId)")

        // 1. 查找本地建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            print("❌ [建筑] 未找到建筑: \(buildingId)")
            return .failure(.templateNotFound)
        }

        let building = playerBuildings[index]

        // 2. 检查状态：只有运行中才能升级
        guard building.status == .active else {
            print("❌ [建筑] 只能升级运行中的建筑，当前状态: \(building.status.displayName)")
            return .failure(.invalidStatus)
        }

        // 3. 检查是否已达最大等级
        guard let template = buildingTemplates.first(where: { $0.templateId == building.templateId }) else {
            print("❌ [建筑] 未找到模板: \(building.templateId)")
            return .failure(.templateNotFound)
        }

        guard building.level < template.maxLevel else {
            print("❌ [建筑] 已达到最大等级: \(template.maxLevel)")
            return .failure(.maxLevelReached)
        }

        let newLevel = building.level + 1

        // 4. 更新数据库
        do {
            try await supabase
                .from("player_buildings")
                .update(["level": newLevel])
                .eq("id", value: buildingId.uuidString.lowercased())
                .execute()

            // 5. 更新本地状态
            playerBuildings[index].level = newLevel

            print("✅ [建筑] 升级成功: \(building.buildingName) Lv.\(newLevel)")
            return .success(playerBuildings[index])
        } catch {
            print("❌ [建筑] 升级失败: \(error.localizedDescription)")
            errorMessage = "升级失败: \(error.localizedDescription)"
            return .failure(.invalidStatus)
        }
    }

    // MARK: - 拆除建筑

    /// 拆除建筑
    /// - Parameter buildingId: 建筑 ID
    /// - Returns: 是否成功
    func demolishBuilding(buildingId: UUID) async -> Bool {
        print("🏗️ [建筑] 拆除建筑: \(buildingId)")

        // 1. 查找本地建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            print("❌ [建筑] 未找到建筑: \(buildingId)")
            return false
        }

        let building = playerBuildings[index]

        // 2. 从数据库删除
        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString.lowercased())
                .execute()

            // 3. 从本地数组移除
            playerBuildings.remove(at: index)

            // 4. 清理计时器（如果有）
            buildTimers[buildingId]?.invalidate()
            buildTimers.removeValue(forKey: buildingId)

            print("✅ [建筑] 拆除成功: \(building.buildingName)")
            return true
        } catch {
            print("❌ [建筑] 拆除失败: \(error.localizedDescription)")
            errorMessage = "拆除失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 数据拉取

    /// 从数据库加载指定领地的玩家建筑
    /// - Parameter territoryId: 领地 ID
    func fetchPlayerBuildings(territoryId: String) async {
        print("🏗️ [建筑] 加载玩家建筑: 领地 \(territoryId)")
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await supabase.auth.session.user.id.uuidString.lowercased()

            // 查询数据库
            let response = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId)
                .eq("territory_id", value: territoryId)
                .execute()

            // 解码（手动处理日期字段）
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let buildings = try decoder.decode([PlayerBuilding].self, from: response.data)

            playerBuildings = buildings
            print("✅ [建筑] 加载 \(buildings.count) 个建筑")

            // 检查正在建造中的建筑，恢复计时器
            for building in buildings where building.status == .constructing {
                if let template = buildingTemplates.first(where: { $0.templateId == building.templateId }) {
                    let elapsed = Date().timeIntervalSince(building.buildStartedAt)
                    let remaining = Double(template.buildTimeSeconds) - elapsed

                    if remaining <= 0 {
                        // 建造时间已过，直接完成
                        await completeConstruction(buildingId: building.id)
                    } else {
                        // 恢复计时器
                        startBuildingTimer(buildingId: building.id, duration: Int(remaining))
                        print("⏱️ [建筑] 恢复建造计时器: \(building.buildingName) 剩余 \(Int(remaining))秒")
                    }
                }
            }
        } catch {
            print("❌ [建筑] 加载建筑失败: \(error.localizedDescription)")
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 私有方法

    /// 启动建造计时器
    /// - Parameters:
    ///   - buildingId: 建筑 ID
    ///   - duration: 倒计时秒数
    private func startBuildingTimer(buildingId: UUID, duration: Int) {
        print("⏱️ [建筑] 启动建造计时器: \(buildingId) (\(duration)秒)")

        // 先清理已有计时器
        buildTimers[buildingId]?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.completeConstruction(buildingId: buildingId)
            }
        }

        buildTimers[buildingId] = timer
    }

    /// 获取指定模板的信息
    /// - Parameter templateId: 模板 ID
    /// - Returns: 建筑模板
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first(where: { $0.templateId == templateId })
    }
}

// MARK: - 数据库上传结构

/// 玩家建筑上传数据结构（用于数据库插入）
private struct PlayerBuildingUploadData: Encodable {
    let id: String
    let userId: String
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: String
    let buildCompletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
    }
}
