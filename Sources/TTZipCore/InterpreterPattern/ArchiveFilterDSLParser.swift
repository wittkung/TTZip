// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - ArchiveFilterDSLParser

/// Recursive descent parser constructing `ArchiveFilterExpressionProtocol` AST trees.
public final class ArchiveFilterDSLParser: Sendable {
    private let tokens: [DSLToken]
    
    public init(tokens: [DSLToken] = []) {
        self.tokens = tokens
    }
    
    public func parse() throws -> any ArchiveFilterExpressionProtocol {
        if tokens.isEmpty {
            return MatchAllExpression()
        }
        var index = 0
        let expr = try parseOrExpression(tokens: tokens, index: &index)
        if index < tokens.count {
            let trailingToken = tokens[index]
            throw DSLParseError.unexpectedToken(token: trailingToken, expected: "end of expression")
        }
        return expr
    }
    
    public func parseOrFallback(query: String) -> any ArchiveFilterExpressionProtocol {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return MatchAllExpression()
        }
        
        do {
            let lexer = ArchiveFilterDSLLexer(input: trimmed)
            let parsedTokens = try lexer.tokenize()
            let parser = ArchiveFilterDSLParser(tokens: parsedTokens)
            return try parser.parse()
        } catch {
            return FilenameGlobExpression(pattern: trimmed)
        }
    }
    
    // MARK: - Recursive Descent Precedence Parsers
    
    private func parseOrExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var left = try parseAndExpression(tokens: tokens, index: &index)
        
        while index < tokens.count {
            if tokens[index] == .or {
                index += 1
                let right = try parseAndExpression(tokens: tokens, index: &index)
                left = OrExpression(left: left, right: right)
            } else {
                break
            }
        }
        return left
    }
    
    private func parseAndExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var left = try parseNotExpression(tokens: tokens, index: &index)
        
        while index < tokens.count {
            if tokens[index] == .and {
                index += 1
                let right = try parseNotExpression(tokens: tokens, index: &index)
                left = AndExpression(left: left, right: right)
            } else if canStartPrimaryExpression(at: index, tokens: tokens) || tokens[index] == .not {
                let right = try parseNotExpression(tokens: tokens, index: &index)
                left = AndExpression(left: left, right: right)
            } else {
                break
            }
        }
        return left
    }
    
    private func parseNotExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        if index < tokens.count && tokens[index] == .not {
            index += 1
            let operand = try parseNotExpression(tokens: tokens, index: &index)
            return NotExpression(operand: operand)
        }
        return try parsePrimaryExpression(tokens: tokens, index: &index)
    }
    
    private func parsePrimaryExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        guard index < tokens.count else {
            throw DSLParseError.unexpectedToken(token: nil, expected: "expression")
        }
        
        let currentToken = tokens[index]
        
        if currentToken == .leftParen {
            index += 1
            let innerExpr = try parseOrExpression(tokens: tokens, index: &index)
            guard index < tokens.count && tokens[index] == .rightParen else {
                throw DSLParseError.unexpectedToken(token: index < tokens.count ? tokens[index] : nil, expected: ")")
            }
            index += 1
            return innerExpr
        }
        
        if case .identifier(let fieldName) = currentToken {
            let lowerField = fieldName.lowercased()
            if index + 1 < tokens.count && tokens[index + 1] == .colon {
                index += 2
                return try parseKeyValueExpression(field: lowerField, tokens: tokens, index: &index)
            }
        }
        
        switch currentToken {
        case .identifier(let val):
            index += 1
            return FilenameGlobExpression(pattern: val)
        case .stringLiteral(let val):
            index += 1
            return FilenameGlobExpression(pattern: val)
        case .numberLiteral(let num):
            index += 1
            return FilenameGlobExpression(pattern: String(num))
        default:
            throw DSLParseError.unexpectedToken(token: currentToken, expected: "identifier, string literal or key:value filter")
        }
    }
    
    private func parseKeyValueExpression(field: String, tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var op: ComparisonOperator = .greaterThan
        var hasExplicitOp = false
        
        if index < tokens.count {
            switch tokens[index] {
            case .greaterThan:
                op = .greaterThan
                hasExplicitOp = true
                index += 1
            case .lessThan:
                op = .lessThan
                hasExplicitOp = true
                index += 1
            case .greaterThanOrEqual:
                op = .greaterThanOrEqual
                hasExplicitOp = true
                index += 1
            case .lessThanOrEqual:
                op = .lessThanOrEqual
                hasExplicitOp = true
                index += 1
            case .equals:
                op = .equals
                hasExplicitOp = true
                index += 1
            default:
                break
            }
        }
        
        var rawValueParts: [String] = []
        while index < tokens.count {
            switch tokens[index] {
            case .identifier(let val):
                rawValueParts.append(val)
                index += 1
            case .stringLiteral(let val):
                rawValueParts.append(val)
                index += 1
            case .numberLiteral(let num):
                rawValueParts.append(String(num))
                index += 1
            default:
                break
            }
            
            if index < tokens.count && tokens[index] == .comma {
                index += 1
            } else {
                break;
            }
        }
        
        guard !rawValueParts.isEmpty else {
            throw DSLParseError.unexpectedToken(token: index < tokens.count ? tokens[index] : nil, expected: "field value")
        }
        
        let rawValue = rawValueParts.joined(separator: ",")
        
        switch field {
        case "ext", "extension", "type":
            let exts = rawValue.components(separatedBy: ",")
            return ExtensionExpression(extensions: exts)
            
        case "name", "filename", "path":
            return FilenameGlobExpression(pattern: rawValue)
            
        case "size":
            let effectiveOp = hasExplicitOp ? op : .greaterThan
            guard let expr = SizeExpression(sizeString: rawValue, operatorType: effectiveOp) else {
                throw DSLParseError.invalidSizeFormat(rawValue)
            }
            return expr
            
        case "modified", "date", "mtime":
            let effectiveOp = hasExplicitOp ? op : .lessThan
            guard let expr = DateRangeExpression(dateSpec: rawValue, operatorType: effectiveOp) else {
                throw DSLParseError.invalidDateFormat(rawValue)
            }
            return expr
            
        default:
            return FilenameGlobExpression(pattern: "\(field):\(rawValue)")
        }
    }
    
    private func canStartPrimaryExpression(at index: Int, tokens: [DSLToken]) -> Bool {
        guard index < tokens.count else { return false }
        switch tokens[index] {
        case .leftParen, .identifier, .stringLiteral, .numberLiteral:
            return true
        default:
            return false
        }
    }
}
