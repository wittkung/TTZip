import Foundation

// MARK: - ArchiveFilterExpressionProtocol (解释器抽象表达式协议)

/// AST 抽象语法树解释器节点协议
public protocol ArchiveFilterExpressionProtocol: Sendable {
    /// 评估归档条目是否符合当前表达式节点条件
    /// - Parameter entry: 被评估的归档文件条目 (ArchiveEntry)
    /// - Returns: 符合为 true，否则为 false
    func evaluate(entry: ArchiveEntry) -> Bool
    
    /// 表达式的 DSL 可读描述 (用于调试与 AST 节点树生成)
    var dslDescription: String { get }
}

// MARK: - DSLToken (词法 Token 枚举)

/// DSL 词法分析 Token
public enum DSLToken: Equatable, Sendable, CustomStringConvertible {
    case identifier(String)          // 字段名或普通标识符 (如 ext, name, size, modified 等)
    case colon                        // ':' 键值分隔符
    case stringLiteral(String)      // 带引号的字符串字面量
    case numberLiteral(Int64)        // 纯数字
    case and                          // 逻辑与 (AND, and, &&)
    case or                           // 逻辑或 (OR, or, ||)
    case not                          // 逻辑非 (NOT, not, !)
    case leftParen                    // '('
    case rightParen                   // ')'
    case greaterThan                  // '>'
    case lessThan                     // '<'
    case greaterThanOrEqual           // '>='
    case lessThanOrEqual              // '<='
    case equals                       // '=' or '=='
    case comma                        // ','
    
    public var description: String {
        switch self {
        case .identifier(let val): return "ID(\(val))"
        case .colon: return ":"
        case .stringLiteral(let str): return "\"\(str)\""
        case .numberLiteral(let num): return "NUM(\(num))"
        case .and: return "AND"
        case .or: return "OR"
        case .not: return "NOT"
        case .leftParen: return "("
        case .rightParen: return ")"
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .greaterThanOrEqual: return ">="
        case .lessThanOrEqual: return "<="
        case .equals: return "="
        case .comma: return ","
        }
    }
}

// MARK: - DSLParseError (语法解析异常枚举)

/// DSL 解析错误结构
public enum DSLParseError: Error, Equatable, Sendable, LocalizedError {
    case unexpectedToken(token: DSLToken?, expected: String)
    case invalidSyntax(message: String, position: Int)
    case unknownField(name: String)
    case invalidSizeFormat(String)
    case invalidDateFormat(String)
    case emptyQuery
    
    public var errorDescription: String? {
        switch self {
        case .unexpectedToken(let token, let expected):
            return "Unexpected token '\(token?.description ?? "EOF")', expected: \(expected)"
        case .invalidSyntax(let message, let position):
            return "Syntax error at position \(position): \(message)"
        case .unknownField(let name):
            return "Unknown filter field '\(name)'"
        case .invalidSizeFormat(let val):
            return "Invalid size specification '\(val)'"
        case .invalidDateFormat(let val):
            return "Invalid date specification '\(val)'"
        case .emptyQuery:
            return "Empty search query"
        }
    }
}
