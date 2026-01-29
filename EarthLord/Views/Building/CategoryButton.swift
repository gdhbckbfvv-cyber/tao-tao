//
//  CategoryButton.swift
//  EarthLord
//
//  第29天：建筑分类筛选按钮组件
//

import SwiftUI

/// 建筑分类筛选按钮
struct BuildingCategoryButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? ApocalypseTheme.primary
                    : ApocalypseTheme.cardBackground
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : ApocalypseTheme.textSecondary
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 12) {
        BuildingCategoryButton(title: "全部", isSelected: true, action: {})
        BuildingCategoryButton(title: "生存", icon: "house.fill", isSelected: false, action: {})
        BuildingCategoryButton(title: "储存", icon: "archivebox.fill", isSelected: false, action: {})
    }
    .padding()
    .background(ApocalypseTheme.background)
}
