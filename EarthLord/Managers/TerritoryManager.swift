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

        // UUID 统一转为小写
        let currentUserIdLower = userId.uuidString.lowercased()

        // 2. 转换坐标为 JSON 格式
        let pathJSON = coordinatesToPathJSON(coordinates)

        // 3. 转换坐标为 WKT 格式（PostGIS）
        let wktPolygon = coordinatesToWKT(coordinates)

        // 4. 计算边界框
        let bbox = calculateBoundingBox(coordinates)

        // 5. 构建上传数据
        let territoryData = TerritoryUploadData(
            userId: currentUserIdLower,  // ✅ 使用小写 UUID
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

        // UUID 统一转为小写
        let currentUserIdLower = userId.uuidString.lowercased()

        // 2. 查询当前用户的 is_active = true 的领地
        let response = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: currentUserIdLower)  // ✅ 关键：只查询当前用户的领地（小写）
            .eq("is_active", value: true)
            .order("created_at", ascending: false)      // 按时间倒序排列
            .execute()

        // 3. 解析数据
        let territories = try JSONDecoder().decode([Territory].self, from: response.data)

        print("✅ 加载领地成功")
        print("   用户 ID: \(currentUserIdLower)")
        print("   领地数量: \(territories.count)")

        return territories
    }

    /// 加载他人的所有激活领地（用于碰撞检测）
    /// - Returns: 他人的领地数组
    /// - Throws: 查询错误
    func loadOthersActiveTerritories() async throws -> [Territory] {
        // 1. 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "未登录，无法加载领地"
            ])
        }

        // 2. 查询他人的 is_active = true 的领地（排除当前用户）
        // 注意：UUID 字符串统一转为小写，避免大小写问题
        let currentUserIdLower = userId.uuidString.lowercased()

        let response = try await supabase
            .from("territories")
            .select()
            .neq("user_id", value: currentUserIdLower)  // ✅ 关键：排除当前用户的领地（小写）
            .eq("is_active", value: true)
            .execute()

        // 3. 解析数据
        let territories = try JSONDecoder().decode([Territory].self, from: response.data)

        print("✅ 加载他人领地成功")
        print("   当前用户 ID: \(currentUserIdLower)")
        print("   他人领地数量: \(territories.count)")

        return territories
    }

    /// 加载所有玩家的激活领地（用于地图显示）
    /// - Returns: 所有玩家的领地数组
    /// - Throws: 查询错误
    func loadAllPlayersActiveTerritories() async throws -> [Territory] {
        // 查询所有 is_active = true 的领地（不过滤用户）
        let response = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()

        // 解析数据
        let territories = try JSONDecoder().decode([Territory].self, from: response.data)

        print("✅ 加载所有玩家领地成功")
        print("   领地总数: \(territories.count)")

        return territories
    }

    /// 获取当前用户ID（Day19）
    /// - Returns: 当前用户ID（小写格式）
    /// - Throws: 未登录错误
    func getCurrentUserId() async throws -> String {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString.lowercased()
        return userId
    }

    // MARK: - 预警级别定义

    /// 领地预警级别
    enum TerritoryWarningLevel {
        case safe           // 安全区（> 50米）
        case caution        // 警告区（20-50米）
        case danger         // 危险区（< 20米）
        case violation      // 违规区（在领地内或穿越边界）

        var description: String {
            switch self {
            case .safe: return "安全"
            case .caution: return "接近他人领地"
            case .danger: return "危险：距离他人领地过近"
            case .violation: return "违规：进入他人领地"
            }
        }

        var color: String {
            switch self {
            case .safe: return "绿色"
            case .caution: return "黄色"
            case .danger: return "橙色"
            case .violation: return "红色"
            }
        }
    }

    // MARK: - 碰撞检测方法

    /// 判断点是否在多边形内（Ray Casting 算法）
    /// - Parameters:
    ///   - point: 要判断的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: true 表示点在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            // Ray Casting 算法：从点向右发射射线，统计与多边形边的交点数
            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                            (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)

            if intersect {
                inside = !inside
            }

            j = i
        }

        return inside
    }

    /// 判断两条线段是否相交（CCW算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D,
        p4: CLLocationCoordinate2D
    ) -> Bool {
        /// CCW 辅助函数：计算叉积判断方向
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断线段相交：两端点分别在另一线段两侧
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 判断线段是否与多边形边界相交
    /// - Parameters:
    ///   - lineStart: 线段起点
    ///   - lineEnd: 线段终点
    ///   - polygon: 多边形顶点数组
    /// - Returns: true 表示线段与多边形边界相交
    func isLineIntersectingPolygon(
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D,
        polygon: [CLLocationCoordinate2D]
    ) -> Bool {
        guard polygon.count >= 3 else { return false }

        // 遍历多边形的每条边
        for i in 0..<polygon.count {
            let edgeStart = polygon[i]
            let edgeEnd = polygon[(i + 1) % polygon.count] // 循环取下一个点

            // 检查线段与多边形边界是否相交
            if segmentsIntersect(p1: lineStart, p2: lineEnd, p3: edgeStart, p4: edgeEnd) {
                return true
            }
        }

        return false
    }

    /// 检测点是否与任何他人领地冲突
    /// - Parameter point: 要检测的点
    /// - Returns: (hasConflict: 是否冲突, conflictTerritory: 冲突的领地)
    func checkTerritoryConflict(at point: CLLocationCoordinate2D) async -> (hasConflict: Bool, conflictTerritory: Territory?) {
        do {
            // 获取所有他人的领地
            let otherTerritories = try await loadOthersActiveTerritories()

            // 检查点是否在任何领地内
            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                if isPointInPolygon(point: point, polygon: polygon) {
                    print("⚠️ 检测到领地冲突（点在多边形内）！")
                    print("   点: (\(point.latitude), \(point.longitude))")
                    print("   冲突领地 ID: \(territory.id)")
                    return (true, territory)
                }
            }

            print("✅ 未检测到领地冲突")
            return (false, nil)

        } catch {
            print("❌ 检测领地冲突失败: \(error.localizedDescription)")
            // 出错时为了安全起见，允许圈地（假设没有冲突）
            return (false, nil)
        }
    }

    /// 检测路径线段是否与任何他人领地冲突
    /// - Parameters:
    ///   - lineStart: 线段起点
    ///   - lineEnd: 线段终点
    /// - Returns: (hasConflict: 是否冲突, conflictTerritory: 冲突的领地)
    func checkPathSegmentConflict(
        from lineStart: CLLocationCoordinate2D,
        to lineEnd: CLLocationCoordinate2D
    ) async -> (hasConflict: Bool, conflictTerritory: Territory?) {
        do {
            // 获取所有他人的领地
            let otherTerritories = try await loadOthersActiveTerritories()

            // 检查线段是否与任何领地相交或在领地内
            for territory in otherTerritories {
                let polygon = territory.toCoordinates()

                // 1. 检查终点是否在多边形内
                if isPointInPolygon(point: lineEnd, polygon: polygon) {
                    print("⚠️ 检测到领地冲突（终点在多边形内）！")
                    print("   线段: (\(lineStart.latitude), \(lineStart.longitude)) → (\(lineEnd.latitude), \(lineEnd.longitude))")
                    print("   冲突领地 ID: \(territory.id)")
                    return (true, territory)
                }

                // 2. 检查线段是否穿过多边形边界
                if isLineIntersectingPolygon(lineStart: lineStart, lineEnd: lineEnd, polygon: polygon) {
                    print("⚠️ 检测到领地冲突（线段穿过边界）！")
                    print("   线段: (\(lineStart.latitude), \(lineStart.longitude)) → (\(lineEnd.latitude), \(lineEnd.longitude))")
                    print("   冲突领地 ID: \(territory.id)")
                    return (true, territory)
                }
            }

            print("✅ 路径线段未检测到冲突")
            return (false, nil)

        } catch {
            print("❌ 检测路径冲突失败: \(error.localizedDescription)")
            // 出错时为了安全起见，允许圈地（假设没有冲突）
            return (false, nil)
        }
    }

    // MARK: - 距离计算方法

    /// 计算点到线段的最短距离
    /// - Parameters:
    ///   - point: 目标点
    ///   - lineStart: 线段起点
    ///   - lineEnd: 线段终点
    /// - Returns: 距离（米）
    private func distanceFromPointToLineSegment(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let endLoc = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        // 线段长度
        let lineLength = startLoc.distance(from: endLoc)

        // 如果线段退化为点
        if lineLength < 0.001 {
            return pointLoc.distance(from: startLoc)
        }

        // 计算投影参数 t
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        let t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / (dx * dx + dy * dy)

        // 根据 t 值判断最近点
        if t < 0 {
            // 最近点是线段起点
            return pointLoc.distance(from: startLoc)
        } else if t > 1 {
            // 最近点是线段终点
            return pointLoc.distance(from: endLoc)
        } else {
            // 最近点在线段上
            let projectionLat = lineStart.latitude + t * dy
            let projectionLon = lineStart.longitude + t * dx
            let projectionLoc = CLLocation(latitude: projectionLat, longitude: projectionLon)
            return pointLoc.distance(from: projectionLoc)
        }
    }

    /// 计算点到多边形的最短距离
    /// - Parameters:
    ///   - point: 目标点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 距离（米）
    func distanceToPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Double {
        guard polygon.count >= 3 else { return Double.infinity }

        var minDistance = Double.infinity

        // 遍历多边形的每条边
        for i in 0..<polygon.count {
            let edgeStart = polygon[i]
            let edgeEnd = polygon[(i + 1) % polygon.count]

            let distance = distanceFromPointToLineSegment(point: point, lineStart: edgeStart, lineEnd: edgeEnd)
            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    /// 综合检测：计算距离最近的他人领地和预警级别
    /// - Parameter point: 当前位置
    /// - Returns: (level: 预警级别, distance: 最短距离, territory: 最近的领地)
    func checkTerritoryWarningLevel(at point: CLLocationCoordinate2D) async -> (
        level: TerritoryWarningLevel,
        distance: Double,
        territory: Territory?
    ) {
        do {
            // 获取所有他人的领地
            let otherTerritories = try await loadOthersActiveTerritories()

            guard !otherTerritories.isEmpty else {
                print("✅ 没有他人领地，安全")
                return (.safe, Double.infinity, nil)
            }

            var minDistance = Double.infinity
            var closestTerritory: Territory? = nil

            // 遍历所有领地，找出最近的
            for territory in otherTerritories {
                let polygon = territory.toCoordinates()

                // 1. 先检查是否在多边形内
                if isPointInPolygon(point: point, polygon: polygon) {
                    print("⚠️ 违规：点在他人领地内（ID: \(territory.id)）")
                    return (.violation, 0, territory)
                }

                // 2. 计算到边界的距离
                let distance = distanceToPolygon(point: point, polygon: polygon)
                if distance < minDistance {
                    minDistance = distance
                    closestTerritory = territory
                }
            }

            // 根据距离判断预警级别
            let level: TerritoryWarningLevel
            if minDistance < 20 {
                level = .danger
                print("⚠️ 危险：距离他人领地 \(String(format: "%.1f", minDistance))m")
            } else if minDistance < 50 {
                level = .caution
                print("⚠️ 警告：距离他人领地 \(String(format: "%.1f", minDistance))m")
            } else {
                level = .safe
                print("✅ 安全：距离他人领地 \(String(format: "%.1f", minDistance))m")
            }

            return (level, minDistance, closestTerritory)

        } catch {
            print("❌ 检测预警级别失败: \(error.localizedDescription)")
            // 出错时返回安全状态
            return (.safe, Double.infinity, nil)
        }
    }
}
