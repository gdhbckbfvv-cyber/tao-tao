import SwiftUI

/// 根视图：主界面的根容器
/// 注意：启动页逻辑已移至 EarthLordApp.swift
struct RootView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    RootView()
}
