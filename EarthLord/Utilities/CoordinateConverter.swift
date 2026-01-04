//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具
//  WGS-84（GPS原始坐标）→ GCJ-02（中国火星坐标系）
//

import Foundation
import CoreLocation

/// 坐标转换工具类
/// 负责处理 WGS-84 和 GCJ-02 坐标系之间的转换
struct CoordinateConverter {

    // MARK: - 常量

    /// 地球半径（米）
    private static let earthRadius = 6378137.0

    /// 偏移量计算常量 a
    private static let a = 6378245.0

    /// 偏移量计算常量 ee（第一偏心率的平方）
    private static let ee = 0.00669342162296594323

    /// π
    private static let pi = Double.pi

    // MARK: - 公开方法

    /// 将 WGS-84 坐标转换为 GCJ-02 坐标
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（火星坐标系）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，不需要转换
        if !isInChina(lat: wgs84.latitude, lon: wgs84.longitude) {
            return wgs84
        }

        // 计算偏移量
        let (dLat, dLon) = delta(lat: wgs84.latitude, lon: wgs84.longitude)

        return CLLocationCoordinate2D(
            latitude: wgs84.latitude + dLat,
            longitude: wgs84.longitude + dLon
        )
    }

    /// 批量转换坐标
    /// - Parameter wgs84Coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ wgs84Coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgs84Coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境内
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lon: 经度
    /// - Returns: 是否在中国
    private static func isInChina(lat: Double, lon: Double) -> Bool {
        // 粗略判断：中国的经纬度范围
        // 纬度：3.86 ~ 53.55（海南到黑龙江）
        // 经度：73.66 ~ 135.05（新疆到东北）
        return lat >= 3.86 && lat <= 53.55 && lon >= 73.66 && lon <= 135.05
    }

    /// 计算偏移量
    /// - Parameters:
    ///   - lat: WGS-84 纬度
    ///   - lon: WGS-84 经度
    /// - Returns: (纬度偏移, 经度偏移)
    private static func delta(lat: Double, lon: Double) -> (Double, Double) {
        let dLat = transformLat(x: lon - 105.0, y: lat - 35.0)
        let dLon = transformLon(x: lon - 105.0, y: lat - 35.0)

        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        let dLatResult = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        let dLonResult = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        return (dLatResult, dLonResult)
    }

    /// 纬度转换函数
    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y
        ret += 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换函数
    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y
        ret += 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
