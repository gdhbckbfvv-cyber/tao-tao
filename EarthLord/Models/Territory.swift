//
//  Territory.swift
//  EarthLord
//
//  领地数据模型
//  用于解析数据库返回的领地数据
//

import Foundation
import CoreLocation

/// 领地数据模型
struct Territory: Codable, Identifiable {

    // MARK: - 属性

    /// 领地 ID
    let id: String

    /// 所属用户 ID
    let userId: String

    /// 领地名称（可选，数据库允许为空）
    let name: String?

    /// 路径坐标数组（格式：[{"lat": x, "lon": y}]）
    let path: [[String: Double]]

    /// 领地面积（平方米）
    let area: Double

    /// 路径点数量（可选）
    let pointCount: Int?

    /// 领地是否激活（可选）
    let isActive: Bool?

    // MARK: - Codable Keys

    /// JSON 字段映射
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
    }

    // MARK: - 辅助方法

    /// 将 path 数据转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
