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

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase

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
        print("🔐 认证状态变化: \(event)")

        switch event {
        case .signedIn:
            // 用户登录
            print("✅ 用户登录成功")
            Task {
                await fetchCurrentUser()
                // 只有在不需要设置密码时才标记为已认证
                if !needsPasswordSetup {
                    isAuthenticated = true
                    print("✅ 用户已完全认证")
                }
            }

        case .signedOut:
            // 用户登出（包括主动登出和会话过期）
            print("⚠️ 用户已登出")
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            errorMessage = nil

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

        do {
            // 使用邮箱密码登录
            try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 获取用户信息
            await fetchCurrentUser()

            // 登录成功，直接进入主页
            isAuthenticated = true
            needsPasswordSetup = false

            errorMessage = nil
        } catch {
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

    /// Google 登录（待实现）
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        // 1. 使用 GoogleSignIn SDK 获取 Google 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(
        //      credentials: .init(
        //          provider: .google,
        //          idToken: googleIdToken
        //      )
        //    )
        // 3. 获取用户信息并设置 isAuthenticated = true
        errorMessage = "Google 登录功能开发中..."
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        print("🚪 开始退出登录...")

        do {
            try await supabase.auth.signOut()
            print("✅ 退出登录成功")

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

    // MARK: - Helper Methods

    /// 重置所有状态（用于流程切换）
    func resetState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }
}
