//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责管理玩家背包物品、与数据库同步
//

import Foundation
import Combine
import Supabase

/// 背包管理器
class InventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = InventoryManager()

    // MARK: - Published 属性

    /// 背包物品列表
    @Published var inventoryItems: [BackpackItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    // MARK: - 私有属性

    /// Supabase 客户端
    private let supabase = SupabaseConfig.shared

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 从数据库加载背包物品
    /// - Returns: 背包物品列表
    @MainActor
    func loadInventory() async throws -> [BackpackItem] {
        isLoading = true
        defer { isLoading = false }

        print("")
        print("📦 ========== 加载背包 ==========")
        print("📦 [背包] 开始从数据库加载物品...")

        // 获取当前用户 ID
        let userId = try await supabase.auth.session.user.id.uuidString
        print("📦 [背包] 用户ID: \(userId)")

        // 查询数据库
        let response: [InventoryItemRow] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        print("✅ [背包] 从数据库查询到 \(response.count) 条记录")

        // 转换为 BackpackItem
        var backpackItems: [BackpackItem] = []

        for row in response {
            // 解析品质
            let quality: ItemQuality? = if let qualityStr = row.quality {
                ItemQuality(rawValue: qualityStr)
            } else {
                nil
            }

            // 检查是否为 AI 生成的物品
            if row.isAiGenerated == true {
                // AI 生成的物品：从数据库字段读取信息
                let rarity: ItemRarity? = if let rarityStr = row.rarity {
                    ItemRarity(rawValue: rarityStr)
                } else {
                    nil
                }

                let category: ItemCategory = if let categoryStr = row.category {
                    ItemCategory(rawValue: categoryStr) ?? .material
                } else {
                    .material
                }

                // 获取默认重量和体积（基于分类）
                let (weight, volume) = getDefaultWeightVolume(for: category)

                let item = BackpackItem(
                    id: row.id,
                    itemId: row.itemId,
                    name: row.itemId.replacingOccurrences(of: "ai_", with: "AI物品_"),  // 临时显示名称
                    category: category,
                    quantity: row.quantity,
                    quality: quality,
                    weight: weight,
                    volume: volume,
                    description: row.story ?? "AI 生成的物品",
                    story: row.story,
                    rarity: rarity,
                    isAIGenerated: true
                )

                backpackItems.append(item)

                let qualityStr = quality?.rawValue ?? "无品质"
                let rarityStr = rarity?.rawValue ?? "未知"
                print("📦 [背包]   - 🤖 \(item.name) x\(item.quantity) [\(qualityStr)] [\(rarityStr)]")
            } else {
                // 预设物品：从 MockExplorationData 获取物品定义
                guard let itemDef = MockExplorationData.getItemDefinition(by: row.itemId) else {
                    print("⚠️ [背包] 未找到物品定义: \(row.itemId)")
                    continue
                }

                let item = BackpackItem(
                    id: row.id,
                    itemId: row.itemId,
                    name: itemDef.name,
                    category: itemDef.category,
                    quantity: row.quantity,
                    quality: quality,
                    weight: itemDef.weight,
                    volume: itemDef.volume,
                    description: itemDef.description,
                    story: nil,
                    rarity: itemDef.rarity,
                    isAIGenerated: false
                )

                backpackItems.append(item)

                let qualityStr = quality?.rawValue ?? "无品质"
                print("📦 [背包]   - 📦 \(item.name) x\(item.quantity) [\(qualityStr)]")
            }
        }

        // 更新本地缓存
        await MainActor.run {
            self.inventoryItems = backpackItems
        }

        print("✅ [背包] 加载完成，共 \(backpackItems.count) 种物品")
        print("================================")

        return backpackItems
    }

    /// 添加物品到背包（支持 AI 生成物品和预设物品）
    /// - Parameter items: 物品掉落列表
    @MainActor
    func addItems(_ items: [ExplorationResult.ItemLoot]) async throws {
        guard !items.isEmpty else {
            print("⚠️ [背包] 物品列表为空，跳过添加")
            return
        }

        print("")
        print("📦 ========== 添加物品到背包 ==========")
        print("📦 [背包] 开始添加 \(items.count) 种物品...")

        // 获取当前用户 ID
        let userId = try await supabase.auth.session.user.id.uuidString

        for item in items {
            let qualityStr = item.quality?.rawValue ?? "无品质"
            let aiStr = item.isAIGenerated ? "🤖" : "📦"
            print("📦 [背包] 添加: \(aiStr) \(item.itemName) x\(item.quantity) [\(qualityStr)]")

            if item.isAIGenerated {
                // AI 生成的物品：直接插入新记录（不合并，每个物品都是独特的）
                try await insertAIGeneratedItem(
                    userId: userId,
                    item: item
                )
            } else {
                // 预设物品：使用原有的 upsert 逻辑
                try await addOrUpdateItem(
                    userId: userId,
                    itemId: item.itemId,
                    quantity: item.quantity,
                    quality: item.quality?.rawValue
                )
            }
        }

        print("✅ [背包] 所有物品已添加到数据库")
        print("================================")

        // 重新加载背包
        _ = try await loadInventory()
    }

    /// 插入 AI 生成的物品（新增方法）
    private func insertAIGeneratedItem(
        userId: String,
        item: ExplorationResult.ItemLoot
    ) async throws {
        struct InsertData: Encodable {
            let user_id: String
            let item_id: String
            let quantity: Int
            let quality: String?
            let story: String?
            let rarity: String?
            let is_ai_generated: Bool
            let category: String?
        }

        let data = InsertData(
            user_id: userId,
            item_id: item.itemId,
            quantity: item.quantity,
            quality: item.quality?.rawValue,
            story: item.story,
            rarity: item.rarity?.rawValue,
            is_ai_generated: true,
            category: item.category?.rawValue
        )

        try await supabase.from("inventory_items")
            .insert(data)
            .execute()

        print("  ✅ [数据库] 新增 AI 物品: \(item.itemName)")
    }

    /// 移除物品（减少数量或删除）
    /// - Parameters:
    ///   - itemId: 物品 ID
    ///   - quantity: 数量
    ///   - quality: 品质（可选）
    @MainActor
    func removeItem(itemId: String, quantity: Int, quality: String? = nil) async throws {
        print("📦 开始移除物品: \(itemId) x\(quantity)")

        // 获取当前用户 ID
        let userId = try await supabase.auth.session.user.id.uuidString

        // 查询当前物品
        var query = supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_id", value: itemId)

        if let quality = quality {
            query = query.eq("quality", value: quality)
        } else {
            query = query.is("quality", value: nil)
        }

        let response: [InventoryItemRow] = try await query.execute().value

        guard let existingItem = response.first else {
            print("⚠️ 物品不存在，无法移除")
            return
        }

        let newQuantity = existingItem.quantity - quantity

        if newQuantity <= 0 {
            // 删除物品
            try await supabase.from("inventory_items")
                .delete()
                .eq("id", value: existingItem.id)
                .execute()

            print("✅ 物品已删除")
        } else {
            // 更新数量
            try await supabase.from("inventory_items")
                .update(["quantity": newQuantity])
                .eq("id", value: existingItem.id)
                .execute()

            print("✅ 物品数量已更新: \(newQuantity)")
        }

        // 重新加载背包
        try await loadInventory()
    }

    // MARK: - 私有方法

    /// 添加或更新物品（使用 upsert 逻辑）
    /// - Parameters:
    ///   - userId: 用户 ID
    ///   - itemId: 物品 ID
    ///   - quantity: 数量
    ///   - quality: 品质
    private func addOrUpdateItem(
        userId: String,
        itemId: String,
        quantity: Int,
        quality: String?
    ) async throws {
        // 先查询是否已存在
        var query = supabase.from("inventory_items")
            .select()
            .eq("user_id", value: userId)
            .eq("item_id", value: itemId)

        if let quality = quality {
            query = query.eq("quality", value: quality)
        } else {
            query = query.is("quality", value: nil)
        }

        let response: [InventoryItemRow] = try await query.execute().value

        if let existingItem = response.first {
            // 已存在，累加数量
            let newQuantity = existingItem.quantity + quantity

            try await supabase.from("inventory_items")
                .update(["quantity": newQuantity])
                .eq("id", value: existingItem.id)
                .execute()

            print("  ✅ [数据库] 累加数量: \(itemId) (\(existingItem.quantity) + \(quantity) = \(newQuantity))")
        } else {
            // 不存在，插入新记录
            struct InsertData: Encodable {
                let user_id: String
                let item_id: String
                let quantity: Int
                let quality: String?
            }

            let data = InsertData(
                user_id: userId,
                item_id: itemId,
                quantity: quantity,
                quality: quality
            )

            try await supabase.from("inventory_items")
                .insert(data)
                .execute()

            print("  ✅ [数据库] 新增物品: \(itemId) x\(quantity)")
        }
    }

    /// 获取默认重量和体积（基于物品分类）
    private func getDefaultWeightVolume(for category: ItemCategory) -> (Double, Double) {
        switch category {
        case .water:
            return (0.5, 0.5)
        case .food:
            return (0.3, 0.2)
        case .medical:
            return (0.2, 0.1)
        case .material:
            return (1.0, 1.5)
        case .tool:
            return (0.4, 0.3)
        case .weapon:
            return (1.5, 1.0)
        }
    }
}

