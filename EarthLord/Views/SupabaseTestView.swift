import SwiftUI
import Supabase

// 初始化 Supabase 客户端
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://vlfvceeqwnahwcnbahth.supabase.co")!,
    supabaseKey: "sb_publishable_zIKWJgysMWGtqXRVGEMpsQ_Ln7COtmo"
)

struct SupabaseTestView: View {
    @State private var isConnected: Bool? = nil
    @State private var debugLog: String = "点击按钮开始测试连接..."
    @State private var isTesting: Bool = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .padding(.top, 40)

                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 120, height: 120)
                        .shadow(color: statusBackgroundColor.opacity(0.5), radius: 20)

                    Image(systemName: statusIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)

                // 调试日志
                VStack(alignment: .leading, spacing: 12) {
                    Text("调试日志")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ScrollView {
                        Text(debugLog)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 200)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)

                Spacer()

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isTesting)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - 状态计算属性

    private var statusIcon: String {
        guard let isConnected = isConnected else {
            return "questionmark.circle.fill"
        }
        return isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusBackgroundColor: Color {
        guard let isConnected = isConnected else {
            return ApocalypseTheme.textMuted
        }
        return isConnected ? ApocalypseTheme.success : ApocalypseTheme.danger
    }

    // MARK: - 测试连接

    private func testConnection() {
        isTesting = true
        isConnected = nil
        debugLog = "正在连接到 Supabase...\n"

        Task {
            do {
                // 尝试查询一个不存在的表
                debugLog += "发送请求: SELECT * FROM non_existent_table\n"

                let _ = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()

                // 如果没有抛出错误（不太可能），说明表存在
                await MainActor.run {
                    debugLog += "\n✅ 意外成功：表存在或连接成功\n"
                    isConnected = true
                    isTesting = false
                }

            } catch {
                await MainActor.run {
                    debugLog += "\n收到错误响应:\n"
                    debugLog += "错误类型: \(type(of: error))\n"
                    debugLog += "错误描述: \(error.localizedDescription)\n\n"

                    let errorString = error.localizedDescription

                    // 判断连接状态
                    if errorString.contains("PGRST") ||
                       errorString.contains("Could not find the table") ||
                       errorString.contains("relation") && errorString.contains("does not exist") {
                        debugLog += "✅ 连接成功（服务器已响应）\n"
                        debugLog += "说明: Supabase 服务器正常响应，表不存在是预期的\n"
                        isConnected = true
                    } else if errorString.contains("hostname") ||
                              errorString.contains("URL") ||
                              errorString.contains("NSURLErrorDomain") {
                        debugLog += "❌ 连接失败：URL 错误或无网络\n"
                        debugLog += "请检查: 网络连接、Supabase URL 配置\n"
                        isConnected = false
                    } else {
                        debugLog += "❌ 其他错误:\n\(errorString)\n"
                        isConnected = false
                    }

                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    SupabaseTestView()
}
