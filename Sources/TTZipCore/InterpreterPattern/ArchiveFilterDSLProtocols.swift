// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - ArchiveFilterExpressionProtocol

/// Abstract expression protocol for AST interpreter nodes (Interpreter Pattern).
public protocol ArchiveFilterExpressionProtocol: Sendable {
    /// Evaluates whether an archive entry satisfies the filter expression.
    /// - Parameter entry: Archive entry to evaluate.
    /// - Returns: True if entry passes filter, false otherwise.
    func evaluate(entry: ArchiveEntry) -> Bool
    
    /// Human-readable DSL representation of the expression tree.
    var dslDescription: String { get }
}

// MARK: - DSLToken

/// Lexical tokens generated during DSL tokenization.
public enum DSLToken: Equatable, Sendable, CustomStringConvertible {
    case identifier(String)          // Field names or tokens (e.g. ext, name, size, modified)
    case colon                       // ':' key-value separator
    case stringLiteral(String)       // Quoted string literal
    case numberLiteral(Int64)        // Integer number literal
    case and                         // Logical AND (AND, and, &&)
    case or                          // Logical OR (OR, or, ||)
    case not                         // Logical NOT (NOT, not, !)
    case leftParen                   // '('
    case rightParen                  // ')'
    case greaterThan                 // '>'
    case lessThan                    // '<'
    case greaterThanOrEqual          // '>='
    case lessThanOrEqual             // '<='
    case equals                      // '=' or '=='
    case comma                       // ','
    
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

// MARK: - DSLParseError

/// DSL parsing and tokenization error cases.
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
