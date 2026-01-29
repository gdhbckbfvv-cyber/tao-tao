//
//  ScavengeResultView.swift
//  EarthLord
//
//  POI 搜刮结果页面 - 显示搜刮获得的物品（支持 AI 生成物品展示）
//

import SwiftUI

struct ScavengeResultView: View {
    let poi: POI
    let items: [ExplorationResult.ItemLoot]

    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var expandedItemIndex: Int? = nil  // 当前展开的物品索引

    /// 是否有 AI 生成的物品
    private var hasAIItems: Bool {
        items.contains { $0.isAIGenerated }
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // 成功图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.success.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.success)
                    }
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showContent)

                    // 标题
                    VStack(spacing: 8) {
                        Text("搜刮成功！")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Image(systemName: iconForPOIType(poi.type))
                                .foregroundColor(colorForPOIType(poi.type))

                            Text(poi.name)
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)

                    // 获得物品列表
                    VStack(spacing: 0) {
                        // 标题栏
                        HStack {
                            Image(systemName: "gift.fill")
                                .foregroundColor(ApocalypseTheme.primary)
                            Text("获得物品")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()

                            // AI 生成标识
                            if hasAIItems {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                    Text("AI 生成")
                                        .font(.caption)
                                }
                                .foregroundColor(ApocalypseTheme.info)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ApocalypseTheme.info.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))

                        // 物品列表
                        if items.isEmpty {
                            Text("没有找到任何物品")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 30)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.itemId) { index, item in
                                    AIItemRewardRow(
                                        item: item,
                                        isExpanded: expandedItemIndex == index
                                    )
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .opacity(showContent ? 1 : 0)
                                    .offset(x: showContent ? 0 : -20)
                                    .animation(
                                        .easeOut(duration: 0.3).delay(0.4 + Double(index) * 0.1),
                                        value: showContent
                                    )
                                    .onTapGesture {
                                        // 只有有故事的物品才能展开
                                        if item.story != nil {
                                            withAnimation(.spring(response: 0.3)) {
                                                if expandedItemIndex == index {
                                                    expandedItemIndex = nil
                                                } else {
                                                    expandedItemIndex = index
                                                }
                                            }
                                        }
                                    }

                                    if index < items.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ApocalypseTheme.cardBackground)
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.6), value: showContent)

                    // 确认按钮
                    Button {
                        dismiss()
                    } label: {
                        Text("确认")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                Capsule()
                                    .fill(ApocalypseTheme.primary)
                            )
                            .foregroundColor(.white)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.8), value: showContent)
                }
                .padding()
            }
        }
        .onAppear {
            showContent = true
        }
    }

    // MARK: - Helper Methods

    private func iconForPOIType(_ type: POIType) -> String {
        switch type {
        case .supermarket:
            return "cart.fill"
        case .hospital:
            return "cross.case.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .factory:
            return "gearshape.2.fill"
        case .warehouse:
            return "shippingbox.fill"
        case .school:
            return "book.fill"
        }
    }

    private func colorForPOIType(_ type: POIType) -> Color {
        switch type {
        case .supermarket:
            return .green
        case .hospital:
            return .red
        case .pharmacy:
            return .blue
        case .gasStation:
            return .orange
        case .factory:
            return .gray
        case .warehouse:
            return .brown
        case .school:
            return .purple
        }
    }
}

// MARK: - AI 物品奖励行组件

/// 支持展示 AI 生成物品的奖励行组件
struct AIItemRewardRow: View {
    let item: ExplorationResult.ItemLoot
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 主行
            HStack(spacing: 15) {
                // 左侧：物品图标
                ZStack {
                    Circle()
                        .fill(colorForRarity(item.rarity ?? .common).opacity(0.2))
                        .frame(width: 45, height: 45)

                    Image(systemName: iconForItemName(item.itemName))
                        .font(.title3)
                        .foregroundColor(colorForRarity(item.rarity ?? .common))

                    // AI 生成标识
                    if item.isAIGenerated {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.info)
                            .offset(x: 15, y: -15)
                    }
                }

                // 中间：物品名称和信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.itemName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("x\(item.quantity)")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        // 稀有度标签
                        if let rarity = item.rarity {
                            Text(rarity.rawValue)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colorForRarity(rarity))
                                .cornerRadius(4)
                        }

                        // 品质标签
                        if let quality = item.quality {
                            Text(quality.rawValue)
                                .font(.caption2)
                                .foregroundColor(colorForQuality(quality))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colorForQuality(quality).opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                // 展开指示器（如果有故事）
                if item.story != nil {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    // 右侧：绿色对勾
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.success)
                }
            }

            // 故事展开区域
            if isExpanded, let story = item.story {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                        Text("物品故事")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(ApocalypseTheme.info)

                    Text(story)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
                .padding(.leading, 60)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Helper Methods

    /// 根据物品名称获取图标
    private func iconForItemName(_ name: String) -> String {
        switch name {
        case let n where n.contains("水") || n.contains("饮"):
            return "drop.fill"
        case let n where n.contains("食") || n.contains("罐头") || n.contains("饼干") || n.contains("面包"):
            return "fork.knife"
        case let n where n.contains("木材") || n.contains("木"):
            return "rectangle.3.group.fill"
        case let n where n.contains("金属") || n.contains("铁") || n.contains("钢"):
            return "cube.fill"
        case let n where n.contains("绷带") || n.contains("药") || n.contains("急救") || n.contains("医"):
            return "cross.case.fill"
        case let n where n.contains("绳"):
            return "link"
        case let n where n.contains("电筒") || n.contains("灯"):
            return "flashlight.on.fill"
        case let n where n.contains("刀") || n.contains("武器") || n.contains("棍"):
            return "shield.fill"
        case let n where n.contains("工具") || n.contains("扳手"):
            return "wrench.fill"
        default:
            return "cube.fill"
        }
    }

    /// 根据稀有度获取颜色
    private func colorForRarity(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common:
            return Color.gray
        case .uncommon:
            return ApocalypseTheme.success
        case .rare:
            return ApocalypseTheme.info
        case .epic:
            return Color.purple
        case .legendary:
            return ApocalypseTheme.primary
        }
    }

    /// 根据品质获取颜色
    private func colorForQuality(_ quality: ItemQuality) -> Color {
        switch quality {
        case .poor:
            return .gray
        case .normal:
            return .white
        case .good:
            return .green
        case .excellent:
            return .blue
        }
    }
}

#Preview {
    ScavengeResultView(
        poi: POI(
            id: "test",
            name: "协和医院急诊室",
            type: .hospital,
            coordinate: POI.Coordinate(latitude: 0, longitude: 0),
            status: .looted,
            dangerLevel: 4,
            estimatedLoot: nil,
            description: "测试",
            distanceFromUser: 0
        ),
        items: [
            ExplorationResult.ItemLoot(
                itemId: "ai_12345678",
                itemName: "「最后的希望」应急包",
                quantity: 1,
                quality: .excellent,
                story: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它...",
                rarity: .epic,
                isAIGenerated: true,
                category: .medical
            ),
            ExplorationResult.ItemLoot(
                itemId: "ai_87654321",
                itemName: "护士站的咖啡罐头",
                quantity: 1,
                quality: .good,
                story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。",
                rarity: .rare,
                isAIGenerated: true,
                category: .food
            ),
            ExplorationResult.ItemLoot(
                itemId: "item_water_001",
                itemName: "矿泉水",
                quantity: 2,
                quality: .normal
            )
        ]
    )
}
