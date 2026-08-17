import Foundation

/// TTZip 支持的 7 大主流语言枚举 (BCP-47 规范)
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable, Codable {
    case en = "en"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja = "ja"
    case de = "de"
    case fr = "fr"
    case es = "es"
    
    public var id: String { rawValue }
    
    public var bcp47: String {
        switch self {
        case .en: return "en"
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .ja: return "ja"
        case .de: return "de"
        case .fr: return "fr"
        case .es: return "es"
        }
    }
    
    public var displayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }
    
    /// 从 POSIX 环境变量 (LC_ALL / LANG) 或 CLI 参数解析语言
    public static func from(identifier: String) -> AppLanguage? {
        let clean = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.starts(with: "zh-hant") || clean.starts(with: "zh_tw") || clean.starts(with: "zh_hk") {
            return .zhHant
        }
        if clean.starts(with: "zh") {
            return .zhHans
        }
        if clean.starts(with: "ja") {
            return .ja
        }
        if clean.starts(with: "de") {
            return .de
        }
        if clean.starts(with: "fr") {
            return .fr
        }
        if clean.starts(with: "es") {
            return .es
        }
        if clean.starts(with: "en") {
            return .en
        }
        return nil
    }
}
