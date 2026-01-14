//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 12/24/25.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// 认证管理器
    @StateObject private var authManager = AuthManager(
        supabase: SupabaseConfig.shared
    )

    /// 语言管理器
    @ObservedObject var languageManager = LanguageManager.shared

    /// 是否显示启动画面
    @State private var showSplash = true

    /// 🆕 App 生命周期状态（用于玩家位置上报）
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 主内容区域
                Group {
                    if authManager.isAuthenticated {
                        // 已完全认证，显示主界面
                        MainTabView()
                            .environmentObject(authManager)
                            .transition(.opacity)
                    } else {
                        // 未认证，显示登录/注册页面
                        AuthView()
                            .environmentObject(authManager)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)

                // 启动画面（覆盖在最上层）
                if showSplash {
                    SplashView()
                        .environmentObject(authManager)
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            // 1.5秒后隐藏启动画面
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSplash = false
                                }
                            }
                        }
                }
            }
            .environment(\.locale, languageManager.currentLocale)
            .id(languageManager.currentLocale.identifier)
            .onOpenURL { url in
                // 处理 Google Sign-In 的 URL 回调
                print("📱 收到 URL Scheme 回调: \(url.absoluteString)")
                _ = authManager.handleGoogleSignInURL(url)
            }
            // 🆕 监听 App 生命周期变化，管理玩家位置上报
            .onChange(of: scenePhase) { newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    // MARK: - 🆕 App 生命周期处理

    /// 处理 App 生命周期变化
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App 激活，恢复正常上报频率（仅当已登录时）
            print("📱 [App] 进入前台")
            if authManager.isAuthenticated {
                PlayerLocationService.shared.setBackgroundMode(false)
                PlayerLocationService.shared.startLocationReporting()
            }

        case .background:
            // App 进入后台，降低上报频率但继续上报
            print("📱 [App] 进入后台")
            if authManager.isAuthenticated {
                PlayerLocationService.shared.setBackgroundMode(true)
            }

        case .inactive:
            // App 不活跃（如收到电话、下拉通知栏等）
            print("📱 [App] 变为不活跃")

        @unknown default:
            break
        }
    }
}
