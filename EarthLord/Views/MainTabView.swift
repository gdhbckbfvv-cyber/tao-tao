import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 地图
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            // Tab 2: 领地
            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            // Tab 3: 资源（新增）
            ResourcesTabView()
                .tabItem {
                    Image(systemName: "cube.fill")
                    Text("资源")
                }
                .tag(2)

            // Tab 4: 个人
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            // Tab 5: 更多
            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(4)

            // Tab 6: 测试（开发用）
            TerritoryTestView()
                .tabItem {
                    Image(systemName: "hammer.fill")
                    Text("测试")
                }
                .tag(5)
        }
        .tint(ApocalypseTheme.primary)
    }
}

#Preview {
    MainTabView()
}
