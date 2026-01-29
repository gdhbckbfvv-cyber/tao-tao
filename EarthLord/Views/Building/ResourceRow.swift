//
//  ResourceRow.swift
//  EarthLord
//
//  第29天：资源消耗行组件
//

import SwiftUI

/// 资源消耗行（用于建造确认页）
struct ResourceRow: View {
    let resourceName: String
    let required: Int
    let available: Int

    /// 是否足够
    private var isEnough: Bool {
        available >= required
    }

    /// 资源显示名称
    private var displayName: String {
        switch resourceName {
        case "wood": return "木材"
        case "stone": return "石头"
        case "metal": return "废金属"
        case "glass": return "玻璃"
        default: return resourceName
        }
    }

    /// 资源图标
    private var icon: String {
        switch resourceName {
        case "wood": return "leaf.fill"
        case "stone": return "mountain.2.fill"
        case "metal": return "gearshape.fill"
        case "glass": return "square.fill"
        default: return "questionmark.circle"
        }
    }

    /// 资源颜色
    private var iconColor: Color {
        switch resourceName {
        case "wood": return Color.green
        case "stone": return Color.gray
        case "metal": return Color.orange
        case "glass": return Color.cyan
        default: return Color.white
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 资源名称
            Text(displayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量对比
            HStack(spacing: 4) {
                Text("\(available)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)

                Text("/")
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("\(required)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 状态图标
            Image(systemName: isEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)
                .font(.system(size: 20))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        ResourceRow(resourceName: "wood", required: 30, available: 50)
        ResourceRow(resourceName: "stone", required: 20, available: 15)
        ResourceRow(resourceName: "metal", required: 40, available: 40)
        ResourceRow(resourceName: "glass", required: 30, available: 0)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
