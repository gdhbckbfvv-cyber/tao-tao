//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成服务
//  调用 Supabase Edge Function 生成具有故事背景的物品
//

import Foundation
import Supabase

/// AI 物品生成服务
class AIItemGenerator {

    // MARK: - 单例

    static let shared = AIItemGenerator()

    // MARK: - 私有属性

    private let supabase = SupabaseConfig.shared

    // MARK: - 请求/响应模型

    /// Edge Function 请求模型
    private struct GenerateRequest: Encodable {
        let poi: POIData
        let itemCount: Int

        struct POIData: Encodable {
            let name: String
            let type: String
            let dangerLevel: Int
        }
    }

    /// Edge Function 响应模型
    private struct GenerateResponse: Decodable {
        let success: Bool
        let items: [AIGeneratedItem]
        let error: String?
    }

    /// AI 生成的物品数据
    private struct AIGeneratedItem: Decodable {
        let name: String
        let category: String
        let rarity: String
        let story: String
    }

    // MARK: - 错误类型

    enum AIGeneratorError: Error, LocalizedError {
        case networkError(String)
        case parseError(String)
        case apiError(String)
        case noSession

        var errorDescription: String? {
            switch self {
            case .networkError(let message):
                return "网络错误: \(message)"
            case .parseError(let message):
                return "解析错误: \(message)"
            case .apiError(let message):
                return "API 错误: \(message)"
            case .noSession:
                return "用户未登录"
            }
        }
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 兴趣点
    ///   - itemCount: 生成物品数量 (1-5)
    /// - Returns: 生成的物品列表
    func generateItems(for poi: POI, itemCount: Int = 3) async throws -> [ExplorationResult.ItemLoot] {
        print("")
        print("🤖 ========== AI 物品生成 ==========")
        print("🤖 [AI] POI: \(poi.name) (类型: \(poi.type.rawValue))")
        print("🤖 [AI] 危险等级: \(poi.dangerLevel)/5")
        print("🤖 [AI] 请求数量: \(itemCount)")

        // 获取当前会话
        guard let session = try? await supabase.auth.session else {
            print("❌ [AI] 用户未登录")
            throw AIGeneratorError.noSession
        }

        // 构建请求
        let request = GenerateRequest(
            poi: GenerateRequest.POIData(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: poi.dangerLevel
            ),
            itemCount: min(max(itemCount, 1), 5)  // 限制 1-5
        )

        print("🤖 [AI] 正在调用 Edge Function...")

        do {
            // 调用 Edge Function
            let response: GenerateResponse = try await supabase.functions.invoke(
                "generate-ai-item",
                options: FunctionInvokeOptions(
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ],
                    body: request
                )
            )

            // 检查响应
            guard response.success else {
                let errorMsg = response.error ?? "未知错误"
                print("❌ [AI] API 返回错误: \(errorMsg)")
                throw AIGeneratorError.apiError(errorMsg)
            }

            print("✅ [AI] 成功生成 \(response.items.count) 个物品")

            // 转换为 ItemLoot
            let lootItems = response.items.enumerated().map { index, item in
                // 解析分类
                let category = parseCategory(item.category)

                // 解析稀有度
                let rarity = parseRarity(item.rarity)

                // 生成唯一 ID
                let itemId = "ai_\(UUID().uuidString.prefix(8))"

                // 随机品质（根据稀有度）
                let quality = randomQuality(for: rarity)

                print("🤖 [AI]   \(index + 1). \(item.name)")
                print("🤖 [AI]      分类: \(category.rawValue), 稀有度: \(rarity.rawValue)")
                print("🤖 [AI]      故事: \(item.story.prefix(50))...")

                return ExplorationResult.ItemLoot(
                    itemId: itemId,
                    itemName: item.name,
                    quantity: 1,
                    quality: quality,
                    story: item.story,
                    rarity: rarity,
                    isAIGenerated: true,
                    category: category
                )
            }

            print("✅ [AI] 物品转换完成")
            print("================================")

            return lootItems

        } catch let error as AIGeneratorError {
            throw error
        } catch {
            print("❌ [AI] 网络请求失败: \(error.localizedDescription)")
            throw AIGeneratorError.networkError(error.localizedDescription)
        }
    }

    // MARK: - 私有方法

    /// 解析分类字符串
    private func parseCategory(_ categoryString: String) -> ItemCategory {
        switch categoryString {
        case "水类", "水":
            return .water
        case "食物", "食品":
            return .food
        case "医疗", "医药":
            return .medical
        case "材料":
            return .material
        case "工具":
            return .tool
        case "武器":
            return .weapon
        default:
            return .material
        }
    }

    /// 解析稀有度字符串
    private func parseRarity(_ rarityString: String) -> ItemRarity {
        switch rarityString.lowercased() {
        case "common", "常见":
            return .common
        case "uncommon", "少见":
            return .uncommon
        case "rare", "稀有":
            return .rare
        case "epic", "史诗":
            return .epic
        case "legendary", "传说":
            return .legendary
        default:
            return .common
        }
    }

    /// 根据稀有度随机品质
    private func randomQuality(for rarity: ItemRarity) -> ItemQuality? {
        // 高稀有度物品有更高的品质
        let random = Double.random(in: 0...1)

        switch rarity {
        case .legendary:
            return .excellent
        case .epic:
            return random < 0.7 ? .excellent : .good
        case .rare:
            return random < 0.5 ? .good : .normal
        case .uncommon:
            return random < 0.3 ? .good : .normal
        case .common:
            if random < 0.1 {
                return .poor
            } else if random < 0.7 {
                return .normal
            } else {
                return .good
            }
        }
    }
}
