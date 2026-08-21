// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// MARK: - RustFilterDSLEngine

/// High-performance compiled Filter DSL evaluator backed directly by the Rust C-ABI engine.
public final class RustFilterDSLEngine: ArchiveFilterExpressionProtocol, @unchecked Sendable {
    private let engine: OpaquePointer?
    public let dslDescription: String
    
    public init(query: String) {
        self.dslDescription = query
        self.engine = query.withCString { cStr in
            ttzip_rust_dsl_filter_new(cStr)
        }
    }
    
    deinit {
        if let engine = engine {
            ttzip_rust_dsl_filter_free(engine)
        }
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        guard let engine = engine else { return true }
        let mtime = Int64(entry.modificationDate?.timeIntervalSince1970 ?? 0)
        let size = UInt64(max(0, entry.uncompressedSize))
        return entry.path.withCString { cPath in
            ttzip_rust_dsl_filter_evaluate(engine, cPath, size, mtime)
        }
    }
}

// MARK: - ArchiveFilterDSLLexer

/// Lexer performing tokenization of DSL filter query strings.
public final class ArchiveFilterDSLLexer: Sendable {
    private let input: String
    
    public init(input: String) {
        self.input = input
    }
    
    public func tokenize() throws -> [DSLToken] {
        var tokens: [DSLToken] = []
        let chars = Array(input)
        let len = chars.count
        var idx = 0
        
        while idx < len {
            let c = chars[idx]
            if c.isWhitespace { idx += 1; continue }
            if c == "(" { tokens.append(.leftParen); idx += 1; continue }
            if c == ")" { tokens.append(.rightParen); idx += 1; continue }
            if c == ":" { tokens.append(.colon); idx += 1; continue }
            if c == "," { tokens.append(.comma); idx += 1; continue }
            if c == ">" {
                if idx + 1 < len && chars[idx + 1] == "=" { tokens.append(.greaterThanOrEqual); idx += 2 }
                else { tokens.append(.greaterThan); idx += 1 }
                continue
            }
            if c == "<" {
                if idx + 1 < len && chars[idx + 1] == "=" { tokens.append(.lessThanOrEqual); idx += 2 }
                else { tokens.append(.lessThan); idx += 1 }
                continue
            }
            if c == "=" {
                if idx + 1 < len && chars[idx + 1] == "=" { tokens.append(.equals); idx += 2 }
                else { tokens.append(.equals); idx += 1 }
                continue
            }
            if c == "!" {
                if idx + 1 < len && chars[idx + 1] == "=" { tokens.append(.identifier("!=")); idx += 2 }
                else { tokens.append(.not); idx += 1 }
                continue
            }
            if c == "&" && idx + 1 < len && chars[idx + 1] == "&" { tokens.append(.and); idx += 2; continue }
            if c == "|" && idx + 1 < len && chars[idx + 1] == "|" { tokens.append(.or); idx += 2; continue }
            
            if c == "\"" || c == "'" {
                let quote = c
                idx += 1
                var literal = ""
                var escaped = false
                var closed = false
                while idx < len {
                    let cur = chars[idx]
                    if escaped { literal.append(cur); escaped = false }
                    else if cur == "\\" { escaped = true }
                    else if cur == quote { closed = true; idx += 1; break }
                    else { literal.append(cur) }
                    idx += 1
                }
                guard closed else {
                    throw DSLParseError.invalidSyntax(message: "Unterminated string literal", position: idx)
                }
                tokens.append(.stringLiteral(literal))
                continue
            }
            
            var word = ""
            let start = idx
            while idx < len {
                let cur = chars[idx]
                if cur.isWhitespace || cur == "(" || cur == ")" || cur == ":" || cur == "," || cur == ">" || cur == "<" || cur == "=" || cur == "\"" || cur == "'" { break }
                if cur == "&" && idx + 1 < len && chars[idx + 1] == "&" { break }
                if cur == "|" && idx + 1 < len && chars[idx + 1] == "|" { break }
                word.append(cur)
                idx += 1
            }
            guard !word.isEmpty else {
                throw DSLParseError.invalidSyntax(message: "Unexpected character '\(c)'", position: start)
            }
            let upper = word.uppercased()
            if upper == "AND" { tokens.append(.and) }
            else if upper == "OR" { tokens.append(.or) }
            else if upper == "NOT" { tokens.append(.not) }
            else if let num = Int64(word) { tokens.append(.numberLiteral(num)) }
            else { tokens.append(.identifier(word)) }
        }
        return tokens
    }
}

// MARK: - ArchiveFilterDSLParser

/// Recursive descent parser constructing `ArchiveFilterExpressionProtocol` AST trees.
public final class ArchiveFilterDSLParser: Sendable {
    private let tokens: [DSLToken]
    
    public init(tokens: [DSLToken] = []) {
        self.tokens = tokens
    }
    
    public func parse() throws -> any ArchiveFilterExpressionProtocol {
        if tokens.isEmpty { return MatchAllExpression() }
        var index = 0
        let expr = try parseOr(index: &index)
        if index < tokens.count {
            throw DSLParseError.unexpectedToken(token: tokens[index], expected: "end of expression")
        }
        return expr
    }
    
