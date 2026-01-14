//
//  BackpackView.swift
//  EarthLord
//
//  玩家背包管理页面
//  显示背包容量、物品列表、搜索筛选等
//

import SwiftUI

struct BackpackView: View {
    var body: some View {
        NavigationView {
            BackpackContent()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 背包内容组件（不含NavigationView）

struct BackpackContent: View {

    // MARK: - 状态

    /// 搜索文本
    @State private var searchText = ""

    /// 选中的分类（nil 表示全部）
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 背包物品列表
    @State private var backpackItems: [BackpackItem] = []

    /// 是否正在加载
    @State private var isLoadingItems = false

    /// 背包最大容量（升）
    private let maxCapacity: Double = 100.0

    /// 列表项是否已加载（用于淡入动画）
    @State private var itemsLoaded = false

    /// 动画显示的当前容量（用于数值跳动效果）
    @State private var animatedCapacity: Double = 0.0

    // MARK: - 计算属性

    /// 当前背包使用的容量（升）
    private var currentCapacity: Double {
        return backpackItems.reduce(0) { $0 + $1.totalVolume }
    }

    /// 容量使用百分比（0-1）
    private var capacityPercentage: Double {
        return min(currentCapacity / maxCapacity, 1.0)
    }

    /// 容量进度条颜色
    private var capacityBarColor: Color {
        if capacityPercentage < 0.7 {
            return ApocalypseTheme.success       // 绿色 < 70%
        } else if capacityPercentage < 0.9 {
            return ApocalypseTheme.warning       // 黄色 70-90%
        } else {
            return ApocalypseTheme.danger        // 红色 > 90%
        }
    }

    /// 是否显示背包满警告
    private var showFullWarning: Bool {
        return capacityPercentage > 0.9
    }

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var items = backpackItems

        // 按分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return items
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 【容量状态卡】
                    capacityCard

                    // 【搜索和筛选】
                    searchAndFilter

                    // 【物品列表】
                    itemList
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBackpackItems()
        }
        .refreshable {
            // 下拉刷新
            await loadBackpackItems()
        }
        .onChange(of: selectedCategory) { _ in
            // 切换分类时重新触发动画
            itemsLoaded = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                itemsLoaded = true
            }
        }
    }

    // MARK: - 子视图

    /// 【容量状态卡】
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 容量文本
            HStack {
                Image(systemName: "backpack.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量：\(Int(animatedCapacity)) / \(Int(maxCapacity))")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(Int((animatedCapacity / maxCapacity) * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(capacityBarColor)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12)

                    // 进度
                    RoundedRectangle(cornerRadius: 8)
                        .fill(capacityBarColor)
                        .frame(width: geometry.size.width * (animatedCapacity / maxCapacity), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedCapacity)
                }
            }
            .frame(height: 12)

            // 警告文字
            if showFullWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)

                    Text("背包快满了！")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.danger)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(capacityBarColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    /// 【搜索和筛选】
    private var searchAndFilter: some View {
        VStack(spacing: 15) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("搜索物品名称...", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal)

            // 分类筛选按钮
            VStack(alignment: .leading, spacing: 10) {
                Text("物品分类")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // "全部" 按钮
                        CategoryButton(
                            title: "全部",
                            icon: "square.grid.2x2.fill",
                            color: .gray,
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }

                        // 食物
                        CategoryButton(
                            title: "食物",
                            icon: "fork.knife",
                            color: Color.orange,
                            isSelected: selectedCategory == .food
                        ) {
                            selectedCategory = .food
                        }

                        // 水
                        CategoryButton(
                            title: "水",
                            icon: "drop.fill",
                            color: ApocalypseTheme.info,
                            isSelected: selectedCategory == .water
                        ) {
                            selectedCategory = .water
                        }

                        // 材料
                        CategoryButton(
                            title: "材料",
                            icon: "cube.fill",
                            color: Color.brown,
                            isSelected: selectedCategory == .material
                        ) {
                            selectedCategory = .material
                        }

                        // 工具
                        CategoryButton(
                            title: "工具",
                            icon: "wrench.fill",
                            color: Color.gray,
                            isSelected: selectedCategory == .tool
                        ) {
                            selectedCategory = .tool
                        }

                        // 医疗
                        CategoryButton(
                            title: "医疗",
                            icon: "cross.case.fill",
                            color: ApocalypseTheme.danger,
                            isSelected: selectedCategory == .medical
                        ) {
                            selectedCategory = .medical
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    /// 【物品列表】
    private var itemList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("物品列表")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(filteredItems.count) 个")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal)

            if filteredItems.isEmpty {
                // 空状态
                emptyView
            } else {
                // 物品卡片列表
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    ItemCard(item: item)
                        .opacity(itemsLoaded ? 1.0 : 0.0)
                        .offset(y: itemsLoaded ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.08), value: itemsLoaded)
                }
            }
        }
        .padding(.top, 10)
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: backpackItems.isEmpty ? "backpack" : (searchText.isEmpty ? "magnifyingglass" : "tray"))
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(emptyStateTitle)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 40)
    }

    /// 空状态主标题
    private var emptyStateTitle: String {
        if isLoadingItems {
            return "加载中..."
        } else if backpackItems.isEmpty {
            return "背包空空如也"
        } else if !searchText.isEmpty {
            return "没有找到相关物品"
        } else {
            return "没有该类型的物品"
        }
    }

    /// 空状态副标题
    private var emptyStateSubtitle: String {
        if isLoadingItems {
            return "正在从数据库加载物品"
        } else if backpackItems.isEmpty {
            return "去探索收集物资吧"
        } else if !searchText.isEmpty {
            return "尝试搜索其他关键词"
        } else {
            return "试试切换到其他分类"
        }
    }

    // MARK: - 方法

    /// 加载背包物品
    private func loadBackpackItems() {
        Task {
            isLoadingItems = true

            do {
                let items = try await inventoryManager.loadInventory()

                await MainActor.run {
                    backpackItems = items
                    isLoadingItems = false

                    // 延迟加载动画，让页面先渲染
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        itemsLoaded = true
                        // 容量数值跳动动画
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            animatedCapacity = currentCapacity
                        }
                    }
                }

                print("✅ 背包页面：加载了 \(items.count) 个物品")
            } catch {
                await MainActor.run {
                    isLoadingItems = false
                }
                print("❌ 背包页面：加载物品失败 - \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 分类按钮组件

struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: isSelected ? 0 : 1.5)
            )
        }
    }
}

