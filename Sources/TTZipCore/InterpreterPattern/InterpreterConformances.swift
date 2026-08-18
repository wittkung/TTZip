// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - ArchiveFilterDSLInterpreter

/// Integrated entry point and facade for archive filter DSL parsing and evaluation.
public struct ArchiveFilterDSLInterpreter: Sendable {
    /// Parses a DSL query string into an AST filter expression tree.
    /// - Parameter query: Query string to parse.
    /// - Returns: Root AST expression conforming to `ArchiveFilterExpressionProtocol`.
    public static func parse(_ query: String) throws -> any ArchiveFilterExpressionProtocol {
        let lexer = ArchiveFilterDSLLexer(input: query)
        let tokens = try lexer.tokenize()
        let parser = ArchiveFilterDSLParser(tokens: tokens)
        return try parser.parse()
    }
    
    /// Parses a DSL query with safe fallback to simple substring/glob match on syntax errors.
    public static func parseOrFallback(_ query: String) -> any ArchiveFilterExpressionProtocol {
        let parser = ArchiveFilterDSLParser()
        return parser.parseOrFallback(query: query)
    }
    
    /// Evaluates an archive entry against a query string.
    public static func evaluate(entry: ArchiveEntry, query: String) -> Bool {
        let expr = parseOrFallback(query)
        return expr.evaluate(entry: entry)
    }
}

// MARK: - ArchiveFilterOptions DSL Extension

extension ArchiveFilterOptions {
    /// Evaluates whether an archive entry passes options and optional DSL query constraints.
    public func matches(entry: ArchiveEntry, dslQuery: String? = nil) -> Bool {
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
        
        if let query = dslQuery, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expr = ArchiveFilterDSLInterpreter.parseOrFallback(query)
            return expr.evaluate(entry: entry)
        }
        
        return true
    }
}
