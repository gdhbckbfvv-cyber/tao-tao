//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果展示页面
//  显示探索统计、获得的物品等信息
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - 属性

    /// 探索结果数据
    let result: ExplorationResult

    /// 环境变量：用于关闭页面
    @Environment(\.dismiss) private var dismiss

    /// 动画状态
    @State private var showContent = false

    /// 动画显示的数字（用于统计数字跳动）
    @State private var animatedDistance: Double = 0.0
    @State private var animatedDuration: Int = 0
    @State private var animatedItemCount: Int = 0

    /// 奖励物品是否显示
    @State private var rewardItemsVisible: [Bool] = []

    /// 对勾图标缩放
    @State private var checkmarkScale: CGFloat = 0.0

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if let error = result.error {
                    // 【错误状态】
                    errorStateView(error: error)
                } else {
                    // 【成功状态】
                    successStateView
                }
            }
            .navigationTitle("探索结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .onAppear {
                // 初始化奖励物品可见性数组
                rewardItemsVisible = Array(repeating: false, count: result.itemsFound.count)

                // 延迟启动动画，增加仪式感
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showContent = true

                    // 对勾图标弹跳动画
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.4)) {
                        checkmarkScale = 1.0
                    }

                    // 统计数字跳动动画
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.5)) {
                        animatedDistance = result.distanceWalked
                        animatedDuration = result.durationInMinutes
                    }

                    // 奖励物品依次出现（每个间隔0.2秒）
                    for index in 0..<result.itemsFound.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(index) * 0.2) {
                            rewardItemsVisible[index] = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 子视图

    /// 【成功状态视图】
    private var successStateView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 【成就标题】
                achievementHeader
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showContent)

                // 【统计数据卡片】
                statisticsCard
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)

                // 【奖励物品卡片】
                rewardsCard
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: showContent)

                // 【确认按钮】
                confirmButton
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: showContent)

                Spacer(minLength: 20)
            }
            .padding()
            .padding(.top, 20)
        }
    }

    /// 【错误状态视图】
    private func errorStateView(error: ExplorationResult.ExplorationError) -> some View {
        VStack(spacing: 30) {
            Spacer()

            // 错误图标
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.danger.opacity(0.3),
                                ApocalypseTheme.danger.opacity(0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: true), value: showContent)

                // 主图标背景
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.2))
                    .frame(width: 120, height: 120)

                // 错误图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1.0 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showContent)

            // 错误标题
            VStack(spacing: 12) {
                Text("探索失败")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text(error.message)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("错误代码: \(error.code)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)

            Spacer()

            // 按钮区域
            VStack(spacing: 16) {
                // 重试按钮（如果可重试）
                if error.recoverable {
                    Button(action: {
                        print("🔄 重试探索")
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title3)
                            Text("重试探索")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }

                // 返回按钮
                Button(action: {
                    dismiss()
                }) {
                    Text(error.recoverable ? "返回" : "确认")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textSecondary, lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 30)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: showContent)

            Spacer()
        }
    }

    /// 【成就标题】
    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标（带动画缩放效果）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ApocalypseTheme.success.opacity(0.3),
                                ApocalypseTheme.success.opacity(0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: true), value: showContent)

                // 主图标背景
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 120, height: 120)

                // 地图图标
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.success)

                // 右上角对勾图标（带弹跳动画）
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.success)
                    .background(
                        Circle()
                            .fill(ApocalypseTheme.background)
                            .frame(width: 35, height: 35)
                    )
                    .offset(x: 40, y: -40)
                    .scaleEffect(checkmarkScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5), value: checkmarkScale)
            }

            // 大文字标题
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("勇敢的幸存者，你又向前迈进了一步")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    /// 【统计数据卡片】
    private var statisticsCard: some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ApocalypseTheme.info)
                Text("统计数据")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))

            Divider()
                .background(Color.white.opacity(0.1))

            VStack(spacing: 16) {
                // 行走距离
                StatisticRow(
                    icon: "figure.walk",
                    iconColor: ApocalypseTheme.primary,
                    title: "行走距离",
                    current: formatDistance(animatedDistance),
                    total: formatDistance(result.totalDistanceWalked),
                    ranking: result.distanceRanking
                )

                Divider()
                    .background(Color.white.opacity(0.05))

                // 探索时长
                HStack(spacing: 15) {
                    Image(systemName: "clock.fill")
                        .font(.title3)
                        .foregroundColor(ApocalypseTheme.warning)
                        .frame(width: 30)

                    Text("探索时长")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    Text("\(animatedDuration) 分钟")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.info.opacity(0.3), lineWidth: 1)
        )
    }

    /// 【奖励物品卡片】
    private var rewardsCard: some View {
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(ApocalypseTheme.warning)
                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))

            Divider()
                .background(Color.white.opacity(0.1))

            if result.itemsFound.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("未发现任何物品")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    // 物品列表
                    ForEach(Array(result.itemsFound.enumerated()), id: \.offset) { index, item in
                        if index < rewardItemsVisible.count {
                            ItemRewardRow(item: item)
                                .opacity(rewardItemsVisible[index] ? 1 : 0)
                                .offset(x: rewardItemsVisible[index] ? 0 : -20)
                                .scaleEffect(rewardItemsVisible[index] ? 1.0 : 0.8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rewardItemsVisible[index])
                        }
                    }

                    // 底部提示
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                        Text("已添加到背包")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }

    /// 【确认按钮】
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)

                Text("确认")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }

    // MARK: - 辅助方法

    /// 格式化距离
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
}

