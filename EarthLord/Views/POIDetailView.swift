//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//  显示POI的详细信息、物资状态、危险等级等
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - 属性

    /// 传入的POI数据
    let poi: POI

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult = false

    /// 环境变量：用于返回上一页
    @Environment(\.dismiss) private var dismiss

    /// 内容是否已加载（用于淡入动画）
    @State private var contentLoaded = false

    // MARK: - 计算属性

    /// 是否已被搜空（不可搜寻）
    private var isLooted: Bool {
        return poi.status == .looted || poi.estimatedLoot == nil || poi.estimatedLoot?.isEmpty == true
    }

    /// 危险等级文本
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1:
            return ApocalypseTheme.success       // 绿色
        case 2:
            return ApocalypseTheme.info          // 蓝色
        case 3:
            return ApocalypseTheme.warning       // 黄色
        case 4:
            return Color.orange                  // 橙色
        case 5:
            return ApocalypseTheme.danger        // 红色
        default:
            return Color.gray
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 【顶部大图区域】
                    headerSection

                    // 【信息区域】
                    infoSection
                        .padding(.top, -30) // 向上偏移，营造卡片叠加效果
                        .opacity(contentLoaded ? 1.0 : 0.0)
                        .offset(y: contentLoaded ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: contentLoaded)

                    // 【操作按钮区域】
                    actionButtonsSection
                        .padding(.top, 20)
                        .opacity(contentLoaded ? 1.0 : 0.0)
                        .offset(y: contentLoaded ? 0 : 30)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: contentLoaded)

                    Spacer(minLength: 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            // 使用假的探索结果数据
            ExplorationResultView(result: MockExplorationData.mockExplorationResult)
        }
        .onAppear {
            // 延迟加载动画，让页面先渲染
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                contentLoaded = true
            }
        }
    }

    // MARK: - 子视图

    /// 【顶部大图区域】
    private var headerSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    colors: gradientColorsForPOIType(poi.type),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: geometry.size.height)

                // 大图标
                Image(systemName: iconForPOIType(poi.type))
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 60)

                // 底部半透明黑色遮罩
                VStack(spacing: 8) {
                    Text(poi.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(poi.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: UIScreen.main.bounds.height / 3) // 占屏幕1/3
    }

    /// 【信息区域】
    private var infoSection: some View {
        VStack(spacing: 16) {
            // 距离信息
            InfoRow(
                icon: "location.fill",
                iconColor: ApocalypseTheme.primary,
                label: "距离",
                value: formatDistance(poi.distanceFromUser ?? 350),
                valueColor: ApocalypseTheme.textPrimary
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // 物资状态
            InfoRow(
                icon: "shippingbox.fill",
                iconColor: isLooted ? ApocalypseTheme.textMuted : ApocalypseTheme.success,
                label: "物资状态",
                value: isLooted ? "已清空" : "有物资",
                valueColor: isLooted ? ApocalypseTheme.textMuted : ApocalypseTheme.success
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // 危险等级
            InfoRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: dangerLevelColor,
                label: "危险等级",
                value: dangerLevelText,
                valueColor: dangerLevelColor
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // 来源
            InfoRow(
                icon: "map.fill",
                iconColor: ApocalypseTheme.info,
                label: "来源",
                value: "地图数据",
                valueColor: ApocalypseTheme.textSecondary
            )

            // 如果有物资列表，显示预估物资
            if let loot = poi.estimatedLoot, !loot.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(ApocalypseTheme.warning)
                        Text("预估物资")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    POIDetailFlowLayout(spacing: 8) {
                        ForEach(loot, id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(ApocalypseTheme.warning.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 描述信息
            if !poi.description.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text("描述")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Text(poi.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    /// 【操作按钮区域】
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // 主按钮："搜寻此POI"
            Button(action: {
                if !isLooted {
                    print("🔍 开始搜寻POI: \(poi.name)")
                    showExplorationResult = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: isLooted ? "exclamationmark.triangle.fill" : "magnifyingglass.circle.fill")
                        .font(.title3)

                    Text(isLooted ? "已被搜空" : "搜寻此POI")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isLooted
                            ? [Color.gray, Color.gray.opacity(0.8)]
                            : [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(isLooted)
            .opacity(isLooted ? 0.6 : 1.0)

            // 两个小按钮并排
            HStack(spacing: 12) {
                // "标记已发现" 按钮
                Button(action: {
                    print("📍 标记POI为已发现: \(poi.name)")
                    // TODO: 实现标记逻辑
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.subheadline)

                        Text("标记已发现")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(ApocalypseTheme.info)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.info, lineWidth: 1.5)
                    )
                }

                // "标记无物资" 按钮
                Button(action: {
                    print("🚫 标记POI无物资: \(poi.name)")
                    // TODO: 实现标记逻辑
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.subheadline)

                        Text("标记无物资")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ApocalypseTheme.textSecondary, lineWidth: 1.5)
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 辅助方法

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

    /// 获取POI类型对应的渐变色
    private func gradientColorsForPOIType(_ type: POIType) -> [Color] {
        switch type {
        case .hospital:
            return [ApocalypseTheme.danger, ApocalypseTheme.danger.opacity(0.7)]
        case .supermarket:
            return [ApocalypseTheme.success, ApocalypseTheme.success.opacity(0.7)]
        case .factory:
            return [Color.gray, Color.gray.opacity(0.7)]
        case .pharmacy:
            return [Color.purple, Color.purple.opacity(0.7)]
        case .gasStation:
            return [Color.orange, Color.orange.opacity(0.7)]
        case .warehouse:
            return [Color.brown, Color.brown.opacity(0.7)]
        case .school:
            return [ApocalypseTheme.info, ApocalypseTheme.info.opacity(0.7)]
        }
    }

    /// 格式化距离
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f 公里", distance / 1000)
        } else {
            return String(format: "%.0f 米", distance)
        }
    }
}

// MARK: - 信息行组件

private struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 15) {
            // 图标
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)

            // 标签
            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - 流式布局（用于物资标签）

struct POIDetailFlowLayout: Layout {
    var spacing: CGFloat = 8

    struct Row {
        var indices: [Int]
        var height: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow: [Int] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        let maxWidth = proposal.width ?? .infinity

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append(Row(indices: currentRow, height: currentRowHeight))
                currentRow = []
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRow.append(index)
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if !currentRow.isEmpty {
            rows.append(Row(indices: currentRow, height: currentRowHeight))
        }

        return rows
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}
