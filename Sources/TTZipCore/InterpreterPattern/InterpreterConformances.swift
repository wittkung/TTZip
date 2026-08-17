import Foundation

// MARK: - ArchiveFilterDSLInterpreter (解释器模式外观层/集成入口)

public struct ArchiveFilterDSLInterpreter: Sendable {
    /// 解析 DSL 查询字符串为 AST 抽象语法树表达式
    /// - Parameter query: 检索表达式字符串
    /// - Returns: 符合 ArchiveFilterExpressionProtocol 协议的 AST 根节点
    public static func parse(_ query: String) throws -> any ArchiveFilterExpressionProtocol {
        let lexer = ArchiveFilterDSLLexer(input: query)
        let tokens = try lexer.tokenize()
        let parser = ArchiveFilterDSLParser(tokens: tokens)
        return try parser.parse()
    }
    
    /// 解析 DSL 表达式，在遇到错误时提供 Safe Fallback 容错降级根节点
    /// - Parameter query: 检索表达式字符串
    /// - Returns: AST 根节点 (绝对不抛出异常)
    public static func parseOrFallback(_ query: String) -> any ArchiveFilterExpressionProtocol {
        let parser = ArchiveFilterDSLParser()
        return parser.parseOrFallback(query: query)
    }
    
    /// 对单一 ArchiveEntry 进行快速 AST 求值
    /// - Parameters:
    ///   - entry: 归档文件条目
    ///   - query: DSL 过滤语句
    /// - Returns: 是否通过筛选
    public static func evaluate(entry: ArchiveEntry, query: String) -> Bool {
        let expr = parseOrFallback(query)
        return expr.evaluate(entry: entry)
    }
}

// MARK: - ArchiveFilterOptions 解释器扩展

extension ArchiveFilterOptions {
    /// 评估给定条目是否满足当前 ArchiveFilterOptions 及其附带的 DSL 条件
    /// - Parameters:
    ///   - entry: 归档条目
    ///   - dslQuery: 可选的 DSL 筛选查询字符串
    /// - Returns: 是否通过过滤
    public func matches(entry: ArchiveEntry, dslQuery: String? = nil) -> Bool {
        // 1. 系统级文件与忽略模式检测
        if skipMacJunk {
            if entry.name == ".DS_Store" || entry.name.hasPrefix("._") || entry.path.contains("__MACOSX/") {
                return false
            }
        }
        if skipGitDirectory {
            if entry.name == ".git" || entry.path.contains("/.git/") || entry.path.hasPrefix(".git/") {
                return false
            }
        }
        for pattern in customIgnorePatterns {
            if entry.path.contains(pattern) || entry.name == pattern {
                return false
            }
        }
        
        // 2. DSL 表达式求值
        if let query = dslQuery, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expr = ArchiveFilterDSLInterpreter.parseOrFallback(query)
            return expr.evaluate(entry: entry)
        }
        
        return true
    }
}
