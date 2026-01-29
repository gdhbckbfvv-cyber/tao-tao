//
//  TerritoryDetailView.swift
//  EarthLord
//
//  第29天：领地详情视图（完全重写）
//  全屏地图布局 + 建筑列表 + 操作菜单
//

import SwiftUI
import MapKit
import CoreLocation

struct TerritoryDetailView: View {

    // MARK: - 属性

    @State var territory: Territory
    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    @State private var showInfoPanel = true
    @State private var showBuildingBrowser = false
    @State private var selectedTemplateForConstruction: BuildingTemplate?
    @State private var showRenameDialog = false
    @State private var showDeleteConfirm = false
    @State private var newTerritoryName = ""
    @State private var isDeleting = false
    @State private var showUpgradeConfirm = false
    @State private var showDemolishConfirm = false
    @State private var selectedBuildingForAction: PlayerBuilding?

    // MARK: - 管理器

    @ObservedObject private var buildingManager = BuildingManager.shared
    @ObservedObject private var territoryManager = TerritoryManager.shared

    // MARK: - 计算属性

    /// 领地坐标数组
    private var territoryCoordinates: [CLLocationCoordinate2D] {
        territory.toCoordinates()
    }

    /// 当前领地的建筑列表
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == territory.id }
    }

    /// 模板字典
    private var templateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territoryCoordinates: territoryCoordinates,
                buildings: territoryBuildings,
                templates: templateDict
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack {
                TerritoryToolbarView(
                    onDismiss: { dismiss() },
                    onBuildingBrowser: { showBuildingBrowser = true },
                    showInfoPanel: $showInfoPanel
                )
                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
        }
        // Sheet: 建筑浏览器
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    // 延迟 0.3s 避免动画冲突
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        // Sheet: 建造确认
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: territoryCoordinates,
                onDismiss: { selectedTemplateForConstruction = nil },
                onConstructionStarted: { _ in
                    selectedTemplateForConstruction = nil
                    Task {
                        await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                    }
                }
            )
        }
        // 重命名对话框
        .alert("重命名领地", isPresented: $showRenameDialog) {
            TextField("领地名称", text: $newTerritoryName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                renameTerritory()
            }
        } message: {
            Text("请输入新的领地名称")
        }
        // 删除确认对话框
        .confirmationDialog("确定要删除这块领地吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                deleteTerritory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将无法恢复")
        }
        // 升级确认对话框
        .confirmationDialog("升级建筑", isPresented: $showUpgradeConfirm, titleVisibility: .visible) {
            Button("确认升级") {
                upgradeBuilding()
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let building = selectedBuildingForAction {
                Text("将 \(building.buildingName) 升级到 Lv.\(building.level + 1)")
            }
        }
        // 拆除确认对话框
        .confirmationDialog("拆除建筑", isPresented: $showDemolishConfirm, titleVisibility: .visible) {
            Button("确认拆除", role: .destructive) {
                demolishBuilding()
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let building = selectedBuildingForAction {
                Text("确定要拆除 \(building.buildingName) 吗？此操作不可撤销。")
            }
        }
    }

    // MARK: - 信息面板视图

    @ViewBuilder
    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名称和操作
                    territoryHeader

                    // 领地信息卡片
                    territoryInfoCard

                    // 建筑列表
                    buildingListSection

                    // 删除领地按钮
                    deleteButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ApocalypseTheme.background)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
    }

    // MARK: - 领地标题

    @ViewBuilder
    private var territoryHeader: some View {
        HStack {
            Text(territory.name ?? "未命名领地")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 齿轮按钮（重命名）
            Button {
                newTerritoryName = territory.name ?? ""
                showRenameDialog = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - 领地信息卡片

    @ViewBuilder
    private var territoryInfoCard: some View {
        HStack(spacing: 24) {
            // 面积
            VStack(spacing: 4) {
                Image(systemName: "square.dashed")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
                Text(formatArea(territory.area))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("面积")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Divider()
                .frame(height: 50)

            // 路径点
            VStack(spacing: 4) {
                Image(systemName: "mappin.circle")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.info)
                Text("\(territory.pointCount ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("路径点")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Divider()
                .frame(height: 50)

            // 建筑数量
            VStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.success)
                Text("\(territoryBuildings.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("建筑")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 建筑列表区域

    @ViewBuilder
    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("建筑列表")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(territoryBuildings.count) 个建筑")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if territoryBuildings.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 32))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("暂无建筑")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("点击顶部「建造」按钮开始建造")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            } else {
                // 建筑列表
                VStack(spacing: 8) {
                    ForEach(territoryBuildings) { building in
                        TerritoryBuildingRow(
                            building: building,
                            template: templateDict[building.templateId],
                            onUpgrade: {
                                selectedBuildingForAction = building
                                showUpgradeConfirm = true
                            },
                            onDemolish: {
                                selectedBuildingForAction = building
                                showDemolishConfirm = true
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - 删除按钮

    @ViewBuilder
    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash.fill")
                }
                Text(isDeleting ? "删除中..." : "删除领地")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.danger.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }

    // MARK: - 方法

    /// 加载数据
    private func loadData() {
        // 加载建筑模板
        if buildingManager.buildingTemplates.isEmpty {
            buildingManager.loadTemplates()
        }

        // 加载领地建筑
        Task {
            await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
        }
    }

    /// 格式化面积
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 重命名领地
    private func renameTerritory() {
        let trimmedName = newTerritoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        Task {
            let success = await territoryManager.updateTerritoryName(
                territoryId: territory.id,
                newName: trimmedName
            )

            if success {
                await MainActor.run {
                    // 更新本地对象
                    territory = Territory(
                        id: territory.id,
                        userId: territory.userId,
                        name: trimmedName,
                        path: territory.path,
                        area: territory.area,
                        pointCount: territory.pointCount,
                        isActive: territory.isActive
                    )

                    // 发送通知刷新领地列表
                    NotificationCenter.default.post(name: .territoryUpdated, object: nil)
                }
            }
        }
    }

    /// 删除领地
    private func deleteTerritory() {
        isDeleting = true

        Task {
            let success = await territoryManager.deleteTerritory(territoryId: territory.id)

            await MainActor.run {
                isDeleting = false

                if success {
                    // 发送通知刷新领地列表
                    NotificationCenter.default.post(name: .territoryDeleted, object: nil)
                    dismiss()
                }
            }
        }
    }

    /// 升级建筑
    private func upgradeBuilding() {
        guard let building = selectedBuildingForAction else { return }

        Task {
            let result = await buildingManager.upgradeBuilding(buildingId: building.id)

            if case .failure(let error) = result {
                print("❌ 升级失败: \(error)")
            }

            selectedBuildingForAction = nil
        }
    }

    /// 拆除建筑
    private func demolishBuilding() {
        guard let building = selectedBuildingForAction else { return }

        Task {
            let success = await buildingManager.demolishBuilding(buildingId: building.id)

            if !success {
                print("❌ 拆除失败")
            }

            selectedBuildingForAction = nil
        }
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "test-user",
            name: "测试领地",
            path: [
                ["lat": 31.230, "lon": 121.470],
                ["lat": 31.231, "lon": 121.470],
                ["lat": 31.231, "lon": 121.471],
                ["lat": 31.230, "lon": 121.471]
            ],
            area: 1500,
            pointCount: 20,
            isActive: true
        )
    )
}
