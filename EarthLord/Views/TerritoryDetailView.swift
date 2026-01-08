//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情视图
//  显示单个领地的详细信息和地图
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    let territory: Territory

    // MARK: - 状态

    @State private var region: MKCoordinateRegion
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - 初始化

    init(territory: Territory) {
        self.territory = territory

        // 计算地图中心点和缩放级别
        let coordinates = territory.toCoordinates()
        if let firstCoordinate = coordinates.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: firstCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            // 默认中心点（北京）
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 地图预览
                mapPreview

                // 基本信息卡片
                infoCard

                // 操作按钮
                actionButtons
            }
            .padding()
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("领地详情")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "确定要删除这块领地吗？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deleteTerritory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将无法恢复")
        }
    }

    // MARK: - 子视图

    /// 地图预览
    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("领地范围")
                .font(.headline)
                .foregroundColor(.white)

            Map(coordinateRegion: $region, annotationItems: [territory]) { item in
                MapAnnotation(coordinate: item.toCoordinates().first ?? CLLocationCoordinate2D()) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                }
            }
            .frame(height: 300)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 基本信息卡片
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                DetailRow(
                    icon: "flag.fill",
                    label: "领地名称",
                    value: territory.name ?? "未命名领地"
                )

                Divider()
                    .background(Color.white.opacity(0.1))

                DetailRow(
                    icon: "square.dashed",
                    label: "面积",
                    value: formatArea(territory.area)
                )

                Divider()
                    .background(Color.white.opacity(0.1))

                if let pointCount = territory.pointCount {
                    DetailRow(
                        icon: "mappin.circle",
                        label: "路径点数",
                        value: "\(pointCount) 个"
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                }

                DetailRow(
                    icon: "checkmark.circle",
                    label: "状态",
                    value: (territory.isActive ?? true) ? "激活" : "未激活"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
            )
        }
    }

    /// 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 编辑按钮
            Button(action: {
                // TODO: 实现编辑功能
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("编辑领地")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // 删除按钮
            Button(action: {
                showDeleteConfirm = true
            }) {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash.fill")
                    }
                    Text(isDeleting ? "删除中..." : "删除领地")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isDeleting)
        }
    }

    // MARK: - 方法

    /// 格式化面积
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 删除领地
    private func deleteTerritory() {
        isDeleting = true

        // TODO: 实现删除功能
        // 需要在 TerritoryManager 中添加删除方法

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isDeleting = false
            dismiss()
        }
    }
}

// MARK: - 详情行视图

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TerritoryDetailView(
            territory: Territory(
                id: "test-id",
                userId: "test-user",
                name: "测试领地",
                path: [["lat": 39.9042, "lon": 116.4074]],
                area: 1500,
                pointCount: 20,
                isActive: true
            )
        )
    }
}