// MARK: - 物品卡片组件

struct ItemCard: View {
    let item: BackpackItem

    var body: some View {
        HStack(spacing: 15) {
            // 左侧：圆形图标
            ZStack {
                Circle()
                    .fill(colorForCategory(item.category).opacity(0.2))
                    .frame(width: 55, height: 55)

                Image(systemName: iconForCategory(item.category))
                    .font(.title3)
                    .foregroundColor(colorForCategory(item.category))
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 物品名称
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 数量 + 重量
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                        Text("x\(item.quantity)")
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", item.weight))kg")
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 品质 + 稀有度
                HStack(spacing: 8) {
                    // 品质标签（如果有）
                    if let quality = item.quality {
                        qualityBadge(quality: quality)
                    }

                    // 稀有度标签
                    if let definition = getItemDefinition(item.itemId) {
                        rarityBadge(rarity: definition.rarity)
                    }
                }
            }

            Spacer()

            // 右侧：操作按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button(action: {
                    print("🎒 使用物品: \(item.name)")
                }) {
                    Text("使用")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                }

                // 存储按钮
                Button(action: {
                    print("🎒 存储物品: \(item.name)")
                }) {
                    Text("存储")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForCategory(item.category).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    /// 品质标签
    private func qualityBadge(quality: ItemQuality) -> some View {
        Text(quality.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(colorForQuality(quality))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForQuality(quality).opacity(0.15))
            .cornerRadius(6)
    }

    /// 稀有度标签
    private func rarityBadge(rarity: ItemRarity) -> some View {
        Text(rarity.rawValue)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForRarity(rarity))
            .cornerRadius(6)
    }

    /// 获取物品定义（用于获取稀有度）
    private func getItemDefinition(_ itemId: String) -> ItemDefinition? {
        return MockExplorationData.getItemDefinition(by: itemId)
    }

    /// 获取分类对应的图标
    private func iconForCategory(_ category: ItemCategory) -> String {
        switch category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.fill"
        case .tool:
            return "wrench.fill"
        case .weapon:
            return "shield.fill"
        }
    }

    /// 获取分类对应的颜色
    private func colorForCategory(_ category: ItemCategory) -> Color {
        switch category {
        case .water:
            return ApocalypseTheme.info             // 蓝色
        case .food:
            return Color.orange                     // 橙色
        case .medical:
            return ApocalypseTheme.danger           // 红色
        case .material:
            return Color.brown                      // 棕色
        case .tool:
            return Color.gray                       // 灰色
        case .weapon:
            return Color.red                        // 深红色
        }
    }

    /// 获取品质对应的颜色
    private func colorForQuality(_ quality: ItemQuality) -> Color {
        switch quality {
        case .poor:
            return Color.gray                       // 灰色（破损）
        case .normal:
            return Color.white                      // 白色（普通）
        case .good:
            return ApocalypseTheme.success          // 绿色（良好）
        case .excellent:
            return ApocalypseTheme.info             // 蓝色（优秀）
        }
    }

    /// 获取稀有度对应的颜色
    private func colorForRarity(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common:
            return Color.gray                       // 灰色（常见）
        case .uncommon:
            return ApocalypseTheme.success          // 绿色（少见）
        case .rare:
            return ApocalypseTheme.info             // 蓝色（稀有）
        case .epic:
            return Color.purple                     // 紫色（史诗）
        case .legendary:
            return ApocalypseTheme.primary          // 橙色（传说）
        }
    }
}

// MARK: - 预览

#Preview {
    BackpackView()
}
