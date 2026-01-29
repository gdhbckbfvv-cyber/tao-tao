//
//  BuildingModels.swift
//  EarthLord
//
//  第28天：建筑系统数据模型
//  包含：建筑分类、建筑状态、建筑模板、玩家建筑、建筑错误
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - 建筑分类枚举

/// 建筑分类
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    /// 显示名称（中文）
    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    /// 系统图标名称
    var icon: String {
        switch self {
        case .survival: return "house.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态枚举

/// 建筑状态（状态机）
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active: return .green
        }
    }
}

// MARK: - 建筑模板

/// 建筑模板（从本地配置文件加载的静态数据）
struct BuildingTemplate: Codable, Identifiable {
    let id: UUID
    let templateId: String
    let name: String
    let category: BuildingCategory
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name
        case category
        case tier
        case description
        case icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

// MARK: - 建筑模板数据（配置文件外层包装）

/// 配置文件的顶层结构
struct BuildingTemplateData: Codable {
    let version: String
    let templates: [BuildingTemplate]
}

// MARK: - 玩家建筑

/// 玩家建筑（数据库记录）
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    var buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?

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

// MARK: - 建筑错误

/// 建筑系统错误类型
enum BuildingError: LocalizedError {
    case notAuthenticated                       // 用户未登录
    case insufficientResources([String: Int])   // 资源不足（键：资源名，值：缺少数量）
    case maxBuildingsReached(Int)               // 达到上限
    case templateNotFound                       // 模板不存在
    case invalidStatus                          // 状态不对（如建造中不能升级）
    case maxLevelReached                        // 已达最大等级
    case databaseError(String)                  // 数据库错误

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key) 还需 \($0.value)" }.joined(separator: ", ")
            return "资源不足: \(items)"
        case .maxBuildingsReached(let max):
            return "已达到建筑上限 (\(max))"
        case .templateNotFound:
            return "建筑模板不存在"
        case .invalidStatus:
            return "只能升级运行中的建筑"
        case .maxLevelReached:
            return "建筑已达最大等级"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}

// MARK: - 玩家建筑扩展

extension PlayerBuilding {

    /// 建造进度（0.0 ~ 1.0）
    var buildProgress: Double {
        guard status == .constructing,
              let completedAt = buildCompletedAt else { return 0 }

        let total = completedAt.timeIntervalSince(buildStartedAt)
        guard total > 0 else { return 0 }

        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return min(1.0, max(0, elapsed / total))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        guard status == .constructing,
              let completedAt = buildCompletedAt else { return "" }

        let remaining = completedAt.timeIntervalSince(Date())
        guard remaining > 0 else { return "即将完成" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// 坐标（便捷属性）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 是否建造完成
    var isConstructionComplete: Bool {
        if status == .active { return true }
        guard status == .constructing,
              let completedAt = buildCompletedAt else { return false }
        return Date() >= completedAt
    }
}
