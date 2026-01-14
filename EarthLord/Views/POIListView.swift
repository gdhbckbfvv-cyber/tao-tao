//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示可探索的POI、搜索附近地点、筛选分类等
//

import SwiftUI

struct POIListView: View {
    var body: some View {
        NavigationView {
            POIListContent()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - POI列表内容组件（不含NavigationView）

struct POIListContent: View {

    // MARK: - 状态

    /// 是否正在搜索附近POI
    @State private var isSearching = false

    /// 当前选中的POI类型筛选（nil 表示全部）
    @State private var selectedPOIType: POIType? = nil

    /// 所有POI数据（从假数据加载）
    @State private var allPOIs: [POI] = MockExplorationData.mockPOIs

    /// 假的GPS坐标（深圳坐标）
    private let mockGPSCoordinate = (latitude: 22.54, longitude: 114.06)

    /// 搜索按钮是否被按下
    @State private var isSearchButtonPressed = false

    /// 列表项是否已加载（用于淡入动画）
    @State private var itemsLoaded = false

    // MARK: - 计算属性

    /// 筛选后的POI列表
    private var filteredPOIs: [POI] {
        if let selectedType = selectedPOIType {
            return allPOIs.filter { $0.type == selectedType }
        }
        return allPOIs
    }

    /// 已发现的POI数量
    private var discoveredPOICount: Int {
        return allPOIs.filter { $0.status != .undiscovered }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 【状态栏】GPS坐标 + 发现数量
                    statusBar

                    // 【搜索按钮】
                    searchButton

                    // 【筛选工具栏】
                    filterToolbar

                    // 【POI列表】
                    poiList
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 延迟加载动画，让页面先渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                itemsLoaded = true
            }
        }
    }

    // MARK: - 子视图

    /// 【状态栏】显示GPS坐标和发现数量
    private var statusBar: some View {
        VStack(spacing: 10) {
            // GPS 坐标
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("GPS: \(String(format: "%.2f", mockGPSCoordinate.latitude)), \(String(format: "%.2f", mockGPSCoordinate.longitude))")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 发现数量
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.info)

                Text("附近发现 \(discoveredPOICount) 个地点")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal)
    }

    /// 【搜索按钮】
    private var searchButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isSearchButtonPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isSearchButtonPressed = false
                }
            }

            performSearch()
        }) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }

                Text(isSearching ? "搜索中..." : "搜索附近POI")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isSearching
                        ? [ApocalypseTheme.primary.opacity(0.6), ApocalypseTheme.primaryDark.opacity(0.6)]
                        : [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .scaleEffect(isSearchButtonPressed ? 0.95 : 1.0)
        .disabled(isSearching)
        .padding(.horizontal)
    }

    /// 【筛选工具栏】横向滚动的分类按钮
    private var filterToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("地点类型")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // "全部" 按钮
                    FilterButton(
                        title: "全部",
                        icon: "map.fill",
                        color: .gray,
                        isSelected: selectedPOIType == nil
                    ) {
                        selectedPOIType = nil
                    }

                    // 各类型按钮
                    FilterButton(
                        title: "医院",
                        icon: "cross.case.fill",
                        color: ApocalypseTheme.danger,
                        isSelected: selectedPOIType == .hospital
                    ) {
                        selectedPOIType = .hospital
                    }

                    FilterButton(
                        title: "超市",
                        icon: "cart.fill",
                        color: ApocalypseTheme.success,
                        isSelected: selectedPOIType == .supermarket
                    ) {
                        selectedPOIType = .supermarket
                    }

                    FilterButton(
                        title: "工厂",
                        icon: "building.2.fill",
                        color: Color.gray,
                        isSelected: selectedPOIType == .factory
                    ) {
                        selectedPOIType = .factory
                    }

                    FilterButton(
                        title: "药店",
                        icon: "pills.fill",
                        color: Color.purple,
                        isSelected: selectedPOIType == .pharmacy
                    ) {
                        selectedPOIType = .pharmacy
                    }

                    FilterButton(
                        title: "加油站",
                        icon: "fuelpump.fill",
                        color: Color.orange,
                        isSelected: selectedPOIType == .gasStation
                    ) {
                        selectedPOIType = .gasStation
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// 【POI列表】显示所有筛选后的POI
    private var poiList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("地点列表")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(filteredPOIs.count) 个")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal)

            if filteredPOIs.isEmpty {
                // 空状态
                emptyView
            } else {
                // POI 卡片列表
                ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                    NavigationLink(destination: POIDetailView(poi: poi)) {
                        POICard(poi: poi)
                    }
                    .buttonStyle(PlainButtonStyle()) // 移除默认的按钮样式
                    .opacity(itemsLoaded ? 1.0 : 0.0)
                    .offset(y: itemsLoaded ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: itemsLoaded)
                }
            }
        }
        .padding(.top, 10)
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: allPOIs.isEmpty ? "map" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(allPOIs.isEmpty ? "附近暂无兴趣点" : "没有找到该类型的地点")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            if allPOIs.isEmpty {
                Text("点击搜索按钮发现周围的废墟")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            } else if selectedPOIType != nil {
                Text("试试切换到其他分类")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 40)
    }

    // MARK: - 方法

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟网络请求，1.5秒后完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSearching = false
            }
            print("🔍 搜索完成，发现 \(allPOIs.count) 个POI")
        }
    }
}

