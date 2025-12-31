import Foundation
import Combine
import Supabase

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证流程
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户是否已完全认证（已登录且完成所有必需步骤）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后必须设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// OTP验证码是否已发送
    @Published var otpSent: Bool = false

    /// OTP是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// Supabase 客户端实例
    private let supabase: SupabaseClient

    /// Google 登录服务
    private let googleSignInService: GoogleSignInService

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        self.googleSignInService = GoogleSignInService(supabase: supabase)

        // 监听认证状态变化
        Task {
            await observeAuthStateChanges()
        }
    }

    // MARK: - 认证状态监听

    /// 监听 Supabase 认证状态变化
    private func observeAuthStateChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            handleAuthStateChange(event: event, session: session)
        }
    }

    /// 处理认证状态变化
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔐 认证状态变化事件: \(event)")
        print("   会话是否存在: \(session != nil)")
        if let session = session {
            print("   用户 ID: \(session.user.id)")
            print("   邮箱: \(session.user.email ?? "无")")
            print("   会话是否过期: \(session.isExpired)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        switch event {
        case .signedIn:
            // 用户登录
            print("✅ 用户登录成功")

            // 检查 session 是否过期（新行为要求）
            if let session = session, session.isExpired {
                print("⚠️ 会话已过期，触发登出")
                Task {
                    await signOut()
                }
                return
            }

            Task {
                await fetchCurrentUser()
                // 只有在不需要设置密码时才标记为已认证
                if !needsPasswordSetup {
                    isAuthenticated = true
                    print("✅ 用户已完全认证，isAuthenticated = true")
                } else {
                    print("⚠️ 需要设置密码，isAuthenticated 保持 false")
                }
            }

        case .signedOut:
            // 用户登出（包括主动登出和会话过期）
            print("⚠️ 用户已登出事件触发")
            print("   设置 isAuthenticated = false")
            print("   清理 currentUser")
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            errorMessage = nil
            print("✅ 登出状态已清理完成")

        case .userUpdated:
            // 用户信息更新
            print("🔄 用户信息已更新")
            Task {
                await fetchCurrentUser()
            }

        case .passwordRecovery:
            // 密码恢复流程
            print("🔑 进入密码恢复流程")
            needsPasswordSetup = true

        case .tokenRefreshed:
            // Token 刷新（无需特殊处理）
            print("🔄 Token 已刷新")
            break

        case .userDeleted:
            // 用户删除
            print("⚠️ 用户已删除")
            isAuthenticated = false
            currentUser = nil
            errorMessage = nil

        case .mfaChallengeVerified:
            // MFA 验证（暂不处理）
            print("🔐 MFA 验证成功")
            break

        @unknown default:
            print("⚠️ 未知的认证事件")
            break
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送 OTP 验证码（自动创建用户）
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            errorMessage = nil
        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// ⚠️ 验证成功后用户已登录，但必须设置密码才能完成注册
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP（验证成功后用户已登录）
            try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，但还需要设置密码
            otpVerified = true
            needsPasswordSetup = true

            // 注意：此时用户已登录，但 isAuthenticated 保持 false
            // 必须完成密码设置后才能进入主页

            errorMessage = nil
        } catch {
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            otpVerified = false
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let attributes = UserAttributes(password: password)
            try await supabase.auth.update(user: attributes)

            // 获取用户信息
            await fetchCurrentUser()

            // 注册完成，允许进入主页
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false

            errorMessage = nil
        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        print("🔐 开始登录流程...")
        print("📧 邮箱: \(email)")
        print("🔑 密码长度: \(password.count)")
        print("🌐 Supabase URL: \(SupabaseConfig.supabaseURL)")

        do {
            // 使用邮箱密码登录
            print("📡 正在调用 Supabase 登录 API...")
            try await supabase.auth.signIn(
                email: email,
                password: password
            )

            print("✅ Supabase 登录 API 调用成功")

            // 获取用户信息
            await fetchCurrentUser()

            // 登录成功，直接进入主页
            isAuthenticated = true
            needsPasswordSetup = false

            errorMessage = nil
            print("✅ 登录流程完成")
        } catch {
            print("❌ 登录失败详情:")
            print("   错误: \(error)")
            print("   错误描述: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
            }
            errorMessage = "登录失败: \(error.localizedDescription)"
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            errorMessage = nil
        } catch {
            errorMessage = "发送重置邮件失败: \(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// ⚠️ 注意：type 必须是 .recovery，不是 .email
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证重置验证码（使用 .recovery 类型）
            try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // ⚠️ 使用 recovery 类型
            )

            // 验证成功，需要设置新密码
            otpVerified = true
            needsPasswordSetup = true

            errorMessage = nil
        } catch {
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            otpVerified = false
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let attributes = UserAttributes(password: newPassword)
            try await supabase.auth.update(user: attributes)

            // 获取用户信息
            await fetchCurrentUser()

            // 密码重置完成
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false

            errorMessage = nil
        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录（待实现）
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 框架获取 Apple ID 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(
        //      credentials: .init(
        //          provider: .apple,
        //          idToken: appleIDToken
        //      )
        //    )
        // 3. 获取用户信息并设置 isAuthenticated = true
        errorMessage = "Apple 登录功能开发中..."
    }

    /// Google 登录
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        print("🚀 启动 Google 登录流程...")

        do {
            // 1. 执行 Google 登录并获取 Supabase 会话
            try await googleSignInService.signIn()

            print("✅ Google 登录成功，正在获取用户信息...")

            // 2. 获取用户信息
            await fetchCurrentUser()

            // 3. 登录成功，允许进入主页
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 用户信息获取成功，登录流程完成")
            errorMessage = nil

        } catch {
            print("❌ Google 登录失败: \(error.localizedDescription)")
            errorMessage = "Google 登录失败: \(error.localizedDescription)"
            isAuthenticated = false
        }

        isLoading = false
    }

    /// 处理 Google Sign-In 的 URL 回调
    /// - Parameter url: 回调 URL
    /// - Returns: 是否成功处理
    func handleGoogleSignInURL(_ url: URL) -> Bool {
        return googleSignInService.handleURL(url)
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        print("🚪 开始退出登录...")

        do {
            try await supabase.auth.signOut()
            print("✅ Supabase 退出登录成功")

            // Google 登出
            googleSignInService.signOut()

            // 清空所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            errorMessage = nil
        } catch {
            print("❌ 退出登录失败: \(error.localizedDescription)")
            errorMessage = "退出登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 检查会话状态
    /// 用于应用启动时恢复登录状态
    func checkSession() async {
        isLoading = true
        print("🔍 开始检查会话状态...")

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 会话有效，获取用户信息
            print("✅ 会话有效，用户ID: \(session.user.id)")
            await fetchCurrentUser()
            isAuthenticated = true
            needsPasswordSetup = false
        } catch {
            // 会话无效或已过期
            print("❌ 会话检查失败: \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }

    // MARK: - Private Methods

    /// 获取当前用户信息
    private func fetchCurrentUser() async {
        do {
            let session = try await supabase.auth.session

            // 从 profiles 表获取完整用户信息
            let profile: User = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value

            currentUser = profile
        } catch {
            print("获取用户信息失败: \(error.localizedDescription)")
            // 如果获取失败，使用基本信息
            if let session = try? await supabase.auth.session {
                currentUser = User(
                    id: session.user.id,
                    email: session.user.email,
                    username: nil,
                    avatarUrl: nil,
                    createdAt: session.user.createdAt
                )
            }
        }
    }

    // MARK: - 删除账户

    /// 删除当前用户账户
    /// ⚠️ 此操作不可撤销！将永久删除用户账户和所有相关数据
    func deleteAccount() async throws {
        print("")
        print("════════════════════════════════════════════")
        print("🗑️  开始删除账户流程")
        print("════════════════════════════════════════════")

        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前会话以获取 access token
            print("")
            print("📋 步骤 1: 获取当前会话...")
            let session = try await supabase.auth.session
            print("   ✅ 会话获取成功")
            print("   用户 ID: \(session.user.id)")
            print("   邮箱: \(session.user.email ?? "无")")
            print("   Access Token: \(session.accessToken.prefix(50))...")

            // 2. 调用删除账户边缘函数
            print("")
            print("📡 步骤 2: 调用删除账户边缘函数...")
            print("   函数名称: delete-account")
            print("   请求参数: {confirm: true}")
            print("   Authorization: Bearer \(session.accessToken.prefix(20))...")

            struct DeleteRequest: Encodable {
                let confirm: Bool
            }

            struct DeleteResponse: Decodable {
                let success: Bool
                let message: String
                let deleted_user_id: String
                let deleted_email: String?
            }

            // 手动传递 Authorization header
            let response: DeleteResponse = try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ],
                    body: DeleteRequest(confirm: true)
                )
            )

            print("   ✅ 边缘函数调用成功")
            print("   响应: success = \(response.success)")
            print("   消息: \(response.message)")
            print("   删除的用户 ID: \(response.deleted_user_id)")
            if let email = response.deleted_email {
                print("   删除的邮箱: \(email)")
            }

            // 3. 账户已删除，尝试清理 Supabase 会话
            print("")
            print("🧹 步骤 3: 清理 Supabase 本地会话...")
            do {
                try await supabase.auth.signOut()
                print("   ✅ Supabase 会话已清理（signOut 成功）")
            } catch {
                // 账户已删除，会话可能已失效，忽略错误
                print("   ⚠️ Supabase 会话清理失败（这是预期行为，因为账户已删除）")
                print("   错误: \(error.localizedDescription)")
            }

            // 4. 清理本地状态
            print("")
            print("🧹 步骤 4: 清理本地状态...")
            print("   设置前: isAuthenticated = \(isAuthenticated)")
            print("   设置前: currentUser = \(currentUser?.email ?? "nil")")

            isAuthenticated = false
            currentUser = nil
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            errorMessage = nil

            print("   设置后: isAuthenticated = \(isAuthenticated)")
            print("   设置后: currentUser = \(currentUser?.email ?? "nil")")

            print("")
            print("════════════════════════════════════════════")
            print("✅ 账户删除完成！")
            print("   应该触发认证状态变化事件")
            print("   应该自动返回登录页面")
            print("════════════════════════════════════════════")
            print("")

        } catch {
            print("")
            print("════════════════════════════════════════════")
            print("❌ 删除账户失败")
            print("════════════════════════════════════════════")
            print("   错误类型: \(type(of: error))")
            print("   错误描述: \(error.localizedDescription)")

            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
            }
            print("════════════════════════════════════════════")
            print("")

            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }

        isLoading = false
        print("🔚 deleteAccount() 函数执行结束")
    }

    // MARK: - Helper Methods

    /// 重置所有状态（用于流程切换）
    func resetState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }
}