// MARK: - 统计行组件

struct StatisticRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let current: String
    let total: String
    let ranking: Int

    var body: some View {
        VStack(spacing: 10) {
            // 第一行：标题
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 30)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()
            }

            // 第二行：数据
            HStack(spacing: 20) {
                Spacer().frame(width: 30) // 对齐图标

                // 本次
                VStack(alignment: .leading, spacing: 4) {
                    Text("本次")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(current)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Spacer()

                // 累计
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(total)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Spacer()

                // 排名
                VStack(alignment: .trailing, spacing: 4) {
                    Text("排名")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("#\(ranking)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.success)
                }
            }
        }
    }
}

// MARK: - 物品奖励行组件

struct ItemRewardRow: View {
    let item: ExplorationResult.ItemLoot

    var body: some View {
        HStack(spacing: 15) {
            // 左侧：物品图标
            ZStack {
                Circle()
                    .fill(colorForItemName(item.itemName).opacity(0.2))
                    .frame(width: 45, height: 45)

                Image(systemName: iconForItemName(item.itemName))
                    .font(.title3)
                    .foregroundColor(colorForItemName(item.itemName))
            }

            // 中间：物品名称和数量
            VStack(alignment: .leading, spacing: 4) {
                Text(item.itemName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Text("x\(item.quantity)")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质标签（如果有）
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

            // 右侧：绿色对勾
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(ApocalypseTheme.success)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }

    /// 根据物品名称获取图标
    private func iconForItemName(_ name: String) -> String {
        switch name {
        case let n where n.contains("水"):
            return "drop.fill"
        case let n where n.contains("食") || n.contains("罐头") || n.contains("饼干"):
            return "fork.knife"
        case let n where n.contains("木材"):
            return "rectangle.3.group.fill"
        case let n where n.contains("金属"):
            return "cube.fill"
        case let n where n.contains("绷带") || n.contains("药"):
            return "cross.case.fill"
        case let n where n.contains("绳"):
            return "link"
        case let n where n.contains("电筒"):
            return "flashlight.on.fill"
        default:
            return "cube.fill"
        }
    }

    /// 根据物品名称获取颜色
    private func colorForItemName(_ name: String) -> Color {
        switch name {
        case let n where n.contains("水"):
            return ApocalypseTheme.info
        case let n where n.contains("食") || n.contains("罐头") || n.contains("饼干"):
            return Color.orange
        case let n where n.contains("木材"):
            return Color.brown
        case let n where n.contains("金属"):
            return Color.gray
        case let n where n.contains("绷带") || n.contains("药"):
            return ApocalypseTheme.danger
        case let n where n.contains("绳"):
            return Color.gray
        case let n where n.contains("电筒"):
            return ApocalypseTheme.warning
        default:
            return Color.gray
        }
    }

    /// 获取品质对应的颜色
    private func colorForQuality(_ quality: ItemQuality) -> Color {
        switch quality {
        case .poor:
            return Color.gray
        case .normal:
            return Color.white
        case .good:
            return ApocalypseTheme.success
        case .excellent:
            return ApocalypseTheme.info
        }
    }
}

// MARK: - 预览

#Preview {
    ExplorationResultView(result: MockExplorationData.mockExplorationResult)
}
