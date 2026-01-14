//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块的测试假数据
//  包含：POI、背包物品、物品定义、探索结果等
//

import Foundation
import CoreLocation

// MARK: - POI（兴趣点）数据模型

/// POI 状态枚举
enum POIStatus: String, Codable {
    case undiscovered = "未发现"    // 未发现（地图上不显示）
    case discovered = "已发现"      // 已发现但未搜刮
    case looted = "已搜空"          // 已被搜刮完毕
}

/// POI 类型枚举
enum POIType: String, Codable {
    case supermarket = "超市"
    case hospital = "医院"
    case gasStation = "加油站"
    case pharmacy = "药店"
    case factory = "工厂"
    case warehouse = "仓库"
    case school = "学校"
}

/// POI（兴趣点）数据结构
struct POI: Identifiable, Codable {
    let id: String                          // 唯一标识符
    let name: String                        // POI 名称
    let type: POIType                       // POI 类型
    let coordinate: Coordinate              // 经纬度坐标
    var status: POIStatus                   // 状态（未发现/已发现/已搜空）
    let dangerLevel: Int                    // 危险等级（1-5，1最安全，5最危险）
    let estimatedLoot: [String]?            // 预估可获得的物资列表（nil 表示已搜空）
    let description: String                 // 描述信息
    let distanceFromUser: Double?           // 距离用户的距离（米，nil 表示未计算）

    /// 可编码的坐标结构（CoreLocation 的 CLLocationCoordinate2D 不支持 Codable）
    struct Coordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double

        /// 转换为 CLLocationCoordinate2D
        func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

// MARK: - 背包物品数据模型

/// 物品品质枚举
enum ItemQuality: String, Codable {
    case poor = "破损"          // 品质差（50%效果）
    case normal = "普通"        // 品质正常（100%效果）
    case good = "良好"          // 品质好（120%效果）
    case excellent = "优秀"     // 品质优秀（150%效果）
}

/// 物品分类枚举
enum ItemCategory: String, Codable {
    case water = "水类"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
    case weapon = "武器"
}

/// 背包物品数据结构
struct BackpackItem: Identifiable, Codable {
    let id: String                          // 唯一标识符
    let itemId: String                      // 物品定义 ID（关联 ItemDefinition）
    let name: String                        // 物品名称
    let category: ItemCategory              // 物品分类
    var quantity: Int                       // 数量
    let quality: ItemQuality?               // 品质（部分物品没有品质，如材料）
    let weight: Double                      // 单个物品重量（千克）
    let volume: Double                      // 单个物品体积（升）
    let description: String                 // 物品描述

    /// 总重量（千克）
    var totalWeight: Double {
        return weight * Double(quantity)
    }

    /// 总体积（升）
    var totalVolume: Double {
        return volume * Double(quantity)
    }
}

// MARK: - 物品定义数据模型

/// 物品稀有度枚举
enum ItemRarity: String, Codable {
    case common = "常见"        // 常见（白色）
    case uncommon = "少见"      // 少见（绿色）
    case rare = "稀有"          // 稀有（蓝色）
    case epic = "史诗"          // 史诗（紫色）
    case legendary = "传说"     // 传说（橙色）
}

/// 物品定义数据结构（物品数据库）
struct ItemDefinition: Identifiable, Codable {
    let id: String                          // 物品唯一标识符
    let name: String                        // 中文名称
    let category: ItemCategory              // 分类
    let weight: Double                      // 单个重量（千克）
    let volume: Double                      // 单个体积（升）
    let rarity: ItemRarity                  // 稀有度
    let hasQuality: Bool                    // 是否有品质系统
    let stackable: Bool                     // 是否可堆叠
    let maxStack: Int                       // 最大堆叠数量
    let description: String                 // 描述
    let iconName: String?                   // 图标名称（SF Symbol）
}

// MARK: - 探索结果数据模型

/// 探索结果数据结构
struct ExplorationResult: Codable, Equatable {
    let sessionId: String                   // 本次探索会话 ID
    let startTime: Date                     // 开始时间
    let endTime: Date                       // 结束时间
    let duration: TimeInterval              // 探索时长（秒）

    // 行走数据
    let distanceWalked: Double              // 本次行走距离（米）
    let totalDistanceWalked: Double         // 累计行走距离（米）
    let distanceRanking: Int                // 距离排名

    // 获得物品
    let itemsFound: [ItemLoot]              // 获得的物品列表

    // 探索路径
    let pathCoordinates: [POI.Coordinate]   // 探索路径坐标点

    // 错误状态（可选）
    let error: ExplorationError?            // 探索失败时的错误信息