// MARK: - 筛选按钮组件

struct FilterButton: View {
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

// MARK: - POI 卡片组件

struct POICard: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 15) {
            // 左侧：类型图标
            ZStack {
                Circle()
                    .fill(colorForPOIType(poi.type).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: iconForPOIType(poi.type))
                    .font(.title3)
                    .foregroundColor(colorForPOIType(poi.type))
            }

            // 中间：POI 信息
            VStack(alignment: .leading, spacing: 6) {
                // POI 名称
                Text(poi.name)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // POI 类型
                Text(poi.type.rawValue)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 发现状态 + 物资状态
                HStack(spacing: 8) {
                    // 发现状态
                    statusBadge(
                        text: poi.status.rawValue,
                        color: colorForPOIStatus(poi.status)
                    )

                    // 物资状态
                    if poi.status != .undiscovered {
                        if let loot = poi.estimatedLoot, !loot.isEmpty {
                            statusBadge(
                                text: "有物资",
                                color: ApocalypseTheme.success
                            )
                        } else {
                            statusBadge(
                                text: "已搜空",
                                color: ApocalypseTheme.textMuted
                            )
                        }
                    }
                }
            }

            Spacer()

            // 右侧：距离信息
            if let distance = poi.distanceFromUser {
                VStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)

                    Text(formatDistance(distance))
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
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
                .stroke(colorForPOIType(poi.type).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    /// 状态标签
    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    /// 格式化距离
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// 获取POI类型对应的图标
    private func iconForPOIType(_ type: POIType) -> String {
        switch type {
        case .hospital:
            return "cross.case.fill"
        case .supermarket:
            return "cart.fill"
        case .factory:
            return "building.2.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .school:
            return "book.fill"
        }
    }

    /// 获取POI类型对应的颜色
    private func colorForPOIType(_ type: POIType) -> Color {
        switch type {
        case .hospital:
            return ApocalypseTheme.danger           // 红色
        case .supermarket:
            return ApocalypseTheme.success          // 绿色
        case .factory:
            return Color.gray                       // 灰色
        case .pharmacy:
            return Color.purple                     // 紫色
        case .gasStation:
            return Color.orange                     // 橙色
        case .warehouse:
            return Color.brown                      // 棕色
        case .school:
            return ApocalypseTheme.info             // 蓝色
        }
    }

    /// 获取POI状态对应的颜色
    private func colorForPOIStatus(_ status: POIStatus) -> Color {
        switch status {
        case .undiscovered:
            return ApocalypseTheme.textMuted        // 灰色（未发现）
        case .discovered:
            return ApocalypseTheme.info             // 蓝色（已发现）
        case .looted:
            return ApocalypseTheme.textSecondary    // 暗色（已搜空）
        }
    }
}

// MARK: - 预览

#Preview {
    POIListView()
}
