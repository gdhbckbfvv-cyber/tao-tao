//
//  CollisionModels.swift
//  EarthLord
//
//  Day 19: 碰撞检测核心模型和方法
//

import Foundation
import CoreLocation

// MARK: - 预警级别枚举

/// 领地碰撞预警级别（5 级）
enum WarningLevel {
    case safe           // 安全区（> 100m）
    case notice         // 提醒区（50-100m）
    case caution        // 警告区（20-50m）
    case danger         // 危险区（< 20m）
    case violation      // 违规区（在领地内或穿越边界）

    var description: String {
        switch self {
        case .safe:
            return "安全"
        case .notice:
            return "发现附近领地"
        case .caution:
            return "接近他人领地"
        case .danger:
            return "危险：距离他人领地过近"
        case .violation:
            return "违规：进入他人领地"
        }
    }

    var color: String {
        switch self {
        case .safe:
            return "绿色"
        case .notice:
            return "蓝色"
        case .caution:
            return "黄色"
        case .danger:
            return "橙色"
        case .violation:
            return "红色"
        }
    }

    /// 震动强度（0-1.0）
    var hapticIntensity: Double {
        switch self {
        case .safe:
            return 0.0
        case .notice:
            return 0.3
        case .caution:
            return 0.5
        case .danger:
            return 0.7
        case .violation:
            return 1.0
        }
    }
}

// MARK: - 碰撞检测结果

/// 点碰撞检测结果
struct PointCollisionResult {
    let hasCollision: Bool              // 是否碰撞
    let warningLevel: WarningLevel      // 预警级别
    let distance: Double                // 到最近领地的距离（米）
    let nearestTerritory: Territory?    // 最近的领地
}

/// 路径碰撞检测结果
struct PathCollisionResult {
    let hasCollision: Bool              // 是否碰撞
    let crossesTerritory: Bool          // 是否穿越领地
    let conflictTerritory: Territory?   // 冲突的领地
}

// MARK: - 碰撞检测核心方法

class CollisionDetector {

    // MARK: - 点在多边形内检测（射线法）

