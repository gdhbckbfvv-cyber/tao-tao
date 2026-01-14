//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI 接近提示弹窗 - 玩家走到 50m 内时显示
//

import SwiftUI

struct POIProximityPopup: View {
    let poi: POI
    let onScavenge: () async throws -> Void
    let onDismiss: () -> Void

    @State private var isScavenging = false
    @State private var showError = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // POI 图标 + 名称
            HStack(spacing: 12) {
                // POI 类型图标
                Image(systemName: iconForPOIType(poi.type))
                    .font(.system(size: 40))
                    .foregroundColor(colorForPOIType(poi.type))

                VStack(alignment: .leading, spacing: 4) {
                    Text("发现兴趣点")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(poi.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()
            }

            // 危险等级
            HStack {
                Text("危险等级:")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < poi.dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(index < poi.dangerLevel ? dangerColor(level: poi.dangerLevel) : .gray.opacity(0.3))
                    }
                }

                Spacer()
            }

            // 预估物资
            if let loot = poi.estimatedLoot, !loot.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("预估物资")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    FlowLayout(spacing: 6) {
                        ForEach(loot, id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.2))
                                )
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 操作按钮
            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("稍后再说")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .foregroundColor(.gray)
                }

                Button {
                    Task {
                        isScavenging = true
                        do {
                            try await onScavenge()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                        isScavenging = false
                    }
                } label: {
                    if isScavenging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text("立即搜刮")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .background(
                    Capsule()
                        .fill(ApocalypseTheme.primary)
                )
                .foregroundColor(.white)
                .disabled(isScavenging)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 30)
        .alert("搜刮失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
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

    private func dangerColor(level: Int) -> Color {
        switch level {
        case 1:
            return .green
        case 2:
            return .yellow
        case 3:
            return .orange
        case 4:
            return .red
        case 5:
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - FlowLayout Helper

/// 流式布局（用于物品标签换行）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // 换行
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        POIProximityPopup(
            poi: POI(
                id: "test",
                name: "沃尔玛超市",
                type: .supermarket,
                coordinate: POI.Coordinate(latitude: 0, longitude: 0),
                status: .discovered,
                dangerLevel: 3,
                estimatedLoot: ["矿泉水", "罐头食品", "压缩饼干"],
                description: "测试",
                distanceFromUser: 35
            ),
            onScavenge: {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            },
            onDismiss: {}
        )
    }
}
