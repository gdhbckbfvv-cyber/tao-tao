//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、自动居中用户位置
//

import SwiftUI
import MapKit

/// 地图视图（UIKit MapView 的 SwiftUI 包装）
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - 绑定属性

    /// 用户位置坐标
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位居中
    @Binding var hasLocatedUser: Bool

    /// 路径追踪坐标点（圈地路径）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本（用于触发 SwiftUI 更新）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否已闭合（Day16）
    var isPathClosed: Bool

    /// 已保存的领地列表（Day19）
    @Binding var savedTerritories: [Territory]

    /// 当前用户ID（Day19：用于区分自己的领地和别人的领地）
    var currentUserId: String

    /// POI 列表（物品点标记）
    @Binding var pois: [POI]

    // MARK: - UIViewRepresentable 协议

    /// 创建 UIView（MKMapView）
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid // 卫星图 + 道路标签（末世废土风格）
        mapView.pointOfInterestFilter = .excludingAll // 隐藏所有 POI（商店、餐厅等）
        mapView.showsBuildings = false // 隐藏 3D 建筑
        mapView.showsUserLocation = true // 显示用户位置蓝点（关键！）

        // 交互配置
        mapView.isZoomEnabled = true // 允许双指缩放
        mapView.isScrollEnabled = true // 允许单指拖动
        mapView.isRotateEnabled = true // 允许旋转
        mapView.isPitchEnabled = false // 禁用倾斜（俯视更符合战略游戏）

        // 设置代理（关键！用于接收位置更新回调）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        print("🗺️ MKMapView 创建完成")
        return mapView
    }

    /// 更新 UIView（当路径坐标更新时重新绘制轨迹）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 当路径更新版本变化时，重新绘制轨迹（Day16: 传入 isPathClosed）
        context.coordinator.updateTrackingPath(on: uiView, coordinates: trackingPath, isPathClosed: isPathClosed)

        // Day19: 更新已保存的领地（传入当前用户ID）
        context.coordinator.updateSavedTerritories(on: uiView, territories: savedTerritories, currentUserId: currentUserId)

        // 更新 POI 标记
        context.coordinator.updatePOIs(on: uiView, pois: pois)
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    // MARK: - 末世滤镜

    /// 应用末世滤镜效果（废土泛黄、降低饱和度）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey) // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey) // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey) // 泛黄强度

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
            print("🎨 末世滤镜已应用")
        } else {
            print("⚠️ 滤镜创建失败")
        }
    }

    // MARK: - Coordinator

    /// 协调器（处理 MKMapView 的代理回调）
    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - ⭐ 关键方法：用户位置更新时调用

        /// 用户位置更新回调（这是地图自动居中的核心！）
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else {
                print("⚠️ 用户位置为空，跳过更新")
                return
            }

            print("📍 地图接收到位置更新:")
            print("   纬度: \(location.coordinate.latitude)")
            print("   经度: \(location.coordinate.longitude)")

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经完成首次居中，不再重复居中（允许用户手动拖动地图）
            guard !hasInitialCentered else {
                print("✅ 已完成首次居中，不再自动居中")
                return
            }

            // 创建居中区域（约 1 公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000, // 纬度方向 1 公里
                longitudinalMeters: 1000  // 经度方向 1 公里
            )

            print("🎯 首次定位成功，自动居中地图...")
            print("   中心点: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            print("   范围: 1000m x 1000m")

            // 平滑居中地图（animated: true 实现平滑过渡）
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("✅ 首次居中完成")
        }

        // MARK: - 其他代理方法

        /// 地图区域改变完成
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里记录用户拖动地图的行为
            // print("🗺️ 地图区域改变")
        }

        /// 地图加载完成
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ 地图加载完成")
        }

        /// 地图加载失败
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ 地图加载失败: \(error.localizedDescription)")
        }

        // MARK: - 路径追踪相关

        /// 当前轨迹覆盖物（用于删除旧轨迹）
        private var currentPathOverlay: MKPolyline?

        /// 当前多边形覆盖物（用于删除旧多边形）Day16
        private var currentPolygonOverlay: MKPolygon?

        /// 路径是否已闭合（用于渲染器判断颜色）Day16
        private var isPathClosed: Bool = false

        /// 已保存的领地多边形覆盖物（Day19）
        private var savedTerritoryOverlays: [String: MKPolygon] = [:] // territoryId -> MKPolygon

        /// 当前用户ID（Day19：用于渲染器判断颜色）
        private var currentUserId: String = ""

        /// 更新追踪路径
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - coordinates: 路径坐标点数组
        ///   - isPathClosed: 路径是否已闭合（Day16）
        func updateTrackingPath(on mapView: MKMapView, coordinates: [CLLocationCoordinate2D], isPathClosed: Bool) {
            // 更新闭环状态（Day16）
            self.isPathClosed = isPathClosed

            // 删除旧的轨迹
            if let oldOverlay = currentPathOverlay {
                mapView.removeOverlay(oldOverlay)
                currentPathOverlay = nil
            }

            // 删除旧的多边形（Day16）
            if let oldPolygon = currentPolygonOverlay {
                mapView.removeOverlay(oldPolygon)
                currentPolygonOverlay = nil
            }

            // 如果路径点少于 2 个，不绘制
            guard coordinates.count >= 2 else {
                return
            }

            print("🎨 更新轨迹:")
            print("   路径点数: \(coordinates.count)")
            print("   是否闭合: \(isPathClosed)")

            // 坐标转换：WGS-84 → GCJ-02（中国火星坐标系）
            let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

            print("   坐标转换完成（WGS-84 → GCJ-02）")

            // 创建折线（MKPolyline）
            let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)

            // 添加到地图
            mapView.addOverlay(polyline)
            currentPathOverlay = polyline

            print("✅ 轨迹已绘制到地图")

            // Day16: 如果路径已闭合，绘制多边形填充
            if isPathClosed && gcj02Coordinates.count >= 3 {
                let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
                mapView.addOverlay(polygon)
                currentPolygonOverlay = polygon
                print("✅ 多边形已绘制到地图")
            }
        }

        /// 更新已保存的领地（Day19）
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - territories: 已保存的领地列表
        ///   - currentUserId: 当前用户ID（用于区分颜色）
        func updateSavedTerritories(on mapView: MKMapView, territories: [Territory], currentUserId: String) {
            // 更新当前用户ID（用于渲染器判断颜色）
            self.currentUserId = currentUserId

            print("🗺️ 更新已保存领地:")
            print("   领地数量: \(territories.count)")
            print("   当前用户ID: \(currentUserId)")

            // 获取当前应该显示的领地 ID 集合
            let currentTerritoryIds = Set(territories.map { $0.id })

            // 删除不再存在的领地
            let overlaysToRemove = savedTerritoryOverlays.filter { !currentTerritoryIds.contains($0.key) }
            for (territoryId, overlay) in overlaysToRemove {
                mapView.removeOverlay(overlay)
                savedTerritoryOverlays.removeValue(forKey: territoryId)
                print("   ➖ 删除领地: \(territoryId)")
            }

            // 添加或更新领地
            for territory in territories {
                let coordinates = territory.toCoordinates()
                guard coordinates.count >= 3 else {
                    print("   ⚠️ 领地 \(territory.id) 坐标点不足，跳过")
                    continue
                }

                // 坐标转换：WGS-84 → GCJ-02
                let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(coordinates)

                // 如果该领地已存在，先删除旧的
                if let oldOverlay = savedTerritoryOverlays[territory.id] {
                    mapView.removeOverlay(oldOverlay)
                }

                // 创建新的多边形
                let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
                polygon.title = territory.id // 使用 title 属性存储领地 ID
                polygon.subtitle = territory.userId // 使用 subtitle 属性存储用户 ID（用于判断颜色）

                // 添加到地图
                mapView.addOverlay(polygon)
                savedTerritoryOverlays[territory.id] = polygon

                // 判断是自己的还是别人的
                let isOwnTerritory = territory.userId.lowercased() == currentUserId.lowercased()
                let ownerType = isOwnTerritory ? "自己" : "他人"
                print("   ✅ 添加/更新领地: \(territory.id) (\(String(format: "%.0f", territory.area))m²) - \(ownerType)")
            }

            print("✅ 领地更新完成，当前显示 \(savedTerritoryOverlays.count) 块领地")
        }

        /// 提供覆盖物渲染器（绘制轨迹样式）
        /// - Parameters:
        ///   - mapView: 地图视图
        ///   - overlay: 覆盖物对象
        /// - Returns: 覆盖物渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 如果是折线覆盖物，返回折线渲染器
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // Day16: 根据是否闭环改变轨迹颜色
                let strokeColor: UIColor
                let colorName: String

                if isPathClosed {
                    strokeColor = UIColor.systemGreen.withAlphaComponent(0.8) // 绿色半透明
                    colorName = "绿色半透明（已闭环）"
                } else {
                    strokeColor = UIColor.systemCyan.withAlphaComponent(0.8) // 青色半透明
                    colorName = "青色半透明（未闭环）"
                }

                // 轨迹样式配置
                renderer.strokeColor = strokeColor
                renderer.lineWidth = 4 // 线条宽度 4 像素
                renderer.lineCap = .round // 圆角端点
                renderer.lineJoin = .round // 圆角连接点

                print("🎨 渲染轨迹:")
                print("   颜色: \(colorName)")
                print("   宽度: 4px")

                return renderer
            }

            // Day16: 如果是多边形覆盖物，返回多边形渲染器
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // Day19: 区分当前追踪路径、自己的领地、别人的领地
                if let territoryId = polygon.title, let territoryUserId = polygon.subtitle {
                    // 已保存的领地：根据用户ID判断颜色
                    let isOwnTerritory = territoryUserId.lowercased() == currentUserId.lowercased()

                    if isOwnTerritory {
                        // 自己的领地：绿色
                        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3) // 半透明绿色填充
                        renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8) // 绿色边框
                        renderer.lineWidth = 3 // 边框宽度 3 像素

                        print("🎨 渲染自己的领地:")
                        print("   领地ID: \(territoryId)")
                        print("   填充色: 半透明绿色")
                        print("   边框色: 绿色")
                    } else {
                        // 别人的领地：橙色
                        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.3) // 半透明橙色填充
                        renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8) // 橙色边框
                        renderer.lineWidth = 3 // 边框宽度 3 像素

                        print("🎨 渲染他人的领地:")
                        print("   领地ID: \(territoryId)")
                        print("   填充色: 半透明橙色")
                        print("   边框色: 橙色")
                    }
                } else {
                    // 当前追踪路径（已闭环）：浅绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25) // 半透明绿色填充
                    renderer.strokeColor = UIColor.systemGreen // 绿色边框
                    renderer.lineWidth = 2 // 边框宽度 2 像素

                    print("🎨 渲染追踪多边形:")
                    print("   填充色: 半透明绿色")
                    print("   边框色: 绿色")
                }

                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - POI 标记管理

        /// 已添加的 POI 标注（用于防止重复添加）
        private var poiAnnotations: [String: POIAnnotation] = [:]

        /// 更新 POI 标记
        func updatePOIs(on mapView: MKMapView, pois: [POI]) {
            print("📍 更新POI标记:")
            print("   POI数量: \(pois.count)")

            // 获取当前应该显示的 POI ID 集合
            let currentPOIIds = Set(pois.map { $0.id })

            // 删除不再存在的 POI
            let annotationsToRemove = poiAnnotations.filter { !currentPOIIds.contains($0.key) }
            for (poiId, annotation) in annotationsToRemove {
                mapView.removeAnnotation(annotation)
                poiAnnotations.removeValue(forKey: poiId)
                print("   ➖ 删除POI: \(poiId)")
            }

            // 添加新的 POI
            for poi in pois {
                // 如果 POI 已存在，跳过
                if poiAnnotations[poi.id] != nil {
                    continue
                }

                // 创建并添加标注
                let annotation = POIAnnotation(poi: poi)
                mapView.addAnnotation(annotation)
                poiAnnotations[poi.id] = annotation
                print("   ✅ 添加POI: \(poi.name) - \(poi.type.rawValue)")
            }

            print("✅ POI更新完成，当前显示 \(poiAnnotations.count) 个POI")
        }

        /// 提供标注视图（自定义POI标记样式）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 如果是用户位置标注，返回 nil（使用系统默认）
            if annotation is MKUserLocation {
                return nil
            }

            // 如果是 POI 标注，自定义样式
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true // 允许显示气泡
                } else {
                    annotationView?.annotation = annotation
                }

                if let markerView = annotationView as? MKMarkerAnnotationView {
                    // 根据 POI 状态设置颜色
                    switch poiAnnotation.poi.status {
                    case .undiscovered:
                        markerView.markerTintColor = .systemGray // 灰色：未发现
                    case .discovered:
                        markerView.markerTintColor = .systemGreen // 绿色：已发现（有物资）
                    case .looted:
                        markerView.markerTintColor = .systemRed // 红色：已搜空
                    }

                    // 设置图标
                    markerView.glyphImage = UIImage(systemName: "cube.box.fill")
                }

                return annotationView
            }

            return nil
        }
    }
}
