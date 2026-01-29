//
//  BuildingBrowserView.swift
//  EarthLord
//
//  第29天：建筑浏览器视图
//

import SwiftUI

/// 建筑浏览器视图（分类筛选 + 建筑卡片网格）
struct BuildingBrowserView: View {
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @State private var selectedCategory: BuildingCategory? = nil
    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var inventoryManager = InventoryManager.shared

    /// 筛选后的建筑模板
    private var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.buildingTemplates.filter { $0.category == category }
        }
        return buildingManager.buildingTemplates
    }

    /// 玩家资源字典（资源名称 -> 数量）
    private var playerResources: [String: Int] {
        var resources: [String: Int] = [:]
        for item in inventoryManager.inventoryItems {
            if let resourceName = BuildingManager.itemIdToResourceName[item.itemId] {
                resources[resourceName, default: 0] += item.quantity
            }
        }
        return resources
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选栏
                categoryFilterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.cardBackground)

                // 建筑卡片网格
                ScrollView {
                    if filteredTemplates.isEmpty {
                        emptyStateView
                    } else {
                        buildingGrid
                    }
                }
                .background(ApocalypseTheme.background)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("建筑列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                // 确保模板已加载
                if buildingManager.buildingTemplates.isEmpty {
                    buildingManager.loadTemplates()
                }
            }
        }
    }

    // MARK: - 分类筛选栏

    @ViewBuilder
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部按钮
                BuildingCategoryButton(
                    title: "全部",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 分类按钮
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    BuildingCategoryButton(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    // MARK: - 建筑卡片网格

    @ViewBuilder
    private var buildingGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
            spacing: 16
        ) {
            ForEach(filteredTemplates) { template in
                BuildingCard(
                    template: template,
                    playerResources: playerResources
                )
                .onTapGesture {
                    onStartConstruction(template)
                }
            }
        }
        .padding(16)
    }

    // MARK: - 空状态视图

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无建筑")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("该分类下没有可用的建筑")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    BuildingBrowserView(
        onDismiss: {},
        onStartConstruction: { _ in }
    )
}
