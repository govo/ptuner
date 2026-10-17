import Combine
import Foundation

/// 设置页的语言切换器：手动指定 App 显示语言（含"跟随系统"）。
///
/// 生效路径：
/// 1. `L10n.effectiveCode` 优先读取 `storageKey` —— 根视图通过 `.id` 刷新文案，无需重启。
/// 2. 同步写入 `AppleLanguages` —— 系统级字符串（权限弹窗等）在下次启动时生效。
@MainActor
final class AppLanguageSettings: ObservableObject {
    static let shared = AppLanguageSettings()

    struct Option: Identifiable, Hashable {
        let id: String
        /// nil 表示跟随系统。
        let code: String?
        /// 语言自身的名称，不随界面语言变化。
        let title: String

        var displayTitle: String {
            code == nil ? L10n.tr("跟随系统") : title
        }
    }

    static let options: [Option] = [
        Option(id: L10n.systemOptionID, code: nil, title: "Follow System"),
        Option(id: "en", code: "en", title: "English"),
        Option(id: "zh-Hans", code: "zh-Hans", title: "简体中文"),
        Option(id: "zh-Hant", code: "zh-Hant", title: "繁體中文"),
        Option(id: "ja", code: "ja", title: "日本語"),
        Option(id: "ko", code: "ko", title: "한국어"),
        Option(id: "es", code: "es", title: "Español"),
        Option(id: "de", code: "de", title: "Deutsch"),
        Option(id: "fr", code: "fr", title: "Français"),
        Option(id: "it", code: "it", title: "Italiano")
    ]

    /// nil 表示跟随系统语言。
    @Published private(set) var selectedCode: String?

    /// 当前选中项的名称，用于设置页下拉行的副标题。
    var selectedTitle: String {
        Self.options.first { $0.code == selectedCode }?.displayTitle ?? L10n.tr("跟随系统")
    }

    /// 用于根视图 `.id` 的刷新标识。
    var refreshID: String {
        selectedCode ?? L10n.systemOptionID
    }

    private init() {
        selectedCode = UserDefaults.standard.string(forKey: L10n.storageKey)
    }

    func select(_ option: Option) {
        selectedCode = option.code

        let defaults = UserDefaults.standard
        if let code = option.code {
            defaults.set(code, forKey: L10n.storageKey)
            defaults.set([code], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: L10n.storageKey)
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
