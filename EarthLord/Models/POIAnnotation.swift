//
//  POIAnnotation.swift
//  EarthLord
//
//  POI 标注（用于在地图上显示兴趣点）
//

import MapKit

/// POI 地图标注
class POIAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let poi: POI

    init(poi: POI) {
        self.poi = poi
        self.coordinate = poi.coordinate.toCLLocationCoordinate2D()
        self.title = poi.name
        self.subtitle = poi.type.rawValue
        super.init()
    }
}
