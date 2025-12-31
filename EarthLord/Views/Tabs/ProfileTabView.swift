import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var showLogoutConfirm = false
    @State private var showErrorToast = false
    @State private var isLoggingOut = false

    // 删除账户相关状态
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmDialog = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false

    // 语言切换相关状态
    @State private var showLanguageSheet = false

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
                        Text(authManager.currentUser?.username ?? "幸存者".localized)
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
                            Text(String(format: "加入时间: %@".localized, formattedDate(createdAt)))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 30)

                    // 用户统计
                    HStack(spacing: 20) {
                        StatCard(title: "领地".localized, value: "0", icon: "flag.fill")
                        StatCard(title: "资源".localized, value: "0", icon: "cube.fill")
                        StatCard(title: "探索".localized, value: "0", icon: "location.fill")
                    }
                    .padding(.horizontal)

                    // 设置选项
                    VStack(spacing: 0) {
                        SettingRow(
                            icon: "person.circle",
                            title: "编辑资料".localized,
                            action: {
                                // TODO: 实现编辑资料功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        SettingRow(
                            icon: "bell.fill",
                            title: "通知设置".localized,
                            action: {
                                // TODO: 实现通知设置功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        SettingRow(
                            icon: "lock.fill",
                            title: "隐私与安全".localized,
                            action: {
                                // TODO: 实现隐私设置功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        SettingRow(
                            icon: "questionmark.circle",
                            title: "帮助与反馈".localized,
                            action: {
                                // TODO: 实现帮助功能
                            }
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 50)

                        // 语言切换
                        Button(action: {
                            showLanguageSheet = true
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 30)

                                Text("语言设置".localized)
                                    .foregroundColor(.white)

                                Spacer()

                                Text(languageManager.currentLanguage.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
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
                            Text(isLoggingOut ? "退出中...".localized : "退出登录".localized)
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

                    // 删除账户按钮
                    Button(action: {
                        showDeleteAccountAlert = true
                    }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.8, green: 0.2, blue: 0.2)))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text(isDeleting ? "删除中...".localized : "删除账户".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.8, green: 0.2, blue: 0.2).opacity(0.15))
                        .foregroundColor(Color(red: 0.8, green: 0.2, blue: 0.2))
                        .cornerRadius(12)
                    }
                    .disabled(isDeleting || isLoggingOut)
                    .opacity((isDeleting || isLoggingOut) ? 0.6 : 1.0)
                    .padding(.horizontal)
                    .padding(.top, 10)

                    // 版本信息
                    Text("地球新主 v1.0.0".localized)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("个人中心".localized)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "确定要退出登录吗？".localized,
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("退出登录".localized, role: .destructive) {
                    Task {
                        await performLogout()
                    }
                }
                Button("取消".localized, role: .cancel) {}
            }
            .alert("⚠️ 警告".localized, isPresented: $showDeleteAccountAlert) {
                Button("取消".localized, role: .cancel) {
                    print("📋 用户取消了删除账户操作")
                }
                Button("继续".localized, role: .destructive) {
                    print("📋 用户确认要继续删除账户")
                    showDeleteConfirmDialog = true
                }
            } message: {
                Text("删除账户后，您的所有数据将被永久删除且无法恢复！\n\n这包括：\n• 个人资料\n• 游戏进度\n• 所有记录\n\n您确定要继续吗？".localized)
            }
            .sheet(isPresented: $showDeleteConfirmDialog) {
                DeleteAccountConfirmView(
                    isPresented: $showDeleteConfirmDialog,
                    deleteConfirmText: $deleteConfirmText,
                    onConfirm: {
                        Task {
                            await performDeleteAccount()
                        }
                    }
                )
            }
            .sheet(isPresented: $showLanguageSheet) {
                LanguageSelectionView(isPresented: $showLanguageSheet)
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

    /// 执行删除账户操作
    private func performDeleteAccount() async {
        print("")
        print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
        print("┃ ProfileTabView: 用户确认删除账户       ┃")
        print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
        print("   isDeleting = true")
        isDeleting = true

        do {
            print("   调用 authManager.deleteAccount()...")
            try await authManager.deleteAccount()
            print("")
            print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
            print("┃ ProfileTabView: deleteAccount() 成功  ┃")
            print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            print("   关闭确认对话框...")

            // 关闭确认对话框
            showDeleteConfirmDialog = false
            deleteConfirmText = ""

            // 确保 UI 更新（延迟一点以确保状态完全清理）
            print("   等待 0.1 秒后检查 UI 状态...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("")
                print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
                print("┃ ProfileTabView: UI 状态检查           ┃")
                print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
                print("   authManager.isAuthenticated = \(self.authManager.isAuthenticated)")
                print("   authManager.currentUser = \(self.authManager.currentUser?.email ?? "nil")")
                print("   如果 isAuthenticated = false，应该显示登录页面")
                print("")
            }
        } catch {
            print("")
            print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
            print("┃ ProfileTabView: deleteAccount() 失败  ┃")
            print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            print("   错误: \(error.localizedDescription)")

            // 显示错误提示
            showErrorToast = true
            showDeleteConfirmDialog = false
            deleteConfirmText = ""

            // 3秒后自动隐藏错误提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showErrorToast = false
                authManager.errorMessage = nil
            }
        }

        print("   isDeleting = false")
        isDeleting = false
        print("")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = languageManager.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - 删除账户确认视图

struct DeleteAccountConfirmView: View {
    @Binding var isPresented: Bool
    @Binding var deleteConfirmText: String
    let onConfirm: () -> Void

    // 获取当前语言的确认文本
    private var expectedConfirmText: String {
        "删除".localized
    }

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    // 警告文本
                    VStack(spacing: 15) {
                        Text("最后确认".localized)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("此操作将永久删除您的账户\n所有数据将无法恢复".localized)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    // 说明文本
                    VStack(alignment: .leading, spacing: 10) {
                        Text("请在下方输入 \"删除\" 以确认：".localized)
                            .font(.subheadline)
                            .foregroundColor(.white)

                        TextField("", text: $deleteConfirmText)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 30)

                    // 确认按钮
                    Button(action: {
                        print("📋 用户输入了确认文本: '\(deleteConfirmText)'")
                        if deleteConfirmText == expectedConfirmText {
                            print("✅ 确认文本匹配，执行删除")
                            onConfirm()
                        } else {
                            print("❌ 确认文本不匹配 (期望: '\(expectedConfirmText)')")
                        }
                    }) {
                        Text("确认删除账户".localized)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(deleteConfirmText == expectedConfirmText ? Color.red : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(deleteConfirmText != expectedConfirmText)
                    .padding(.horizontal, 30)

                    Spacer()
                }
            }
            .navigationTitle("删除账户".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消".localized) {
                        print("📋 用户取消了删除账户确认")
                        deleteConfirmText = ""
                        isPresented = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
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

// 语言选择视图
struct LanguageSelectionView: View {
    @Binding var isPresented: Bool
    @ObservedObject var languageManager = LanguageManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(LanguageManager.Language.allCases) { language in
                            Button(action: {
                                print("🌍 用户选择语言: \(language.displayName)")
                                languageManager.switchLanguage(to: language)

                                // 延迟关闭，让用户看到选择效果
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isPresented = false
                                }
                            }) {
                                HStack(spacing: 15) {
                                    // 语言图标
                                    Image(systemName: language.icon)
                                        .font(.title2)
                                        .foregroundColor(ApocalypseTheme.primary)
                                        .frame(width: 30)

                                    // 语言名称
                                    Text(language.displayName)
                                        .font(.body)
                                        .foregroundColor(.white)

                                    Spacer()

                                    // 选中标记
                                    if languageManager.currentLanguage == language {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(ApocalypseTheme.primary)
                                            .font(.title3)
                                    }
                                }
                                .padding()
                                .background(
                                    languageManager.currentLanguage == language
                                        ? ApocalypseTheme.primary.opacity(0.1)
                                        : Color.clear
                                )
                            }

                            if language != LanguageManager.Language.allCases.last {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("语言设置".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成".localized) {
                        isPresented = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager(supabase: SupabaseConfig.shared))
}
