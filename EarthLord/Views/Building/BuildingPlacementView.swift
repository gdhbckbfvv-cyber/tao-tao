//
//  BuildingPlacementView.swift
//  EarthLord
//
//  第29天：建造确认视图（资源检查 + 位置选择）
//

import SwiftUI
import CoreLocation

/// 建造确认视图
struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territoryId: String
    let territoryCoordinates: [CLLocationCoordinate2D]
    let onDismiss: () -> Void
    let onConstructionStarted: (PlayerBuilding) -> Void

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var isConstructing = false
    @State private var errorMessage: String?

    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 玩家资源字典
    private var playerResources: [String: Int] {
        var resources: [String: Int] = [:]
        for item in inventoryManager.inventoryItems {
            if let resourceName = BuildingManager.itemIdToResourceName[item.itemId] {
                resources[resourceName, default: 0] += item.quantity
            }
        }
        return resources
    }

    /// 是否资源足够
    private var hasEnoughResources: Bool {
        for (resource, required) in template.requiredResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                return false
            }
        }
        return true
    }

    /// 是否可以建造
    private var canBuild: Bool {
        hasEnoughResources && selectedLocation != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 建筑预览
                    buildingPreview

                    // 位置选择
                    locationSection

                    // 资源消耗
                    resourcesSection

                    // 建造时间
                    buildTimeSection

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.danger)
                            .padding()
                            .background(ApocalypseTheme.danger.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建造确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("确认建造") {
                        startConstruction()
                    }
                    .disabled(!canBuild || isConstructing)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: buildingManager.playerBuildings.filter { $0.territoryId == territoryId },
                    buildingTemplates: Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) }),
                    selectedCoordinate: $selectedLocation,
                    onSelectLocation: { coord in
                        selectedLocation = coord
                        showLocationPicker = false
                    },
                    onCancel: {
                        showLocationPicker = false
                    }
                )
            }
        }
    }

    // MARK: - 建筑预览

    @ViewBuilder
    private var buildingPreview: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.category.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 40))
                    .foregroundColor(template.category.color)
            }

            // 名称和分类
            VStack(spacing: 4) {
                Text(template.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 8) {
                    Text(template.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("•")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("T\(template.tier)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 描述
            Text(template.description)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 位置选择区域

    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造位置")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                        .font(.title2)
                        .foregroundColor(selectedLocation != nil ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedLocation != nil ? "已选择位置" : "点击选择位置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if let location = selectedLocation {
                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        } else {
                            Text("在地图上选择建筑位置")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(16)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 资源消耗区域

    @ViewBuilder
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("资源消耗")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if hasEnoughResources {
                    Label("资源充足", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                } else {
                    Label("资源不足", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.danger)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resource in
                    let required = template.requiredResources[resource] ?? 0
                    let available = playerResources[resource] ?? 0

                    ResourceRow(
                        resourceName: resource,
                        required: required,
                        available: available
                    )
                }
            }
        }
    }

    // MARK: - 建造时间区域

    @ViewBuilder
    private var buildTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造时间")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.info)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formatBuildTime(template.buildTimeSeconds))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("建造完成后自动激活")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - 开始建造

    private func startConstruction() {
        guard let location = selectedLocation else {
            errorMessage = "请先选择建造位置"
            return
        }

        isConstructing = true
        errorMessage = nil

        Task {
            let result = await buildingManager.startConstruction(
                templateId: template.templateId,
                territoryId: territoryId,
                location: (lat: location.latitude, lon: location.longitude)
            )

            await MainActor.run {
                isConstructing = false

                switch result {
                case .success(let building):
                    onConstructionStarted(building)
                case .failure(let error):
                    errorMessage = error.localizedDescription ?? "建造失败，请稍后重试"
                }
            }
        }
    }

    /// 格式化建造时间
    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) 秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes) 分 \(secs) 秒" : "\(minutes) 分钟"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return minutes > 0 ? "\(hours) 小时 \(minutes) 分" : "\(hours) 小时"
        }
    }
}

#Preview {
    let sampleTemplate = BuildingTemplate(
        id: UUID(),
        templateId: "campfire",
        name: "篝火",
        category: .survival,
        tier: 1,
        description: "简单的篝火，提供照明和取暖。末世的第一个夜晚，你需要它。",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 30,
        maxPerTerritory: 3,
        maxLevel: 5
    )

    return BuildingPlacementView(
        template: sampleTemplate,
        territoryId: "test",
        territoryCoordinates: [],
        onDismiss: {},
        onConstructionStarted: { _ in }
    )
}