    /// 检测点是否在多边形内（Ray Casting Algorithm）
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: true 表示点在多边形内
    static func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            // 射线法：从点向右发射射线，统计与多边形边的交点数
            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }

            j = i
        }

        return inside
    }

    // MARK: - 点到线段距离

    /// 计算点到线段的最短距离
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - lineStart: 线段起点
    ///   - lineEnd: 线段终点
    /// - Returns: 距离（米）
    static func distanceFromPointToLineSegment(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let endLoc = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        let lineLength = startLoc.distance(from: endLoc)

        // 如果线段长度接近 0，返回点到起点的距离
        if lineLength < 0.001 {
            return pointLoc.distance(from: startLoc)
        }

        // 计算投影参数 t
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        let t = ((point.longitude - lineStart.longitude) * dx +
                 (point.latitude - lineStart.latitude) * dy) / (dx * dx + dy * dy)

        if t < 0 {
            // 投影点在起点之前，返回点到起点的距离
            return pointLoc.distance(from: startLoc)
        } else if t > 1 {
            // 投影点在终点之后，返回点到终点的距离
            return pointLoc.distance(from: endLoc)
        } else {
            // 投影点在线段上，计算点到投影点的距离
            let projectionLat = lineStart.latitude + t * dy
            let projectionLon = lineStart.longitude + t * dx
            let projectionLoc = CLLocation(latitude: projectionLat, longitude: projectionLon)
            return pointLoc.distance(from: projectionLoc)
        }
    }

    // MARK: - 点到多边形距离

    /// 计算点到多边形的最短距离
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 距离（米）
    static func distanceToPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Double {
        guard polygon.count >= 3 else { return Double.infinity }

        // 如果点在多边形内，距离为 0
        if isPointInPolygon(point: point, polygon: polygon) {
            return 0
        }

        // 计算点到每条边的最短距离
        var minDistance = Double.infinity
        for i in 0..<polygon.count {
            let edgeStart = polygon[i]
            let edgeEnd = polygon[(i + 1) % polygon.count]

            let distance = distanceFromPointToLineSegment(
                point: point,
                lineStart: edgeStart,
                lineEnd: edgeEnd
            )

            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    // MARK: - 线段相交检测

    /// 检测两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    static func segmentsIntersect(
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D,
        p4: CLLocationCoordinate2D
    ) -> Bool {
        // CCW (Counter-Clockwise) 方向判断
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                              (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 两条线段相交的条件：
        // p1, p2 在 p3-p4 两侧 且 p3, p4 在 p1-p2 两侧
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测路径线段是否与多边形相交
    /// - Parameters:
    ///   - lineStart: 路径线段起点
    ///   - lineEnd: 路径线段终点
    ///   - polygon: 多边形顶点数组
    /// - Returns: true 表示相交
    static func isLineIntersectingPolygon(
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D,
        polygon: [CLLocationCoordinate2D]
    ) -> Bool {
        guard polygon.count >= 3 else { return false }

        // 检查线段是否与多边形的任意一条边相交
        for i in 0..<polygon.count {
            let edgeStart = polygon[i]
            let edgeEnd = polygon[(i + 1) % polygon.count]

            if segmentsIntersect(p1: lineStart, p2: lineEnd, p3: edgeStart, p4: edgeEnd) {
                return true
            }
        }

        return false
    }

    // MARK: - 点碰撞检测

    /// 检测点与所有他人领地的碰撞（综合检测）
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - territories: 他人的领地列表
    /// - Returns: 碰撞检测结果
    static func checkPointCollision(
        point: CLLocationCoordinate2D,
        territories: [Territory]
    ) -> PointCollisionResult {
        guard !territories.isEmpty else {
            return PointCollisionResult(
                hasCollision: false,
                warningLevel: .safe,
                distance: Double.infinity,
                nearestTerritory: nil
            )
        }

        var minDistance = Double.infinity
        var nearestTerritory: Territory? = nil

        // 遍历所有领地，找到最近的领地和最小距离
        for territory in territories {
            let polygon = territory.toCoordinates()

            // 检查点是否在领地内
            if isPointInPolygon(point: point, polygon: polygon) {
                return PointCollisionResult(
                    hasCollision: true,
                    warningLevel: .violation,
                    distance: 0,
                    nearestTerritory: territory
                )
            }

            // 计算到领地的距离
            let distance = distanceToPolygon(point: point, polygon: polygon)
            if distance < minDistance {
                minDistance = distance
                nearestTerritory = territory
            }
        }

        // 根据距离判断预警级别
        let warningLevel: WarningLevel
        if minDistance < 20 {
            warningLevel = .danger
        } else if minDistance < 50 {
            warningLevel = .caution
        } else if minDistance < 100 {
            warningLevel = .notice
        } else {
            warningLevel = .safe
        }

        return PointCollisionResult(
            hasCollision: false,
            warningLevel: warningLevel,
            distance: minDistance,
            nearestTerritory: nearestTerritory
        )
    }

    // MARK: - 路径穿越检测

    /// 检测路径是否穿越他人领地边界
    /// - Parameters:
    ///   - lineStart: 路径线段起点
    ///   - lineEnd: 路径线段终点
    ///   - territories: 他人的领地列表
    /// - Returns: 碰撞检测结果
    static func checkPathCrossTerritory(
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D,
        territories: [Territory]
    ) -> PathCollisionResult {
        guard !territories.isEmpty else {
            return PathCollisionResult(
                hasCollision: false,
                crossesTerritory: false,
                conflictTerritory: nil
            )
        }

        // ✅ 配置参数：穿越深度阈值（米）
        // 只有当路径穿入领地内部超过此距离时，才判定为真正的冲突
        // 设置为 3 米可以避免"擦边"误判
        let penetrationThreshold: Double = 3.0

        // 检查路径线段是否与任何领地边界相交
        for territory in territories {
            let polygon = territory.toCoordinates()

            if isLineIntersectingPolygon(lineStart: lineStart, lineEnd: lineEnd, polygon: polygon) {
                // ✅ 方案1+3：检查穿越深度，避免"擦边"误判
                // 计算线段中点
                let midPoint = CLLocationCoordinate2D(
                    latitude: (lineStart.latitude + lineEnd.latitude) / 2.0,
                    longitude: (lineStart.longitude + lineEnd.longitude) / 2.0
                )

                // 检查中点是否在领地内
                let midPointInside = isPointInPolygon(point: midPoint, polygon: polygon)

                // 如果中点在领地内，说明确实穿越了领地
                if midPointInside {
                    print("❌ 路径穿越检测：线段穿入领地内部（中点在领地内）")
                    print("   线段起点: (\(String(format: "%.6f", lineStart.latitude)), \(String(format: "%.6f", lineStart.longitude)))")
                    print("   线段终点: (\(String(format: "%.6f", lineEnd.latitude)), \(String(format: "%.6f", lineEnd.longitude)))")
                    print("   线段中点: (\(String(format: "%.6f", midPoint.latitude)), \(String(format: "%.6f", midPoint.longitude)))")
                    print("   冲突领地 ID: \(territory.id)")

                    return PathCollisionResult(
                        hasCollision: true,
                        crossesTerritory: true,
                        conflictTerritory: territory
                    )
                } else {
                    // 中点不在领地内，检查中点到领地边界的距离
                    let distanceToPolygon = self.distanceToPolygon(point: midPoint, polygon: polygon)

                    if distanceToPolygon < penetrationThreshold {
                        // 距离太近，判定为穿越
                        print("⚠️ 路径穿越检测：线段穿越领地边界（距离 \(String(format: "%.1f", distanceToPolygon))m < \(penetrationThreshold)m）")
                        print("   线段起点: (\(String(format: "%.6f", lineStart.latitude)), \(String(format: "%.6f", lineStart.longitude)))")
                        print("   线段终点: (\(String(format: "%.6f", lineEnd.latitude)), \(String(format: "%.6f", lineEnd.longitude)))")
                        print("   线段中点: (\(String(format: "%.6f", midPoint.latitude)), \(String(format: "%.6f", midPoint.longitude)))")
                        print("   中点到领地距离: \(String(format: "%.1f", distanceToPolygon))m")
                        print("   冲突领地 ID: \(territory.id)")

                        return PathCollisionResult(
                            hasCollision: true,
                            crossesTerritory: true,
                            conflictTerritory: territory
                        )
                    } else {
                        // 只是擦边，不判定为冲突
                        print("✅ 路径穿越检测：线段仅擦过领地边界（距离 \(String(format: "%.1f", distanceToPolygon))m ≥ \(penetrationThreshold)m），允许通过")
                        print("   线段起点: (\(String(format: "%.6f", lineStart.latitude)), \(String(format: "%.6f", lineStart.longitude)))")
                        print("   线段终点: (\(String(format: "%.6f", lineEnd.latitude)), \(String(format: "%.6f", lineEnd.longitude)))")
                        print("   冲突领地 ID: \(territory.id)")
                        // 继续检查其他领地
                    }
                }
            }
        }

        return PathCollisionResult(
            hasCollision: false,
            crossesTerritory: false,
            conflictTerritory: nil
        )
    }

    // MARK: - 综合碰撞检测

    /// 综合检测路径线段碰撞（点 + 线段穿越）
    /// - Parameters:
    ///   - lineStart: 路径线段起点
    ///   - lineEnd: 路径线段终点
    ///   - territories: 他人的领地列表
    /// - Returns: 碰撞检测结果
    static func checkPathCollisionComprehensive(
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D,
        territories: [Territory]
    ) -> PathCollisionResult {
        guard !territories.isEmpty else {
            return PathCollisionResult(
                hasCollision: false,
                crossesTerritory: false,
                conflictTerritory: nil
            )
        }

        // 1. 检查终点是否在领地内
        for territory in territories {
            let polygon = territory.toCoordinates()

            if isPointInPolygon(point: lineEnd, polygon: polygon) {
                return PathCollisionResult(
                    hasCollision: true,
                    crossesTerritory: false,
                    conflictTerritory: territory
                )
            }
        }

        // 2. 检查路径是否穿越领地边界
        return checkPathCrossTerritory(lineStart: lineStart, lineEnd: lineEnd, territories: territories)
    }
}
