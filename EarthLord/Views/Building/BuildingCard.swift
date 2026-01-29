//
//  BuildingCard.swift
//  EarthLord
//
//  第29天：建筑卡片网格组件
//

import SwiftUI

/// 建筑卡片（用于建筑浏览器网格）
struct BuildingCard: View {
    let template: BuildingTemplate
    let playerResources: [String: Int]

    init(template: BuildingTemplate, playerResources: [String: Int] = [:]) {
        self.template = template
        self.playerResources = playerResources
    }

    /// 检查资源是否足够
    private var canAfford: Bool {
        for (resource, required) in template.requiredResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                return false
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：图标和等级
            HStack {
                // 建筑图标
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: template.icon)
                        .font(.system(size: 24))
                        .foregroundColor(template.category.color)
                }

                Spacer()

                // Tier 标签
                Text("T\(template.tier)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.primary.opacity(0.2))
                    .foregroundColor(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }

            // 建筑名称
            Text(template.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            // 资源需求（简化显示）
            HStack(spacing: 8) {
                ForEach(Array(template.requiredResources.keys.sorted().prefix(2)), id: \.self) { resource in
                    let required = template.requiredResources[resource] ?? 0
                    let available = playerResources[resource] ?? 0
                    let isEnough = available >= required

                    HStack(spacing: 4) {
                        Image(systemName: resourceIcon(for: resource))
                            .font(.system(size: 10))
                        Text("\(required)")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(isEnough ? ApocalypseTheme.textSecondary : ApocalypseTheme.danger)
                }

                if template.requiredResources.count > 2 {
                    Text("+\(template.requiredResources.count - 2)")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            // 建造时间
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(formatBuildTime(template.buildTimeSeconds))
                    .font(.system(size: 11))
            }
            .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    canAfford ? ApocalypseTheme.primary.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    /// 资源图标
    private func resourceIcon(for resource: String) -> String {
        switch resource {
        case "wood": return "leaf.fill"
        case "stone": return "mountain.2.fill"
        case "metal": return "gearshape.fill"
        case "glass": return "square.fill"
        default: return "questionmark.circle"
        }
    }

    /// 格式化建造时间
    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分钟"
        } else {
            return "\(seconds / 3600)小时"
        }
    }
}

// MARK: - BuildingCategory 颜色扩展

extension BuildingCategory {
    var color: Color {
        switch self {
        case .survival: return ApocalypseTheme.warning
        case .storage: return ApocalypseTheme.info
        case .production: return ApocalypseTheme.success
        case .energy: return ApocalypseTheme.primary
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
        description: "简单的篝火",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 30,
        maxPerTerritory: 3,
        maxLevel: 5
    )

    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
        BuildingCard(template: sampleTemplate, playerResources: ["wood": 50, "stone": 25])
        BuildingCard(template: sampleTemplate, playerResources: ["wood": 10, "stone": 5])
    }
    .padding()
    .background(ApocalypseTheme.background)
}