    /// 物品掉落数据结构
    struct ItemLoot: Codable, Equatable {
        let itemId: String                  // 物品 ID
        let itemName: String                // 物品名称
        let quantity: Int                   // 数量
        let quality: ItemQuality?           // 品质（如果有）
    }

    /// 探索错误信息
    struct ExplorationError: Codable, Equatable {
        let code: String                    // 错误代码
        let message: String                 // 错误信息
        let recoverable: Bool               // 是否可重试
    }

    /// 格式化时长（分钟）
    var durationInMinutes: Int {
        return Int(duration / 60)
    }
}

// MARK: - 测试假数据

/// 探索模块测试数据
class MockExplorationData {

    // MARK: - 1. POI 列表（5个不同状态的兴趣点）

    static let mockPOIs: [POI] = [
        // POI 1: 废弃超市 - 已发现，有物资
        POI(
            id: "poi_supermarket_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: POI.Coordinate(latitude: 39.9042, longitude: 116.4074), // 北京天安门附近
            status: .discovered,
            dangerLevel: 2,
            estimatedLoot: ["矿泉水", "罐头食品", "绳子"],
            description: "一座废弃的大型超市，货架上还留有部分物资，需要小心探索。",
            distanceFromUser: 1200.0
        ),

        // POI 2: 医院废墟 - 已发现，已被搜空
        POI(
            id: "poi_hospital_001",
            name: "医院废墟",
            type: .hospital,
            coordinate: POI.Coordinate(latitude: 39.9100, longitude: 116.4150),
            status: .looted,
            dangerLevel: 4,
            estimatedLoot: nil, // 已被搜空
            description: "废弃的医院大楼，看起来已经被其他幸存者搜刮过了，危险等级较高。",
            distanceFromUser: 800.0
        ),

        // POI 3: 加油站 - 未发现
        POI(
            id: "poi_gasstation_001",
            name: "加油站",
            type: .gasStation,
            coordinate: POI.Coordinate(latitude: 39.9000, longitude: 116.4000),
            status: .undiscovered,
            dangerLevel: 3,
            estimatedLoot: ["手电筒", "绳子", "废金属"],
            description: "一座废弃的加油站，可能还有一些工具和材料。",
            distanceFromUser: 2500.0
        ),

        // POI 4: 药店废墟 - 已发现，有物资
        POI(
            id: "poi_pharmacy_001",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: POI.Coordinate(latitude: 39.9080, longitude: 116.4100),
            status: .discovered,
            dangerLevel: 2,
            estimatedLoot: ["绷带", "药品", "矿泉水"],
            description: "小型药店废墟，墙壁上的医疗标志依稀可见，可能有医疗物资。",
            distanceFromUser: 950.0
        ),

        // POI 5: 工厂废墟 - 未发现
        POI(
            id: "poi_factory_001",
            name: "工厂废墟",
            type: .factory,
            coordinate: POI.Coordinate(latitude: 39.8950, longitude: 116.4200),
            status: .undiscovered,
            dangerLevel: 5,
            estimatedLoot: ["木材", "废金属", "绳子", "手电筒"],
            description: "大型废弃工厂，内部结构复杂，危险等级极高，但可能有大量材料。",
            distanceFromUser: 3200.0
        )
    ]

    // MARK: - 2. 背包物品（6-8种不同类型）

    static let mockBackpackItems: [BackpackItem] = [
        // 水类
        BackpackItem(
            id: "backpack_item_001",
            itemId: "item_water_001",
            name: "矿泉水",
            category: .water,
            quantity: 8,
            quality: .normal,
            weight: 0.5,
            volume: 0.5,
            description: "500ml装矿泉水，可以解渴和补充体力。"
        ),

        // 食物
        BackpackItem(
            id: "backpack_item_002",
            itemId: "item_food_001",
            name: "罐头食品",
            category: .food,
            quantity: 12,
            quality: .good,
            weight: 0.4,
            volume: 0.3,
            description: "密封良好的罐头食品，可长期保存。"
        ),

        // 医疗 - 绷带
        BackpackItem(
            id: "backpack_item_003",
            itemId: "item_medical_001",
            name: "绷带",
            category: .medical,
            quantity: 15,
            quality: .normal,
            weight: 0.05,
            volume: 0.05,
            description: "医用绷带，可以用于包扎伤口。"
        ),

        // 医疗 - 药品
        BackpackItem(
            id: "backpack_item_004",
            itemId: "item_medical_002",
            name: "药品",
            category: .medical,
            quantity: 6,
            quality: .excellent,
            weight: 0.1,
            volume: 0.05,
            description: "常用药品，可以治疗轻伤和疾病。"
        ),

        // 材料 - 木材（没有品质）
        BackpackItem(
            id: "backpack_item_005",
            itemId: "item_material_001",
            name: "木材",
            category: .material,
            quantity: 25,
            quality: nil, // 材料没有品质
            weight: 1.0,
            volume: 2.0,
            description: "废弃建筑中拆下的木材，可用于建造和修理。"
        ),

        // 材料 - 废金属（没有品质）
        BackpackItem(
            id: "backpack_item_006",
            itemId: "item_material_002",
            name: "废金属",
            category: .material,
            quantity: 18,
            quality: nil, // 材料没有品质
            weight: 2.0,
            volume: 1.5,
            description: "各种废弃金属零件，可用于制作工具和武器。"
        ),

        // 工具 - 手电筒
        BackpackItem(
            id: "backpack_item_007",
            itemId: "item_tool_001",
            name: "手电筒",
            category: .tool,
            quantity: 3,
            quality: .good,
            weight: 0.3,
            volume: 0.2,
            description: "LED手电筒，夜间探索必备工具。"
        ),

        // 工具 - 绳子（没有品质）
        BackpackItem(
            id: "backpack_item_008",
            itemId: "item_tool_002",
            name: "绳子",
            category: .tool,
            quantity: 10,
            quality: nil, // 工具类基础物品没有品质
            weight: 0.5,
            volume: 0.4,
            description: "尼龙绳，可用于攀爬、捆绑等多种用途。"
        )
    ]

