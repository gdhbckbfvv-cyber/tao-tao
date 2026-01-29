//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  第29天：领地详情页悬浮工具栏
//

import SwiftUI

/// 领地详情页悬浮工具栏
struct TerritoryToolbarView: View {
    let onDismiss: () -> Void
    let onBuildingBrowser: () -> Void
    @Binding var showInfoPanel: Bool

    var body: some View {
        HStack(spacing: 16) {
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(ApocalypseTheme.cardBackground)
                    .clipShape(Circle())
            }

            Spacer()

            // 建造按钮
            Button(action: onBuildingBrowser) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))
                    Text("建造")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.primary)
                .cornerRadius(20)
            }

            // 信息面板切换按钮
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showInfoPanel.toggle()
                }
            } label: {
                Image(systemName: showInfoPanel ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(ApocalypseTheme.cardBackground)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                onDismiss: {},
                onBuildingBrowser: {},
                showInfoPanel: .constant(true)
            )
            Spacer()
        }
    }
}