// MARK: - 开发者测试工具

extension InventoryManager {

    /// 添加测试资源（用于建造系统测试）
    /// 添加木材、石头、废金属、玻璃各 100 个
    @MainActor
    func addTestResources() async -> Bool {
        print("")
        print("🧪 ========== 添加测试资源 ==========")

        do {
            let userId = try await supabase.auth.session.user.id.uuidString

            // 测试资源列表
            let testResources: [(itemId: String, name: String, quantity: Int)] = [
                ("item_material_001", "木材", 100),
                ("item_material_004", "石头", 100),
                ("item_material_002", "废金属", 100),
                ("item_material_005", "玻璃", 100),
            ]

            for resource in testResources {
                // 使用 upsert 逻辑
                let query = supabase.from("inventory_items")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("item_id", value: resource.itemId)
                    .is("quality", value: nil)

                let response: [InventoryItemRow] = try await query.execute().value

                if let existingItem = response.first {
                    // 已存在，累加数量
                    let newQuantity = existingItem.quantity + resource.quantity

                    try await supabase.from("inventory_items")
                        .update(["quantity": newQuantity])
                        .eq("id", value: existingItem.id)
                        .execute()

                    print("🧪 [测试] 累加 \(resource.name): +\(resource.quantity) = \(newQuantity)")
                } else {
                    // 不存在，插入新记录
                    struct InsertData: Encodable {
                        let user_id: String
                        let item_id: String
                        let quantity: Int
                    }

                    let data = InsertData(
                        user_id: userId,
                        item_id: resource.itemId,
                        quantity: resource.quantity
                    )

                    try await supabase.from("inventory_items")
                        .insert(data)
                        .execute()

                    print("🧪 [测试] 新增 \(resource.name): \(resource.quantity)")
                }
            }

            // 重新加载背包
            _ = try await loadInventory()

            print("✅ [测试] 测试资源添加完成")
            print("================================")
            return true
        } catch {
            print("❌ [测试] 添加测试资源失败: \(error.localizedDescription)")
            print("================================")
            return false
        }
    }

    /// 清空所有背包物品
    @MainActor
    func clearAllItems() async -> Bool {
        print("")
        print("🧪 ========== 清空背包 ==========")

        do {
            let userId = try await supabase.auth.session.user.id.uuidString

            // 删除该用户的所有背包物品
            try await supabase.from("inventory_items")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            // 清空本地缓存
            inventoryItems = []

            print("✅ [测试] 背包已清空")
            print("================================")
            return true
        } catch {
            print("❌ [测试] 清空背包失败: \(error.localizedDescription)")
            print("================================")
            return false
        }
    }
}

// MARK: - 数据库行结构

/// 数据库 inventory_items 表的行结构（扩展版，支持 AI 物品）
private struct InventoryItemRow: Codable {
    let id: String
    let userId: String
    let itemId: String
    let quantity: Int
    let quality: String?
    let obtainedAt: String

    // MARK: AI 生成物品相关字段
    let story: String?
    let rarity: String?
    let isAiGenerated: Bool?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedAt = "obtained_at"
        case story
        case rarity
        case isAiGenerated = "is_ai_generated"
        case category
    }
}
