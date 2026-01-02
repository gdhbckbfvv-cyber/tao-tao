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

    /// 更新 UIView（本项目暂时不需要更新逻辑）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 空实现即可
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
    }
}
