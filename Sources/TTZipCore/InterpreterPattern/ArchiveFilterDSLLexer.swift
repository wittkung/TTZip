// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
        let length = chars.count
        var index = 0
        
        while index < length {
            let char = chars[index]
            
            // 1. Whitespace skipping
            if char.isWhitespace {
                index += 1
                continue
            }
            
            // 2. Parentheses and punctuation
            if char == "(" {
                tokens.append(.leftParen)
                index += 1
                continue
            }
            if char == ")" {
                tokens.append(.rightParen)
                index += 1
                continue
            }
            if char == ":" {
                tokens.append(.colon)
                index += 1
                continue
            }
            if char == "," {
                tokens.append(.comma)
                index += 1
                continue
            }
            
            // 3. Comparison operators
            if char == ">" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.greaterThanOrEqual)
                    index += 2
                } else {
                    tokens.append(.greaterThan)
                    index += 1
                }
                continue
            }
            if char == "<" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.lessThanOrEqual)
                    index += 2
                } else {
                    tokens.append(.lessThan)
                    index += 1
                }
                continue
            }
            if char == "=" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.equals)
                    index += 2
                } else {
                    tokens.append(.equals)
                    index += 1
                }
                continue
            }
            if char == "!" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.identifier("!="))
                    index += 2
                } else {
                    tokens.append(.not)
                    index += 1
                }
                continue
            }
            
            // 4. Logical operators (&& and ||)
            if char == "&" && index + 1 < length && chars[index + 1] == "&" {
                tokens.append(.and)
                index += 2
                continue
            }
            if char == "|" && index + 1 < length && chars[index + 1] == "|" {
                tokens.append(.or)
                index += 2
                continue
            }
            
            // 5. String literals
            if char == "\"" || char == "'" {
                let quote = char
                index += 1
                var literal = ""
                var escaped = false
                var closed = false
                
                while index < length {
                    let current = chars[index]
                    if escaped {
                        literal.append(current)
                        escaped = false
                    } else if current == "\\" {
                        escaped = true
                    } else if current == quote {
                        closed = true
                        index += 1
                        break
                    } else {
                        literal.append(current)
                    }
                    index += 1
                }
                
                if !closed {
                    throw DSLParseError.invalidSyntax(message: "Unterminated string literal", position: index)
                }
                tokens.append(.stringLiteral(literal))
                continue
            }
            
            // 6. Identifiers, keywords, numbers, or glob words
            var valueStr = ""
            let startPos = index
            while index < length {
                let c = chars[index]
                if c.isWhitespace || c == "(" || c == ")" || c == ":" || c == "," || c == ">" || c == "<" || c == "=" || c == "\"" || c == "'" {
                    break
                }
                if c == "&" && index + 1 < length && chars[index + 1] == "&" { break }
                if c == "|" && index + 1 < length && chars[index + 1] == "|" { break }
                
                valueStr.append(c)
                index += 1
            }
            
            if valueStr.isEmpty {
                throw DSLParseError.invalidSyntax(message: "Unexpected character '\(char)'", position: startPos)
            }
            
            let upper = valueStr.uppercased()
            if upper == "AND" {
                tokens.append(.and)
            } else if upper == "OR" {
                tokens.append(.or)
            } else if upper == "NOT" {
                tokens.append(.not)
            } else if let num = Int64(valueStr) {
                tokens.append(.numberLiteral(num))
            } else {
                tokens.append(.identifier(valueStr))
            }
        }
        
        return tokens
    }
}
