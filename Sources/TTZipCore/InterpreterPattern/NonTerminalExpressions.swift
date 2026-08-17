import Foundation

// MARK: - AndExpression (逻辑与非终结符)

/// 逻辑与 (AND) 抽象语法树非终结节点
public struct AndExpression: ArchiveFilterExpressionProtocol {
    public let left: any ArchiveFilterExpressionProtocol
    public let right: any ArchiveFilterExpressionProtocol
    
    public init(left: any ArchiveFilterExpressionProtocol, right: any ArchiveFilterExpressionProtocol) {
        self.left = left
        self.right = right
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        // 短路求值优化：如果左侧为 false，无需评估右侧
        return left.evaluate(entry: entry) && right.evaluate(entry: entry)
    }
    
    public var dslDescription: String {
        return "(\(left.dslDescription) AND \(right.dslDescription))"
    }
}

// MARK: - OrExpression (逻辑或非终结符)

/// 逻辑或 (OR) 抽象语法树非终结节点
public struct OrExpression: ArchiveFilterExpressionProtocol {
    public let left: any ArchiveFilterExpressionProtocol
    public let right: any ArchiveFilterExpressionProtocol
    
    public init(left: any ArchiveFilterExpressionProtocol, right: any ArchiveFilterExpressionProtocol) {
        self.left = left
        self.right = right
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        // 短路求值优化：如果左侧为 true，无需评估右侧
        return left.evaluate(entry: entry) || right.evaluate(entry: entry)
    }
    
    public var dslDescription: String {
        return "(\(left.dslDescription) OR \(right.dslDescription))"
    }
}

// MARK: - NotExpression (逻辑非非终结符)

/// 逻辑非 (NOT) 抽象语法树非终结节点
public struct NotExpression: ArchiveFilterExpressionProtocol {
    public let operand: any ArchiveFilterExpressionProtocol
    
    public init(operand: any ArchiveFilterExpressionProtocol) {
        self.operand = operand
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        return !operand.evaluate(entry: entry)
    }
    
    public var dslDescription: String {
        return "NOT (\(operand.dslDescription))"
    }
}
