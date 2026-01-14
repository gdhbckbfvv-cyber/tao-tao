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
            // 从 MockExplorationData 获取物品定义
            guard let itemDef = MockExplorationData.getItemDefinition(by: row.itemId) else {
                print("⚠️ [背包] 未找到物品定义: \(row.itemId)")
                continue
            }

            // 解析品质
            let quality: ItemQuality? = if let qualityStr = row.quality {
                ItemQuality(rawValue: qualityStr)
            } else {
                nil
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
                description: itemDef.description
            )

            backpackItems.append(item)

            let qualityStr = quality?.rawValue ?? "无品质"
            print("📦 [背包]   - \(item.name) x\(item.quantity) [\(qualityStr)]")
        }

        // 更新本地缓存
        await MainActor.run {
            self.inventoryItems = backpackItems
        }

        print("✅ [背包] 加载完成，共 \(backpackItems.count) 种物品")
        print("================================")

        return backpackItems
    }

    /// 添加物品到背包（如果已有则累加数量）
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
            print("📦 [背包] 添加: \(item.itemName) x\(item.quantity) [\(qualityStr)]")

            try await addOrUpdateItem(
                userId: userId,
                itemId: item.itemId,
                quantity: item.quantity,
                quality: item.quality?.rawValue
            )
        }

        print("✅ [背包] 所有物品已添加到数据库")
        print("================================")

        // 重新加载背包
        try await loadInventory()
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
}

// MARK: - 数据库行结构

/// 数据库 inventory_items 表的行结构
private struct InventoryItemRow: Codable {
    let id: String
    let userId: String
    let itemId: String
    let quantity: Int
    let quality: String?
    let obtainedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedAt = "obtained_at"
    }
}