    public func parseOrFallback(query: String) -> any ArchiveFilterExpressionProtocol {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return MatchAllExpression() }
        return RustFilterDSLEngine(query: trimmed)
    }
    
    private func parseOr(index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var left = try parseAnd(index: &index)
        while index < tokens.count && tokens[index] == .or {
            index += 1
            let right = try parseAnd(index: &index)
            left = OrExpression(left: left, right: right)
        }
        return left
    }
    
    private func parseAnd(index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var left = try parseNot(index: &index)
        while index < tokens.count {
            if tokens[index] == .and {
                index += 1
                let right = try parseNot(index: &index)
                left = AndExpression(left: left, right: right)
            } else if canStartPrimary(at: index) || tokens[index] == .not {
                let right = try parseNot(index: &index)
                left = AndExpression(left: left, right: right)
            } else {
                break
            }
        }
        return left
    }
    
    private func parseNot(index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        if index < tokens.count && tokens[index] == .not {
            index += 1
            let operand = try parseNot(index: &index)
            return NotExpression(operand: operand)
        }
        return try parsePrimary(index: &index)
    }
    
    private func parsePrimary(index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        guard index < tokens.count else {
            throw DSLParseError.unexpectedToken(token: nil, expected: "expression")
        }
        let cur = tokens[index]
        if cur == .leftParen {
            index += 1
            let inner = try parseOr(index: &index)
            guard index < tokens.count && tokens[index] == .rightParen else {
                throw DSLParseError.unexpectedToken(token: index < tokens.count ? tokens[index] : nil, expected: ")")
            }
            index += 1
            return inner
        }
        if case .identifier(let field) = cur {
            if index + 1 < tokens.count && (tokens[index + 1] == .colon || isComparisonOperator(tokens[index + 1])) {
                index += 1
                return try parseKeyValue(field: field.lowercased(), index: &index)
            }
        }
        switch cur {
        case .identifier(let val), .stringLiteral(let val):
            index += 1
            return FilenameGlobExpression(pattern: val)
        case .numberLiteral(let num):
            index += 1
            return FilenameGlobExpression(pattern: String(num))
        default:
            throw DSLParseError.unexpectedToken(token: cur, expected: "identifier, string literal or filter term")
        }
    }
    
    private func parseKeyValue(field: String, index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var op: ComparisonOperator = .greaterThan
        var hasExplicitOp = false
        if index < tokens.count && tokens[index] == .colon {
            index += 1
        }
        if index < tokens.count {
            switch tokens[index] {
            case .greaterThan: op = .greaterThan; hasExplicitOp = true; index += 1
            case .lessThan: op = .lessThan; hasExplicitOp = true; index += 1
            case .greaterThanOrEqual: op = .greaterThanOrEqual; hasExplicitOp = true; index += 1
            case .lessThanOrEqual: op = .lessThanOrEqual; hasExplicitOp = true; index += 1
            case .equals: op = .equals; hasExplicitOp = true; index += 1
            default: break
            }
        }
        var rawParts: [String] = []
        while index < tokens.count {
            switch tokens[index] {
            case .identifier(let val), .stringLiteral(let val): rawParts.append(val); index += 1
            case .numberLiteral(let num): rawParts.append(String(num)); index += 1
            default: break
            }
            if index < tokens.count && tokens[index] == .comma { index += 1 } else { break }
        }
        guard !rawParts.isEmpty else {
            throw DSLParseError.unexpectedToken(token: index < tokens.count ? tokens[index] : nil, expected: "field value")
        }
        let raw = rawParts.joined(separator: ",")
        switch field {
        case "ext", "extension", "type":
            return ExtensionExpression(extensions: raw.components(separatedBy: ","))
        case "name", "filename", "path":
            return FilenameGlobExpression(pattern: raw)
        case "size":
            let effOp = hasExplicitOp ? op : .greaterThan
            guard let expr = SizeExpression(sizeString: raw, operatorType: effOp) else {
                throw DSLParseError.invalidSizeFormat(raw)
            }
            return expr
        case "modified", "date", "mtime":
            let effOp = hasExplicitOp ? op : .lessThan
            guard let expr = DateRangeExpression(dateSpec: raw, operatorType: effOp) else {
                throw DSLParseError.invalidDateFormat(raw)
            }
            return expr
        default:
            return FilenameGlobExpression(pattern: "\(field):\(raw)")
        }
    }
    
    private func canStartPrimary(at index: Int) -> Bool {
        guard index < tokens.count else { return false }
        switch tokens[index] {
        case .leftParen, .identifier, .stringLiteral, .numberLiteral: return true
        default: return false
        }
    }
    
    private func isComparisonOperator(_ token: DSLToken) -> Bool {
        switch token {
        case .greaterThan, .lessThan, .greaterThanOrEqual, .lessThanOrEqual, .equals: return true
        default: return false
        }
    }
}
