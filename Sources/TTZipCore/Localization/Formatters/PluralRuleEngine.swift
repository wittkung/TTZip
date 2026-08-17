import Foundation

/// Unicode CLDR 标准复数分类
public enum PluralCategory: Sendable {
    case zero
    case one
    case two
    case few
    case many
    case other
}

/// 7 种主流语言 CLDR 复数规则评估引擎
public enum PluralRuleEngine {
    
    /// 根据语言与数量评估复数类别
    public static func evaluate(count: Int64, language: AppLanguage) -> PluralCategory {
        switch language {
        case .zhHans, .zhHant, .ja:
            // 中文、日文属于无形态单复数变化语言 (Other-only)
            return .other
            
        case .en, .de, .es:
            // 英语、德语、西班牙语 (n == 1 -> one, else -> other)
            return (count == 1) ? .one : .other
            
        case .fr:
            // 法语 (0 和 1 算单数 one)
            return (count == 0 || count == 1) ? .one : .other
        }
    }
}
