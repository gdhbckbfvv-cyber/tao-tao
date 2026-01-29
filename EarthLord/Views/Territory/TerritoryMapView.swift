//
//  TerritoryMapView.swift
//  EarthLord
//
//  第29天：领地地图组件（UIKit MKMapView）
//  用于领地详情页的全屏地图底层
//

import SwiftUI
import MapKit

/// 领地地图视图（显示领地多边形和建筑标记）
struct TerritoryMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let buildings: [PlayerBuilding]
    let templates: [String: BuildingTemplate]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 设置地图区域
            let region = regionForPolygon(territoryCoordinates)
            mapView.setRegion(region, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新建筑标记
        context.coordinator.updateBuildingAnnotations(on: mapView, buildings: buildings, templates: templates)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 计算多边形的地图区域
    private func regionForPolygon(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.8,
            longitudeDelta: (maxLon - minLon) * 1.8
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView
        private var buildingAnnotations: [TerritoryBuildingAnnotation] = []

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        /// 更新建筑标记
        func updateBuildingAnnotations(
            on mapView: MKMapView,
            buildings: [PlayerBuilding],
            templates: [String: BuildingTemplate]
        ) {
            // 移除旧的建筑标记
            mapView.removeAnnotations(buildingAnnotations)
            buildingAnnotations.removeAll()

            // 添加新的建筑标记
            for building in buildings {
                // 直接使用数据库坐标，不做 GCJ-02 转换
                guard let coord = building.coordinate else { continue }

                let annotation = TerritoryBuildingAnnotation(building: building)
                annotation.coordinate = coord
                annotation.title = building.buildingName

                if let template = templates[building.templateId] {
                    annotation.subtitle = "\(template.category.displayName) · Lv.\(building.level)"
                    annotation.icon = template.icon
                }

                buildingAnnotations.append(annotation)
                mapView.addAnnotation(annotation)
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.15)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认样式
            if annotation is MKUserLocation {
                return nil
            }

            // 建筑标记
            if let buildingAnnotation = annotation as? TerritoryBuildingAnnotation {
                let identifier = "TerritoryBuilding"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = buildingAnnotation
                }

                // 根据建筑状态设置颜色
                let building = buildingAnnotation.building
                switch building.status {
                case .active:
                    view?.markerTintColor = .systemGreen
                case .constructing:
                    view?.markerTintColor = .systemBlue
                }

                // 设置图标
                if let iconName = buildingAnnotation.icon {
                    view?.glyphImage = UIImage(systemName: iconName)
                } else {
                    view?.glyphImage = UIImage(systemName: "building.2.fill")
                }

                return view
            }

            return nil
        }
    }
}

// MARK: - 领地建筑标注

class TerritoryBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var icon: String?

    init(building: PlayerBuilding) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }
}

#Preview {
    TerritoryMapView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.231, longitude: 121.470),
            CLLocationCoordinate2D(latitude: 31.231, longitude: 121.471),
            CLLocationCoordinate2D(latitude: 31.230, longitude: 121.471)
        ],
        buildings: [],
        templates: [:]
    )
}
