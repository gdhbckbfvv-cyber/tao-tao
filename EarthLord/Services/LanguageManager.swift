import Foundation
import SwiftUI
import Combine

/// 语言管理器
/// 管理应用内语言切换，不依赖系统语言设置
class LanguageManager: ObservableObject {

    /// 单例实例
    static let shared = LanguageManager()

    /// 支持的语言
    enum Language: String, CaseIterable, Identifiable {
        case system = "system"      // 跟随系统
        case chinese = "zh-Hans"    // 简体中文
        case english = "en"         // English

        var id: String { rawValue }

        /// 显示名称
        var displayName: String {
            switch self {
            case .system:
                return NSLocalizedString("跟随系统", comment: "")
            case .chinese:
                return "简体中文"
            case .english:
                return "English"
            }
        }

        /// 图标
        var icon: String {
            switch self {
            case .system:
                return "globe"
            case .chinese:
                return "character.textbox"
            case .english:
                return "textformat.abc"
            }
        }
    }

    // MARK: - Properties

    /// 当前选择的语言
    @Published var currentLanguage: Language {
        didSet {
            saveLanguagePreference()
            updateCurrentLocale()
        }
    }

    /// 当前使用的 Locale
    @Published var currentLocale: Locale

    /// UserDefaults key
    private let languageKey = "app_language_preference"

    // MARK: - Initialization

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        let savedLanguage: Language
        if let savedLanguageString = UserDefaults.standard.string(forKey: languageKey),
           let language = Language(rawValue: savedLanguageString) {
            savedLanguage = language
        } else {
            // 默认跟随系统
            savedLanguage = .system
        }

        // 初始化属性
        self.currentLanguage = savedLanguage
        self.currentLocale = Self.getLocale(for: savedLanguage)

        print("🌍 LanguageManager 初始化")
        print("   当前语言设置: \(currentLanguage.displayName)")
        print("   当前 Locale: \(currentLocale.identifier)")
    }

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func switchLanguage(to language: Language) {
        print("🌍 切换语言: \(currentLanguage.displayName) → \(language.displayName)")
        currentLanguage = language
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化 key
    ///   - comment: 注释
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        // 如果是跟随系统，使用系统的本地化
        if currentLanguage == .system {
            return NSLocalizedString(key, comment: comment)
        }

        // 否则使用指定语言的本地化
        guard let bundlePath = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: bundlePath) else {
            print("⚠️ 找不到语言包: \(currentLanguage.rawValue)")
            return NSLocalizedString(key, comment: comment)
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // MARK: - Private Methods

    /// 保存语言设置到 UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 已保存语言设置: \(currentLanguage.displayName)")
    }

    /// 更新当前 Locale
    private func updateCurrentLocale() {
        currentLocale = Self.getLocale(for: currentLanguage)
        print("🔄 已更新 Locale: \(currentLocale.identifier)")
    }

    /// 获取指定语言的 Locale
    /// - Parameter language: 语言
    /// - Returns: Locale
    private static func getLocale(for language: Language) -> Locale {
        switch language {
        case .system:
            return Locale.current
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

// MARK: - SwiftUI Extension

/// 自定义本地化修饰符
struct LocalizedViewModifier: ViewModifier {
    @ObservedObject var languageManager = LanguageManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, languageManager.currentLocale)
            .id(languageManager.currentLocale.identifier) // 强制刷新视图
    }
}

extension View {
    /// 应用语言管理器
    func withLanguageManager() -> some View {
        modifier(LocalizedViewModifier())
    }
}

// MARK: - String Extension

extension String {
    /// 本地化字符串
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }

    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}
