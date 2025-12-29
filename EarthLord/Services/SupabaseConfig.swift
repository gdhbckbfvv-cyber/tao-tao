import Foundation
import Supabase

/// Supabase 配置和全局客户端实例
enum SupabaseConfig {

    // MARK: - 配置常量

    /// Supabase 项目 URL
    static let supabaseURL = URL(string: "https://vlfvceeqwnahwcnbahth.supabase.co")!

    /// Supabase 公开密钥（Anon Key）
    static let supabaseKey = "sb_publishable_zIKWJgysMWGtqXRVGEMpsQ_Ln7COtmo"

    // MARK: - 全局客户端实例

    /// 全局 Supabase 客户端
    /// 在整个应用中共享使用
    static let shared = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey
    )
}
