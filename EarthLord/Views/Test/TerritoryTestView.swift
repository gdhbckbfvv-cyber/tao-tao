//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地测试页面（三楼）
//  作用：在真机上显示圈地日志，方便现场调试
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - 状态管理

    /// 日志管理器
    @StateObject private var logger = TerritoryLogger.shared

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部状态栏
                statusBar

                Divider()

                // 日志显示区域
                logDisplayArea

                Divider()

                // 底部操作按钮
                bottomControls
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("圈地测试")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 子视图

    /// 顶部状态栏
    private var statusBar: some View {
        HStack(spacing: 16) {
            // 追踪状态指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(locationManager.isTracking ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(locationManager.isTracking ? "追踪中" : "未追踪")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 20)
                .background(Color.gray)

            // 路径点数
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("\(locationManager.pathCoordinates.count) 点")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 20)
                .background(Color.gray)

            // 闭环状态
            HStack(spacing: 4) {
                Image(systemName: locationManager.isPathClosed ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(locationManager.isPathClosed ? .green : .gray)

                Text(locationManager.isPathClosed ? "已闭环" : "未闭环")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }

            Spacer()

            // 日志总数
            Text("\(logger.logCount) 条")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }

    /// 日志显示区域
    private var logDisplayArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // 如果没有日志，显示提示
                    if logger.logs.isEmpty {
                        Text("暂无日志，点击【开始圈地】开始测试")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        // 显示所有日志
                        ForEach(logger.logs) { log in
                            logEntryView(log)
                        }

                        // 底部锚点（用于自动滚动）
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.3))
            .onChange(of: logger.logCount) { _ in
                // 新日志时自动滚动到底部
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 单条日志视图
    private func logEntryView(_ log: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(log.timeString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 65, alignment: .leading)

            // 类型标识
            Text(log.type.emoji)
                .font(.caption)

            // 消息内容
            Text(log.message)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(log.type.color)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// 底部操作按钮
    private var bottomControls: some View {
        HStack(spacing: 12) {
            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }

            // 开始/停止圈地按钮
            Button(action: {
                if locationManager.isTracking {
                    locationManager.stopPathTracking()
                } else {
                    locationManager.startPathTracking()
                }
            }) {
                HStack {
                    Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(locationManager.isTracking ? Color.orange : ApocalypseTheme.success)
                .cornerRadius(8)
            }

            // 导出日志按钮
            Button(action: {
                exportLogs()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 方法

    /// 导出日志
    private func exportLogs() {
        let text = logger.exportText()

        // 创建分享界面
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        // 获取当前窗口并显示分享界面
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryTestView()
}
