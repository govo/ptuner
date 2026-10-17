import Foundation

/// 轻量本地化：中文文案作为 key，按当前语言从 Localizations.json 取译文。
/// 简体中文直接返回 key；其他语言缺词时回退英文，再回退 key。
nonisolated enum L10n {

    /// 手动选择的语言存储键，与设置页保持一致。
    static let storageKey = "ptuner.language"

    /// "跟随系统"选项的 id。
    static let systemOptionID = "system"

    /// 设置页可选语言（简体中文与繁体中文单独区分）。
    static let supportedCodes = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "es", "de", "fr", "it"]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedTable: [String: [String: String]]?

    // MARK: - 查询

    static func tr(_ key: String) -> String {
        let code = effectiveCode
        if code == "zh-Hans" { return key }

        let table = localizationTable
        if let value = table[code]?[key], !value.isEmpty { return value }
        if let value = table["en"]?[key], !value.isEmpty { return value }
        return key
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: Locale(identifier: effectiveCode), arguments: args)
    }

    // MARK: - 语言解析

    /// 当前生效的语言代码。手动选择优先，否则跟随系统，未匹配时回退英文。
    static var effectiveCode: String {
        let selected = UserDefaults.standard.string(forKey: storageKey) ?? systemOptionID
        if selected != systemOptionID, supportedCodes.contains(selected) {
            return selected
        }
        return systemResolvedCode
    }

    /// 从系统偏好语言中解析出支持的语言。
    static var systemResolvedCode: String {
        for preferred in Locale.preferredLanguages {
            let lower = preferred.lowercased()

            if lower.hasPrefix("zh-hans") || lower == "zh" {
                return "zh-Hans"
            }
            if lower.hasPrefix("zh-hant")
                || lower.hasPrefix("zh-hk")
                || lower.hasPrefix("zh-mo")
                || lower.hasPrefix("zh-tw") {
                return "zh-Hant"
            }

            for code in ["ja", "ko", "es", "de", "fr", "it"] where lower.hasPrefix(code) {
                return code
            }
            if lower.hasPrefix("en") {
                return "en"
            }
        }
        return "en"
    }

    // MARK: - 词表

    private static var localizationTable: [String: [String: String]] {
        lock.lock()
        defer { lock.unlock() }

        if let cachedTable { return cachedTable }
        let loaded = loadTable()
        cachedTable = loaded
        return loaded
    }

    private static func loadTable() -> [String: [String: String]] {
        guard
            let url = Bundle.main.url(forResource: "Localizations", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        else {
            return [:]
        }
        return object
    }
}
