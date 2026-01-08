//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器
//  负责上传和拉取领地数据
//

import Foundation
import CoreLocation
import Supabase

/// 领地管理器
class TerritoryManager {

    // MARK: - 单例

    static let shared = TerritoryManager()

    // MARK: - 私有属性

    private let supabase = SupabaseConfig.shared

    // MARK: - 初始化

    private init() {}

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...] 格式的数组
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT (Well-Known Text) 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT POLYGON 字符串
    /// ⚠️ 注意：
    /// 1. WKT 格式是「经度在前，纬度在后」
    /// 2. 多边形必须闭合（首尾坐标相同）
    /// 3. 格式：SRID=4326;POLYGON((lon1 lat1, lon2 lat2, ...))
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保多边形闭合（首尾相同）
        var closedCoordinates = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            // 如果首尾不同，添加首点作为终点
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoordinates.append(first)
            }
        }

        // 将坐标转换为 "经度 纬度" 格式的字符串
        let coordinateStrings = closedCoordinates.map { coordinate in
            "\(coordinate.longitude) \(coordinate.latitude)"
        }

        // 拼接 WKT 格式
        let wkt = "SRID=4326;POLYGON((\(coordinateStrings.joined(separator: ", "))))"
        return wkt
    }

    /// 计算边界框（Bounding Box）
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传数据结构

    /// 上传领地的数据结构
    private struct TerritoryUploadData: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - 上传方法

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 领地路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地的时间
    /// - Throws: 上传错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 1. 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "未登录，无法上传领地"
            ])
        }

        // 2. 转换坐标为 JSON 格式
        let pathJSON = coordinatesToPathJSON(coordinates)

        // 3. 转换坐标为 WKT 格式（PostGIS）
        let wktPolygon = coordinatesToWKT(coordinates)

        // 4. 计算边界框
        let bbox = calculateBoundingBox(coordinates)

        // 5. 构建上传数据
        let territoryData = TerritoryUploadData(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            isActive: true
        )

        // 6. 上传到 Supabase
        do {
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ 领地上传成功")
            print("   面积: \(String(format: "%.0f", area))m²")
            print("   点数: \(coordinates.count)")

            // 记录成功日志
            TerritoryLogger.shared.log(
                "领地上传成功！面积: \(Int(area))m²",
                type: .success
            )
        } catch {
            // 记录失败日志
            TerritoryLogger.shared.log(
                "领地上传失败: \(error.localizedDescription)",
                type: .error
            )
            throw error // 重新抛出错误
        }
    }

    // MARK: - 拉取方法

    /// 加载当前用户的所有激活领地
    /// - Returns: 领地数组
    /// - Throws: 查询错误
    func loadAllTerritories() async throws -> [Territory] {
        // 1. 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "未登录，无法加载领地"
            ])
        }

        // 2. 查询当前用户的 is_active = true 的领地
        let response = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString)  // ✅ 关键：只查询当前用户的领地
            .eq("is_active", value: true)
            .order("created_at", ascending: false)    // 按时间倒序排列
            .execute()

        // 3. 解析数据
        let territories = try JSONDecoder().decode([Territory].self, from: response.data)

        print("✅ 加载领地成功")
        print("   用户 ID: \(userId.uuidString)")
        print("   领地数量: \(territories.count)")

        return territories
    }
}
