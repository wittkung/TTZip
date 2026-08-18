// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - AndExpression

/// Non-terminal AST node representing logical conjunction (AND).
public struct AndExpression: ArchiveFilterExpressionProtocol {
    public let left: any ArchiveFilterExpressionProtocol
    public let right: any ArchiveFilterExpressionProtocol
    
    public init(left: any ArchiveFilterExpressionProtocol, right: any ArchiveFilterExpressionProtocol) {
        self.left = left
        self.right = right
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        return left.evaluate(entry: entry) && right.evaluate(entry: entry)
    }
    
    public var dslDescription: String {
        return "(\(left.dslDescription) AND \(right.dslDescription))"
    }
}

// MARK: - OrExpression

/// Non-terminal AST node representing logical disjunction (OR).
public struct OrExpression: ArchiveFilterExpressionProtocol {
    public let left: any ArchiveFilterExpressionProtocol
    public let right: any ArchiveFilterExpressionProtocol
    
    public init(left: any ArchiveFilterExpressionProtocol, right: any ArchiveFilterExpressionProtocol) {
        self.left = left
        self.right = right
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        return left.evaluate(entry: entry) || right.evaluate(entry: entry)
    }
    
    public var dslDescription: String {
        return "(\(left.dslDescription) OR \(right.dslDescription))"
    }
}

// MARK: - NotExpression

/// Non-terminal AST node representing logical negation (NOT).
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
