import SwiftUI

struct TerritoryTabView: View {

    // MARK: - 状态

    @State private var territories: [Territory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                // 内容
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error: error)
                } else if territories.isEmpty {
                    emptyView
                } else {
                    territoryList
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await loadTerritories()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadTerritories()
            }
            // 监听领地更新通知
            .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
                Task {
                    await loadTerritories()
                }
            }
            // 监听领地删除通知
            .onReceive(NotificationCenter.default.publisher(for: .territoryDeleted)) { _ in
                Task {
                    await loadTerritories()
                }
            }
        }
    }

    // MARK: - 子视图

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(ApocalypseTheme.primary)
            Text("加载中...")
                .foregroundColor(.gray)
        }
    }

    /// 错误视图
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
                .foregroundColor(.white)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("重试") {
                Task {
                    await loadTerritories()
                }
            }
            .buttonStyle(.bordered)
            .tint(ApocalypseTheme.primary)
        }
        .padding()
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.primary.opacity(0.6))
            Text("暂无领地")
                .font(.headline)
                .foregroundColor(.white)
            Text("前往地图页面开始圈地\n您的领地将显示在这里")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    /// 领地列表
    private var territoryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(territories) { territory in
                    NavigationLink(destination: TerritoryDetailView(territory: territory)) {
                        TerritoryCard(territory: territory)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }

    // MARK: - 方法

    /// 加载领地数据
    private func loadTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            territories = try await TerritoryManager.shared.loadAllTerritories()
            print("✅ 领地 Tab：加载成功，共 \(territories.count) 块领地")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ 领地 Tab：加载失败 - \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - 领地卡片

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.success)

                VStack(alignment: .leading, spacing: 4) {
                    Text(territory.name ?? "领地 #\(territory.id.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let pointCount = territory.pointCount {
                        Text("\(pointCount) 个路径点")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // 状态标记
                if territory.isActive ?? true {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("激活")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // 详细信息
            HStack(spacing: 20) {
                InfoItem(
                    icon: "square.dashed",
                    label: "面积",
                    value: formatArea(territory.area)
                )

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }

    /// 格式化面积
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }
}

// MARK: - 信息项

struct InfoItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    TerritoryTabView()
}
