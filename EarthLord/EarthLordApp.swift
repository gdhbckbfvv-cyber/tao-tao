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

    /// 是否显示启动画面
    @State private var showSplash = true

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
        }
    }
}
