import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 页面标题
                    VStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ApocalypseTheme.primary)

                        Text("更多功能")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("开发者工具与测试")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(.top, 40)

                    Spacer()
                        .frame(height: 40)

                    // 功能列表
                    VStack(spacing: 16) {
                        // Supabase 测试按钮
                        NavigationLink(destination: SupabaseTestView()) {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Supabase 连接测试")
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text("检测数据库连接状态")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MoreTabView()
}
