//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地、交易等功能分段
//

import SwiftUI

struct ResourcesTabView: View {

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment = 0

    /// 交易功能开关（假数据）
    @State private var isTradingEnabled = false

    // MARK: - 分段枚举

    enum ResourceSegment: Int, CaseIterable {
        case poi = 0
        case backpack = 1
        case purchased = 2
        case territory = 3
        case trading = 4

        var title: String {
            switch self {
            case .poi: return "POI"
            case .backpack: return "背包"
            case .purchased: return "已购"
            case .territory: return "领地"
            case .trading: return "交易"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 【顶部导航栏】
                    navigationBar

                    // 【分段选择器】
                    segmentedPicker
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.background)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // 【内容区域】
                    contentView
                }
            }
            .navigationBarHidden(true) // 隐藏默认导航栏，使用自定义的
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 使用栈式导航
    }

    // MARK: - 子视图

    /// 【顶部导航栏】
    private var navigationBar: some View {
        HStack {
            // 标题
            Text("资源")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            // 交易开关
            tradingToggle
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(ApocalypseTheme.background)
    }

    /// 【分段选择器】
    private var segmentedPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.rawValue) { segment in
                Text(segment.title)
                    .tag(segment.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 【交易开关】
    private var tradingToggle: some View {
        HStack(spacing: 8) {
            Text("交易")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradingEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(0.8)
        }
    }

    /// 【内容区域】
    @ViewBuilder
    private var contentView: some View {
        switch ResourceSegment(rawValue: selectedSegment) {
        case .poi:
            // POI列表页面
            POIListContent()

        case .backpack:
            // 背包页面
            BackpackContent()

        case .purchased:
            // 已购页面（占位）
            placeholderView(title: "已购", icon: "bag.fill")

        case .territory:
            // 领地页面（占位）
            placeholderView(title: "领地", icon: "flag.fill")

        case .trading:
            // 交易页面（占位）
            placeholderView(title: "交易", icon: "arrow.left.arrow.right")

        case .none:
            EmptyView()
        }
    }

    /// 占位视图
    private func placeholderView(title: String, icon: String) -> some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("\(title)功能")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("功能开发中")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("敬请期待")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
