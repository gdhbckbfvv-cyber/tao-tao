//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  第29天：地图位置选择器（UIKit MKMapView + MKPolygon）
//

import SwiftUI
import MapKit

/// 建筑位置选择器视图
struct BuildingLocationPickerView: View {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let onSelectLocation: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图视图
                LocationPickerMapView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingTemplates,
                    selectedCoordinate: $selectedCoordinate
                )
                .ignoresSafeArea()

                // 提示信息
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        if selectedCoordinate != nil {
                            Text("已选择位置")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.success)
                        } else {
                            Text("点击地图选择建筑位置")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                        }

                        Text("只能在领地范围内选择位置")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        if let coord = selectedCoordinate {
                            onSelectLocation(coord)
                        }
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }
}

// MARK: - UIKit 地图视图

struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        mapView.showsUserLocation = true

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            polygon.title = "territory"
            mapView.addOverlay(polygon)

            // 设置地图区域
            let region = regionForPolygon(territoryCoordinates)
            mapView.setRegion(region, animated: false)
        }

        // 添加已有建筑标记
        context.coordinator.addExistingBuildings(to: mapView)

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标记
        context.coordinator.updateSelectedAnnotation(on: mapView)
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
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView
        private var selectedAnnotation: MKPointAnnotation?

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        /// 添加已有建筑标记
        func addExistingBuildings(to mapView: MKMapView) {
            for building in parent.existingBuildings {
                // 直接使用数据库坐标，不做 GCJ-02 转换
                guard let coord = building.coordinate else { continue }

                let annotation = ExistingBuildingAnnotation(building: building)
                annotation.coordinate = coord
                annotation.title = building.buildingName

                if let template = parent.buildingTemplates[building.templateId] {
                    annotation.subtitle = template.category.displayName
                }

                mapView.addAnnotation(annotation)
            }
        }

        /// 更新选中位置标记
        func updateSelectedAnnotation(on mapView: MKMapView) {
            // 移除旧的选中标记
            if let old = selectedAnnotation {
                mapView.removeAnnotation(old)
            }

            // 添加新的选中标记
            if let coord = parent.selectedCoordinate {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coord
                annotation.title = "建造位置"
                mapView.addAnnotation(annotation)
                selectedAnnotation = annotation
            }
        }

        /// 处理点击手势
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 验证点击位置是否在领地内
            if isPointInPolygon(coordinate, polygon: parent.territoryCoordinates) {
                parent.selectedCoordinate = coordinate
                print("📍 选择位置: \(coordinate.latitude), \(coordinate.longitude)")
            } else {
                print("⚠️ 点击位置在领地范围外")
            }
        }

        /// 射线法判断点是否在多边形内
        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var isInside = false
            var j = polygon.count - 1

            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude

                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }

            return isInside
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认样式
            if annotation is MKUserLocation {
                return nil
            }

            // 已有建筑标记
            if let buildingAnnotation = annotation as? ExistingBuildingAnnotation {
                let identifier = "ExistingBuilding"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = buildingAnnotation
                }

                // 根据建筑状态设置颜色
                view?.markerTintColor = buildingAnnotation.building.status == .active
                    ? .systemGreen
                    : .systemBlue
                view?.glyphImage = UIImage(systemName: "building.2.fill")

                return view
            }

            // 选中位置标记
            let identifier = "SelectedLocation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            view?.markerTintColor = .systemOrange
            view?.glyphImage = UIImage(systemName: "hammer.fill")

            return view
        }
    }
}

// MARK: - 已有建筑标注

class ExistingBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(building: PlayerBuilding) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }
}

// MARK: - Preview Wrapper

private struct BuildingLocationPickerPreview: View {
    @State private var selectedCoord: CLLocationCoordinate2D? = nil

    var body: some View {
        BuildingLocationPickerView(
            territoryCoordinates: [
                CLLocationCoordinate2D(latitude: 31.230, longitude: 121.470),
                CLLocationCoordinate2D(latitude: 31.231, longitude: 121.470),
                CLLocationCoordinate2D(latitude: 31.231, longitude: 121.471),
                CLLocationCoordinate2D(latitude: 31.230, longitude: 121.471)
            ],
            existingBuildings: [],
            buildingTemplates: [:],
            selectedCoordinate: $selectedCoord,
            onSelectLocation: { _ in },
            onCancel: {}
        )
    }
}

#Preview {
    BuildingLocationPickerPreview()
}
