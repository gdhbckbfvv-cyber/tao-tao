//
//  ScavengeResultView.swift
//  EarthLord
//
//  POI 搜刮结果页面 - 显示搜刮获得的物品
//

import SwiftUI

struct ScavengeResultView: View {
    let poi: POI
    let items: [ExplorationResult.ItemLoot]

    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

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
                                ItemRewardRow(item: item)
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .opacity(showContent ? 1 : 0)
                                    .offset(x: showContent ? 0 : -20)
                                    .animation(
                                        .easeOut(duration: 0.3).delay(0.4 + Double(index) * 0.1),
                                        value: showContent
                                    )

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

#Preview {
    ScavengeResultView(
        poi: POI(
            id: "test",
            name: "沃尔玛超市",
            type: .supermarket,
            coordinate: POI.Coordinate(latitude: 0, longitude: 0),
            status: .looted,
            dangerLevel: 3,
            estimatedLoot: nil,
            description: "测试",
            distanceFromUser: 0
        ),
        items: [
            ExplorationResult.ItemLoot(
                itemId: "item_water_001",
                itemName: "矿泉水",
                quantity: 2,
                quality: .normal
            ),
            ExplorationResult.ItemLoot(
                itemId: "item_food_001",
                itemName: "罐头食品",
                quantity: 1,
                quality: .good
            )
        ]
    )
}
