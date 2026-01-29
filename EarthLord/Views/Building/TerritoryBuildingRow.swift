//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  第29天：领地建筑列表行组件
//

import SwiftUI
import Combine

/// 领地建筑列表行（含操作菜单）
struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    var onUpgrade: (() -> Void)?
    var onDemolish: (() -> Void)?

    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：分类图标
            categoryIcon

            // 中间：名称 + 状态
            VStack(alignment: .leading, spacing: 4) {
                // 名称和等级
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if building.status == .active {
                        Text("Lv.\(building.level)")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.primary.opacity(0.2))
                            .foregroundColor(ApocalypseTheme.primary)
                            .cornerRadius(6)
                    }
                }

                // 状态标签
                HStack(spacing: 6) {
                    // 状态徽章
                    Text(building.status.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(building.status.color.opacity(0.2))
                        .foregroundColor(building.status.color)
                        .cornerRadius(8)

                    // 建造中显示剩余时间
                    if building.status == .constructing {
                        Text(building.formattedRemainingTime)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }

            Spacer()

            // 右侧：操作菜单或进度环
            if building.status == .active {
                actionMenu
            } else if building.status == .constructing {
                progressRing
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    // MARK: - 分类图标

    @ViewBuilder
    private var categoryIcon: some View {
        let category = template?.category ?? .survival
        ZStack {
            Circle()
                .fill(category.color.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: template?.icon ?? category.icon)
                .font(.system(size: 20))
                .foregroundColor(category.color)
        }
    }

    // MARK: - 操作菜单

    @ViewBuilder
    private var actionMenu: some View {
        Menu {
            // 升级按钮
            if let template = template, building.level >= template.maxLevel {
                Button {} label: {
                    Label("已达最高等级", systemImage: "checkmark.circle.fill")
                }
                .disabled(true)
            } else {
                Button {
                    onUpgrade?()
                } label: {
                    Label("升级", systemImage: "arrow.up.circle")
                }
            }

            Divider()

            // 拆除按钮
            Button(role: .destructive) {
                onDemolish?()
            } label: {
                Label("拆除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)
        }
    }

    // MARK: - 进度环

    @ViewBuilder
    private var progressRing: some View {
        ZStack {
            // 背景环
            Circle()
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 4)

            // 进度环
            Circle()
                .trim(from: 0, to: building.buildProgress)
                .stroke(building.status.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: building.buildProgress)

            // 百分比文字
            Text("\(Int(building.buildProgress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(width: 40, height: 40)
    }
}

#Preview {
    let sampleBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "campfire",
        buildingName: "篝火",
        status: .active,
        level: 3,
        locationLat: nil,
        locationLon: nil,
        buildStartedAt: Date(),
        buildCompletedAt: nil
    )

    let sampleTemplate = BuildingTemplate(
        id: UUID(),
        templateId: "campfire",
        name: "篝火",
        category: .survival,
        tier: 1,
        description: "简单的篝火",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 30,
        maxPerTerritory: 3,
        maxLevel: 5
    )

    let constructingBuilding = PlayerBuilding(
        id: UUID(),
        userId: UUID(),
        territoryId: "test",
        templateId: "shelter",
        buildingName: "庇护所",
        status: .constructing,
        level: 1,
        locationLat: nil,
        locationLon: nil,
        buildStartedAt: Date().addingTimeInterval(-30),
        buildCompletedAt: Date().addingTimeInterval(30)
    )

    return VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: sampleBuilding,
            template: sampleTemplate,
            onUpgrade: {},
            onDemolish: {}
        )

        TerritoryBuildingRow(
            building: constructingBuilding,
            template: sampleTemplate
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