    // MARK: - 3. 物品定义表（数据库）

    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_water_001",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: true,
            stackable: true,
            maxStack: 20,
            description: "500ml装矿泉水，可以解渴和补充体力。品质影响恢复效果。",
            iconName: "drop.fill"
        ),

        // 食物
        ItemDefinition(
            id: "item_food_001",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            hasQuality: true,
            stackable: true,
            maxStack: 30,
            description: "密封罐头食品，可长期保存。品质影响饱腹度。",
            iconName: "fork.knife"
        ),

        ItemDefinition(
            id: "item_food_002",
            name: "压缩饼干",
            category: .food,
            weight: 0.2,
            volume: 0.1,
            rarity: .uncommon,
            hasQuality: true,
            stackable: true,
            maxStack: 50,
            description: "军用压缩饼干，轻便且高热量。",
            iconName: "square.stack.3d.up.fill"
        ),

        // 医疗
        ItemDefinition(
            id: "item_medical_001",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .common,
            hasQuality: true,
            stackable: true,
            maxStack: 50,
            description: "医用绷带，可以包扎伤口。品质影响治疗效果。",
            iconName: "bandage.fill"
        ),

        ItemDefinition(
            id: "item_medical_002",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            hasQuality: true,
            stackable: true,
            maxStack: 20,
            description: "常用药品，可以治疗轻伤和疾病。品质影响治疗效果。",
            iconName: "pills.fill"
        ),

        ItemDefinition(
            id: "item_medical_003",
            name: "急救包",
            category: .medical,
            weight: 0.5,
            volume: 0.3,
            rarity: .rare,
            hasQuality: true,
            stackable: true,
            maxStack: 5,
            description: "专业急救包，可以治疗重伤。",
            iconName: "cross.case.fill"
        ),

        // 材料
        ItemDefinition(
            id: "item_material_001",
            name: "木材",
            category: .material,
            weight: 1.0,
            volume: 2.0,
            rarity: .common,
            hasQuality: false, // 材料没有品质系统
            stackable: true,
            maxStack: 50,
            description: "废弃建筑中的木材，可用于建造和修理。",
            iconName: "rectangle.3.group.fill"
        ),

        ItemDefinition(
            id: "item_material_002",
            name: "废金属",
            category: .material,
            weight: 2.0,
            volume: 1.5,
            rarity: .common,
            hasQuality: false,
            stackable: true,
            maxStack: 40,
            description: "各种废弃金属零件，可用于制作工具和武器。",
            iconName: "cube.fill"
        ),

        ItemDefinition(
            id: "item_material_003",
            name: "塑料",
            category: .material,
            weight: 0.3,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            stackable: true,
            maxStack: 100,
            description: "废弃塑料制品，可以用于制作容器。",
            iconName: "cylinder.fill"
        ),

        // 工具
        ItemDefinition(
            id: "item_tool_001",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            hasQuality: true,
            stackable: true,
            maxStack: 5,
            description: "LED手电筒，夜间探索必备。品质影响照明范围和电池寿命。",
            iconName: "flashlight.on.fill"
        ),

        ItemDefinition(
            id: "item_tool_002",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.4,
            rarity: .common,
            hasQuality: false,
            stackable: true,
            maxStack: 20,
            description: "尼龙绳，可用于攀爬、捆绑等多种用途。",
            iconName: "link"
        ),

