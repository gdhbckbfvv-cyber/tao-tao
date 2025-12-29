import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutConfirm = false
    @State private var showErrorToast = false
    @State private var isLoggingOut = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 头像和基本信息
                    VStack(spacing: 12) {
                        // 头像
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            ApocalypseTheme.primary.opacity(0.3),
                                            ApocalypseTheme.primary.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)

                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(ApocalypseTheme.primary)
                        }

                        // 用户名
                        Text(authManager.currentUser?.username ?? "幸存者")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        // 邮箱
                        if let email = authManager.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        // 注册时间
                        if let createdAt = authManager.currentUser?.createdAt {
                            Text("加入时间: \(formattedDate(createdAt))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 30)

                    // 用户统计
                    HStack(spacing: 20) {
                        StatCard(title: "领地", value: "0", icon: "flag.fill")
                        StatCard(title: "资源", value: "0", icon: "cube.fill")
                        StatCard(title: "探索", value: "0", icon: "location.fill")
                    }
                    .padding(.horizontal)

                    // 设置选项
                    VStack(spacing: 0) {
                        SettingRow(
                            icon: "person.circle",
                            title: "编辑资料",
                            action: {
                                // TODO: 实现编辑资料功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        SettingRow(
                            icon: "bell.fill",
                            title: "通知设置",
                            action: {
                                // TODO: 实现通知设置功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        SettingRow(
                            icon: "lock.fill",
                            title: "隐私与安全",
                            action: {
                                // TODO: 实现隐私设置功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        SettingRow(
                            icon: "questionmark.circle",
                            title: "帮助与反馈",
                            action: {
                                // TODO: 实现帮助功能
                            }
                        )
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // 退出登录按钮
                    Button(action: {
                        showLogoutConfirm = true
                    }) {
                        HStack {
                            if isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                            Text(isLoggingOut ? "退出中..." : "退出登录")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                    .disabled(isLoggingOut)
                    .opacity(isLoggingOut ? 0.6 : 1.0)
                    .padding(.horizontal)
                    .padding(.top, 30)

                    // 版本信息
                    Text("地球新主 v1.0.0")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "确定要退出登录吗？",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("退出登录", role: .destructive) {
                    Task {
                        await performLogout()
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .overlay(
                // 错误提示 Toast
                Group {
                    if showErrorToast, let errorMessage = authManager.errorMessage {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .animation(.spring(), value: showErrorToast)
                    }
                }
            )
        }
    }

    /// 执行登出操作
    private func performLogout() async {
        isLoggingOut = true

        await authManager.signOut()

        isLoggingOut = false

        // 如果登出失败，显示错误提示
        if authManager.errorMessage != nil {
            showErrorToast = true

            // 3秒后自动隐藏错误提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showErrorToast = false
                authManager.errorMessage = nil
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// 设置行
struct SettingRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 30)

                Text(title)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager(supabase: SupabaseConfig.shared))
}
