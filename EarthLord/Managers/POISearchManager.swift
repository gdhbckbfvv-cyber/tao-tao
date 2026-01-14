//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器 - 使用 MKLocalSearch 搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

/// POI 搜索管理器
/// 职责：使用 Apple Maps 数据搜索附近真实地点，并转换为游戏 POI 模型
class POISearchManager {
    static let shared = POISearchManager()

    private init() {}

    // MARK: - Public Methods

    /// 搜索附近 POI（多种类型）
    /// - Parameters:
    ///   - center: 搜索中心点（用户当前位置）
    ///   - radius: 搜索半径（米），默认 1000m
    /// - Returns: POI 数组，按距离排序，最多 20 个
    func searchNearbyPOIs(center: CLLocationCoordinate2D, radius: Double = 1000) async throws -> [POI] {
        print("🔍 [POI搜索] 开始搜索附近地点，中心：(\(center.latitude), \(center.longitude))，半径：\(radius)m")

        // 并发搜索多种类型
        async let supermarkets = searchPOIType("convenience store grocery store supermarket", center: center, radius: radius)
        async let hospitals = searchPOIType("hospital clinic medical center", center: center, radius: radius)
        async let pharmacies = searchPOIType("pharmacy drugstore", center: center, radius: radius)
        async let gasStations = searchPOIType("gas station", center: center, radius: radius)
        async let restaurants = searchPOIType("restaurant food", center: center, radius: radius)
        async let factories = searchPOIType("factory warehouse industrial", center: center, radius: radius)

        // 等待所有搜索完成
        let allResults = try await [supermarkets, hospitals, pharmacies, gasStations, restaurants, factories].flatMap { $0 }

        print("📊 [POI搜索] 原始结果：\(allResults.count) 个地点")

        // 转换为 POI 模型
        let pois = allResults.compactMap { convertToPOI($0, userLocation: center) }

        // 去重（<50m 视为同一地点）
        let deduplicated = deduplicatePOIs(pois)

        // 按距离排序，取前 20 个
        let sorted = deduplicated.sorted { ($0.distanceFromUser ?? Double.infinity) < ($1.distanceFromUser ?? Double.infinity) }
        let final = Array(sorted.prefix(20))

        print("✅ [POI搜索] 最终结果：\(final.count) 个POI")
        return final
    }

    // MARK: - Private Methods

    /// 搜索单个类型的 POI
    private func searchPOIType(_ query: String, center: CLLocationCoordinate2D, radius: Double) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            print("🔍 [POI搜索] \"\(query)\" 找到 \(response.mapItems.count) 个结果")
            return response.mapItems
        } catch {
            print("⚠️ [POI搜索] \"\(query)\" 搜索失败: \(error.localizedDescription)")
            return [] // 失败优雅降级
        }
    }

    /// 将 MKMapItem 转换为 POI 模型
    private func convertToPOI(_ mapItem: MKMapItem, userLocation: CLLocationCoordinate2D) -> POI? {
        // 过滤无效数据
        guard let name = mapItem.name, !name.isEmpty else {
            print("⚠️ [POI转换] 跳过无名称的地点")
            return nil
        }

        let coordinate = mapItem.placemark.coordinate

        // 推断 POI 类型
        let poiType = inferPOIType(from: mapItem)

        // 计算距离
        let distance = calculateDistance(from: userLocation, to: coordinate)

        // 生成随机危险等级（基于类型）
        let dangerLevel = randomDangerLevel(for: poiType)

        return POI(
            id: UUID().uuidString,
            name: name,
            type: poiType,
            coordinate: POI.Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
            status: .undiscovered, // 初始状态
            dangerLevel: dangerLevel,
            estimatedLoot: nil, // 进入 50m 时分配
            description: generateDescription(for: poiType, name: name),
            distanceFromUser: distance
        )
    }

    /// 根据 MKMapItem 推断 POI 类型
    private func inferPOIType(from mapItem: MKMapItem) -> POIType {
        let name = mapItem.name?.lowercased() ?? ""
        let category = mapItem.pointOfInterestCategory?.rawValue.lowercased() ?? ""

        // 根据名称和类别推断
        if name.contains("hospital") || name.contains("clinic") || name.contains("medical") ||
           category.contains("hospital") {
            return .hospital
        } else if name.contains("pharmacy") || name.contains("drugstore") ||
                  category.contains("pharmacy") {
            return .pharmacy
        } else if name.contains("gas") || name.contains("petrol") || name.contains("fuel") ||
                  category.contains("gasstation") {
            return .gasStation
        } else if name.contains("market") || name.contains("grocery") || name.contains("store") ||
                  category.contains("store") || category.contains("grocery") {
            return .supermarket
        } else if name.contains("factory") || name.contains("industrial") || name.contains("plant") {
            return .factory
        } else if name.contains("warehouse") || name.contains("storage") {
            return .warehouse
        } else if name.contains("school") || name.contains("university") || name.contains("college") {
            return .school
        } else if name.contains("restaurant") || name.contains("cafe") || name.contains("food") {
            // 如果是餐厅/咖啡馆，暂时映射为超市（因为 POIType 枚举没有这些类型）
            return .supermarket
        } else {
            // 默认为超市
            return .supermarket
        }
    }

    /// 去重 POI（<50m 视为同一地点）
    private func deduplicatePOIs(_ pois: [POI]) -> [POI] {
        var result: [POI] = []

        for poi in pois {
            let isDuplicate = result.contains { existingPOI in
                let distance = calculateDistance(
                    from: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude),
                    to: CLLocationCoordinate2D(latitude: existingPOI.coordinate.latitude, longitude: existingPOI.coordinate.longitude)
                )
                return distance < 50 // <50m 视为重复
            }

            if !isDuplicate {
                result.append(poi)
            }
        }

        print("🔄 [POI去重] 去重前：\(pois.count)，去重后：\(result.count)")
        return result
    }

    /// 计算两点距离（米）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    /// 生成随机危险等级
    private func randomDangerLevel(for type: POIType) -> Int {
        switch type {
        case .hospital, .pharmacy:
            return Int.random(in: 2...4) // 中等危险
        case .supermarket:
            return Int.random(in: 1...3) // 较低危险
        case .gasStation:
            return Int.random(in: 3...5) // 较高危险（易燃物）
        case .factory, .warehouse:
            return Int.random(in: 3...5) // 较高危险
        case .school:
            return Int.random(in: 1...2) // 低危险
        }
    }

    /// 生成 POI 描述
    private func generateDescription(for type: POIType, name: String) -> String {
        switch type {
        case .hospital:
            return "一座废弃的医疗机构，可能有医疗物资残留"
        case .pharmacy:
            return "药店废墟，或许能找到一些药品"
        case .supermarket:
            return "曾经繁华的超市，现在空无一人"
        case .gasStation:
            return "加油站遗址，小心易燃物"
        case .factory:
            return "工业区废墟，可能有工具和材料"
        case .warehouse:
            return "仓库遗址，曾经存储大量物资"
        case .school:
            return "荒废的学校，安静而孤寂"
        }
    }
}
