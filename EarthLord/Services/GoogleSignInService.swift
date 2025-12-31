import Foundation
import GoogleSignIn
import Supabase

/// Google 登录服务
/// 负责处理 Google Sign-In 的认证流程
class GoogleSignInService {

    // MARK: - Properties

    /// Google Client ID
    private let clientID = "144838324436-asoq076tmk27okgn04u5fv1k28poa6f6.apps.googleusercontent.com"

    /// Supabase 客户端
    private let supabase: SupabaseClient

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        configureGoogleSignIn()
    }

    // MARK: - Configuration

    /// 配置 Google Sign-In
    private func configureGoogleSignIn() {
        print("📱 开始配置 Google Sign-In...")

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ Google Sign-In 配置成功")
    }

    // MARK: - Sign In

    /// 执行 Google 登录
    /// - Returns: 成功返回 true，失败返回 false
    @MainActor
    func signIn() async throws {
        print("🔐 开始 Google 登录流程...")

        // 1. 获取顶层视图控制器
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ 无法获取根视图控制器")
            throw GoogleSignInError.noRootViewController
        }

        print("📱 正在启动 Google 登录界面...")

        // 2. 执行 Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        )

        print("✅ Google 登录界面完成")

        // 3. 获取 ID Token
        guard let idToken = result.user.idToken?.tokenString else {
            print("❌ 无法获取 Google ID Token")
            throw GoogleSignInError.noIDToken
        }

        print("🔑 成功获取 Google ID Token")
        print("📧 Google 用户邮箱: \(result.user.profile?.email ?? "未知")")
        print("👤 Google 用户名: \(result.user.profile?.name ?? "未知")")

        // 4. 使用 ID Token 登录 Supabase
        print("🔐 正在使用 Google Token 登录 Supabase...")

        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )

        print("✅ Supabase Google 登录成功")
    }

    // MARK: - Handle URL

    /// 处理 Google Sign-In 的 URL 回调
    /// - Parameter url: 回调 URL
    /// - Returns: 是否成功处理
    func handleURL(_ url: URL) -> Bool {
        print("🔗 收到 URL 回调: \(url.absoluteString)")

        let handled = GIDSignIn.sharedInstance.handle(url)

        if handled {
            print("✅ Google Sign-In 成功处理 URL 回调")
        } else {
            print("⚠️ URL 回调未被 Google Sign-In 处理")
        }

        return handled
    }

    // MARK: - Sign Out

    /// Google 登出
    func signOut() {
        print("🚪 执行 Google 登出...")
        GIDSignIn.sharedInstance.signOut()
        print("✅ Google 登出完成")
    }
}

// MARK: - Error Types

enum GoogleSignInError: LocalizedError {
    case noRootViewController
    case noIDToken
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "无法获取根视图控制器"
        case .noIDToken:
            return "无法获取 Google ID Token"
        case .authenticationFailed:
            return "Google 认证失败"
        }
    }
}