        ItemDefinition(
            id: "item_tool_003",
            name: "多功能工具刀",
            category: .tool,
            weight: 0.2,
            volume: 0.1,
            rarity: .rare,
            hasQuality: true,
            stackable: true,
            maxStack: 3,
            description: "瑞士军刀，包含多种工具，非常实用。",
            iconName: "wrench.and.screwdriver.fill"
        )
    ]

    // MARK: - 4. 探索结果示例

    static let mockExplorationResult: ExplorationResult = {
        let startTime = Date().addingTimeInterval(-1800) // 30分钟前
        let endTime = Date()

        return ExplorationResult(
            sessionId: "exploration_session_\(UUID().uuidString)",
            startTime: startTime,
            endTime: endTime,
            duration: 1800, // 30分钟 = 1800秒

            // 行走数据
            distanceWalked: 2500.0,         // 本次行走 2500 米
            totalDistanceWalked: 15000.0,   // 累计行走 15000 米 = 15 公里
            distanceRanking: 42,            // 距离排名第 42 名

            // 获得物品
            itemsFound: [
                ExplorationResult.ItemLoot(
                    itemId: "item_material_001",
                    itemName: "木材",
                    quantity: 5,
                    quality: nil // 材料没有品质
                ),
                ExplorationResult.ItemLoot(
                    itemId: "item_water_001",
                    itemName: "矿泉水",
                    quantity: 3,
                    quality: .normal
                ),
                ExplorationResult.ItemLoot(
                    itemId: "item_food_001",
                    itemName: "罐头食品",
                    quantity: 2,
                    quality: .good
                ),
                ExplorationResult.ItemLoot(
                    itemId: "item_medical_001",
                    itemName: "绷带",
                    quantity: 4,
                    quality: .normal
                ),
                ExplorationResult.ItemLoot(
                    itemId: "item_tool_002",
                    itemName: "绳子",
                    quantity: 1,
                    quality: nil
                )
            ],

            // 探索路径（示例：5个坐标点）
            pathCoordinates: [
                POI.Coordinate(latitude: 39.9042, longitude: 116.4074),
                POI.Coordinate(latitude: 39.9050, longitude: 116.4080),
                POI.Coordinate(latitude: 39.9060, longitude: 116.4090),
                POI.Coordinate(latitude: 39.9070, longitude: 116.4100),
                POI.Coordinate(latitude: 39.9080, longitude: 116.4110)
            ],

            // 无错误
            error: nil
        )
    }()

    /// 失败的探索结果示例（用于测试错误状态）
    static let mockFailedExplorationResult: ExplorationResult = {
        let startTime = Date().addingTimeInterval(-300) // 5分钟前
        let endTime = Date()

        return ExplorationResult(
            sessionId: "exploration_session_failed_\(UUID().uuidString)",
            startTime: startTime,
            endTime: endTime,
            duration: 300, // 5分钟

            // 行走数据（失败前的数据）
            distanceWalked: 150.0,
            totalDistanceWalked: 15000.0,
            distanceRanking: 42,

            // 未获得物品
            itemsFound: [],

            // 探索路径（失败前的少量坐标）
            pathCoordinates: [
                POI.Coordinate(latitude: 39.9042, longitude: 116.4074),
                POI.Coordinate(latitude: 39.9045, longitude: 116.4076)
            ],

            // 错误信息
            error: ExplorationResult.ExplorationError(
                code: "DANGER_ABORT",
                message: "遭遇危险生物，探索被迫中止",
                recoverable: true
            )
        )
    }()

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    static func getItemDefinition(by itemId: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == itemId }
    }

    /// 计算背包总重量（千克）
    static func calculateTotalBackpackWeight() -> Double {
        return mockBackpackItems.reduce(0) { $0 + $1.totalWeight }
    }

    /// 计算背包总体积（升）
    static func calculateTotalBackpackVolume() -> Double {
        return mockBackpackItems.reduce(0) { $0 + $1.totalVolume }
    }

    /// 根据状态筛选POI
    static func filterPOIs(by status: POIStatus) -> [POI] {
        return mockPOIs.filter { $0.status == status }
    }

    /// 根据分类筛选背包物品
    static func filterBackpackItems(by category: ItemCategory) -> [BackpackItem] {
        return mockBackpackItems.filter { $0.category == category }
    }

    /// 格式化探索结果摘要
    static func getExplorationSummary() -> String {
        let result = mockExplorationResult
        return """
        探索摘要：
        - 探索时长：\(result.durationInMinutes) 分钟
        - 行走距离：本次 \(Int(result.distanceWalked))m，累计 \(Int(result.totalDistanceWalked))m（排名 #\(result.distanceRanking)）
        - 获得物品：\(result.itemsFound.count) 种，共 \(result.itemsFound.reduce(0) { $0 + $1.quantity }) 个
        """
    }
}
