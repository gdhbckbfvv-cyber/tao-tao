//
//  TerritoryListView.swift
//  EarthLord
//
//  领地列表视图
//  显示用户已上传的所有领地
//

import SwiftUI

struct TerritoryListView: View {

    // MARK: - 状态

    @Environment(\.dismiss) private var dismiss
    @State private var territories: [Territory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await loadTerritories()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadTerritories()
            }
        }
    }

    // MARK: - 子视图

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
    }

    /// 错误视图
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("重试") {
                Task {
                    await loadTerritories()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    /// 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("暂无领地")
                .font(.headline)
            Text("开始圈地后，您的领地将显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    /// 领地列表
    private var territoryList: some View {
        List {
            ForEach(territories) { territory in
                NavigationLink(destination: TerritoryDetailView(territory: territory)) {
                    TerritoryRow(territory: territory)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 方法

    /// 加载领地数据
    private func loadTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            territories = try await TerritoryManager.shared.loadAllTerritories()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 领地行视图

struct TerritoryRow: View {
    let territory: Territory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.green)
                Text(territory.name ?? "未命名领地")
                    .font(.headline)
                Spacer()
            }

            // 详细信息
            VStack(alignment: .leading, spacing: 4) {
                InfoRow(
                    icon: "square.dashed",
                    label: "面积",
                    value: formatArea(territory.area)
                )

                if let pointCount = territory.pointCount {
                    InfoRow(
                        icon: "mappin.circle",
                        label: "路径点",
                        value: "\(pointCount) 个"
                    )
                }

                InfoRow(
                    icon: "checkmark.circle",
                    label: "状态",
                    value: (territory.isActive ?? true) ? "激活" : "未激活"
                )
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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

// MARK: - 信息行视图

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
            Text(label + ":")
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryListView()
}
