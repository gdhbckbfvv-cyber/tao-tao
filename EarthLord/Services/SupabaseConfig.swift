import Foundation
import Supabase

/// Supabase 配置和全局客户端实例
enum SupabaseConfig {

    // MARK: - 配置常量

    /// Supabase 项目 URL
    static let supabaseURL = URL(string: "https://vlfvceeqwnahwcnbahth.supabase.co")!

    /// Supabase 公开密钥（Publishable Key）
    /// ⚠️ 注意：这是新格式的 publishable key，不是传统的 JWT anon key
    static let supabaseKey = "sb_publishable_zIKWJgysMWGtqXRVGEMpsQ_Ln7COtmo"

    // MARK: - 全局客户端实例

    /// 全局 Supabase 客户端
    /// 在整个应用中共享使用
    ///
    /// 配置说明：
    /// - emitLocalSessionAsInitialSession: 启用新的会话行为
    ///   总是发出本地存储的会话，无论其有效性如何
    ///   这是未来版本的推荐行为，现在手动启用
    static let shared = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey,
        options: .init(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
