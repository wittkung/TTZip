// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance compiled Filter DSL evaluator and facade backed directly by Rust C-ABI.
public final class ArchiveFilter: @unchecked Sendable {
    private let engine: OpaquePointer?
    public let expression: String
    
    /// Initializes and pre-compiles a Filter DSL expression using Rust DFA engine.
    /// - Parameter expression: DSL query string (e.g. `ext:zip AND size > 1MB`).
    public init(expression: String) {
        self.expression = expression
        self.engine = expression.withCString { cStr in
            ttzip_rust_create_filter_dsl_engine(cStr)
        }
    }
    
    deinit {
        if let engine = engine {
            ttzip_rust_free_filter_dsl_engine(engine)
        }
    }
    
    /// Evaluates whether an archive entry satisfies the compiled filter expression via Rust C-ABI.
    /// - Parameter entry: Archive entry to evaluate.
    /// - Returns: True if entry passes filter, false otherwise.
    public func evaluate(entry: ArchiveEntry) -> Bool {
        guard let engine = engine else { return true }
        let mtime = Int64(entry.modificationDate?.timeIntervalSince1970 ?? 0)
        let size = UInt64(max(0, entry.uncompressedSize))
        return entry.path.withCString { cPath in
            ttzip_rust_eval_filter_dsl(engine, cPath, size, mtime)
        }
    }
    
    /// One-shot static evaluation of an entry against a DSL expression.
    /// - Parameters:
    ///   - expression: DSL query string.
    ///   - entry: Target archive entry.
    /// - Returns: True if entry passes filter, false otherwise.
    public static func evaluate(expression: String, entry: ArchiveEntry) -> Bool {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let filter = ArchiveFilter(expression: trimmed)
        return filter.evaluate(entry: entry)
    }
    
    /// Static evaluation of an entry against a query string.
    /// - Parameters:
    ///   - entry: Target archive entry.
    ///   - query: DSL query string.
    /// - Returns: True if entry passes filter, false otherwise.
    public static func evaluate(entry: ArchiveEntry, query: String) -> Bool {
        return evaluate(expression: query, entry: entry)
    }
    
    /// Filters a collection of archive entries using a compiled DSL expression.
    /// - Parameters:
    ///   - entries: List of archive entries.
    ///   - expression: DSL query string.
    /// - Returns: Filtered list of matching archive entries.
    public static func filter(entries: [ArchiveEntry], expression: String) -> [ArchiveEntry] {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return entries }
        let filter = ArchiveFilter(expression: trimmed)
        return entries.filter { filter.evaluate(entry: $0) }
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
            return ArchiveFilter.evaluate(expression: query, entry: entry)
        }
        
        return true
    }
}
