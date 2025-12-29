import SwiftUI

/// 启动画面
/// 显示 Logo 和加载动画，同时检查用户会话状态
struct SplashView: View {
    @EnvironmentObject var authManager: AuthManager

    /// 加载状态文字
    @State private var loadingText = "正在初始化..."

    /// Logo 动画状态
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var isAnimating = false

    /// 是否完成检查
    @State private var checkCompleted = false

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo 区域
                ZStack {
                    // 外圈光晕（呼吸动画）
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ApocalypseTheme.primary.opacity(0.3),
                                    ApocalypseTheme.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // Logo 圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                    // 地球图标
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // 标题
                VStack(spacing: 8) {
                    Text("地球新主")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("EARTH LORD")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .tracking(4)
                }
                .opacity(logoOpacity)

                Spacer()

                // 加载指示器
                VStack(spacing: 16) {
                    // 三点加载动画
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(ApocalypseTheme.primary)
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }

                    // 加载文字
                    Text(loadingText)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 60)
            }
        }
        .task {
            // 启动动画
            startAnimations()

            // 检查会话状态
            await checkSession()
        }
    }

    // MARK: - 动画方法

    private func startAnimations() {
        // Logo 入场动画
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // 启动循环动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = true
        }
    }

    // MARK: - 检查会话

    private func checkSession() async {
        // 模拟检查过程的文字变化
        loadingText = "正在检查登录状态..."
        await Task.sleep(500_000_000) // 0.5秒

        // 调用 AuthManager 检查会话
        await authManager.checkSession()

        loadingText = "准备就绪"
        await Task.sleep(500_000_000) // 0.5秒

        // 标记完成
        checkCompleted = true
    }
}

#Preview {
    SplashView()
        .environmentObject(AuthManager(supabase: SupabaseConfig.shared))
}
