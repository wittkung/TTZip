// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-allocation lifetime-borrowed DSL Lexer for archive filter expressions.

use std::fmt;

/// Lexical tokens borrowing slices directly from query string with zero allocations.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DslToken<'a> {
    Identifier(&'a str),
    Colon,
    StringLiteral(&'a str),
    NumberLiteral(i64),
    And,
    Or,
    Not,
    LeftParen,
    RightParen,
    GreaterThan,
    LessThan,
    GreaterThanOrEqual,
    LessThanOrEqual,
    Equals,
    Comma,
}

impl<'a> fmt::Display for DslToken<'a> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DslToken::Identifier(val) => write!(f, "ID({})", val),
            DslToken::Colon => write!(f, ":"),
            DslToken::StringLiteral(str_val) => write!(f, "\"{}\"", str_val),
            DslToken::NumberLiteral(num) => write!(f, "NUM({})", num),
            DslToken::And => write!(f, "AND"),
            DslToken::Or => write!(f, "OR"),
            DslToken::Not => write!(f, "NOT"),
            DslToken::LeftParen => write!(f, "("),
            DslToken::RightParen => write!(f, ")"),
            DslToken::GreaterThan => write!(f, ">"),
            DslToken::LessThan => write!(f, "<"),
            DslToken::GreaterThanOrEqual => write!(f, ">="),
            DslToken::LessThanOrEqual => write!(f, "<="),
            DslToken::Equals => write!(f, "="),
            DslToken::Comma => write!(f, ","),
        }
    }
}

/// DSL parsing and tokenization error cases.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DslParseError {
    UnexpectedToken {
        expected: &'static str,
        found: Option<String>,
    },
    InvalidSyntax {
        message: &'static str,
        position: usize,
    },
    UnknownField(String),
    InvalidSizeFormat(String),
    InvalidDateFormat(String),
    EmptyQuery,
}

impl fmt::Display for DslParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DslParseError::UnexpectedToken { expected, found } => {
                let token_desc = found.as_deref().unwrap_or("EOF");
                write!(f, "Unexpected token '{}', expected: {}", token_desc, expected)
            }
            DslParseError::InvalidSyntax { message, position } => {
                write!(f, "Syntax error at position {}: {}", position, message)
            }
            DslParseError::UnknownField(name) => write!(f, "Unknown filter field '{}'", name),
            DslParseError::InvalidSizeFormat(val) => write!(f, "Invalid size specification '{}'", val),
            DslParseError::InvalidDateFormat(val) => write!(f, "Invalid date specification '{}'", val),
            DslParseError::EmptyQuery => write!(f, "Empty search query"),
        }
    }
}

impl std::error::Error for DslParseError {}

/// Zero-allocation lexer over a borrowed query string slice.
pub struct DslLexer<'a> {
    input: &'a str,
}

impl<'a> DslLexer<'a> {
    #[inline]
    pub fn new(input: &'a str) -> Self {
        Self { input }
    }

    /// Tokenizes the input string into a list of borrowed tokens.
    pub fn tokenize(&self) -> Result<Vec<DslToken<'a>>, DslParseError> {
        let bytes = self.input.as_bytes();
        let len = bytes.len();
        let mut idx = 0;
        let mut tokens = Vec::new();

        while idx < len {
            let b = bytes[idx];

            // 1. Whitespace skipping
            if b.is_ascii_whitespace() {
                idx += 1;
                continue;
            }

            // 2. Parentheses & punctuation
            if b == b'(' {
                tokens.push(DslToken::LeftParen);
                idx += 1;
                continue;
            }
            if b == b')' {
                tokens.push(DslToken::RightParen);
                idx += 1;
                continue;
            }
            if b == b':' {
                tokens.push(DslToken::Colon);
                idx += 1;
                continue;
            }
            if b == b',' {
                tokens.push(DslToken::Comma);
                idx += 1;
                continue;
            }

            // 3. Comparison operators
            if b == b'>' {
                if idx + 1 < len && bytes[idx + 1] == b'=' {
                    tokens.push(DslToken::GreaterThanOrEqual);
                    idx += 2;
                } else {
                    tokens.push(DslToken::GreaterThan);
                    idx += 1;
                }
                continue;
            }
            if b == b'<' {
                if idx + 1 < len && bytes[idx + 1] == b'=' {
                    tokens.push(DslToken::LessThanOrEqual);
                    idx += 2;
                } else {
                    tokens.push(DslToken::LessThan);
                    idx += 1;
                }
                continue;
            }
            if b == b'=' {
                if idx + 1 < len && bytes[idx + 1] == b'=' {
                    tokens.push(DslToken::Equals);
                    idx += 2;
                } else {
                    tokens.push(DslToken::Equals);
                    idx += 1;
                }
                continue;
            }
            if b == b'!' {
                if idx + 1 < len && bytes[idx + 1] == b'=' {
                    tokens.push(DslToken::Identifier("!="));
                    idx += 2;
                } else {
                    tokens.push(DslToken::Not);
                    idx += 1;
                }
                continue;
            }

            // 4. Logical operators (&& and ||)
            if b == b'&' && idx + 1 < len && bytes[idx + 1] == b'&' {
                tokens.push(DslToken::And);
                idx += 2;
                continue;
            }
            if b == b'|' && idx + 1 < len && bytes[idx + 1] == b'|' {
                tokens.push(DslToken::Or);
                idx += 2;
                continue;
            }

            // 5. String literals (quotes)
            if b == b'"' || b == b'\'' {
                let quote = b;
                let start = idx + 1;
                idx += 1;
                let mut closed = false;

                while idx < len {
                    if bytes[idx] == quote {
                        closed = true;
                        break;
                    }
                    idx += 1;
                }

                if !closed {
                    return Err(DslParseError::InvalidSyntax {
                        message: "Unterminated string literal",
                        position: idx,
                    });
                }

                let literal = &self.input[start..idx];
                tokens.push(DslToken::StringLiteral(literal));
                idx += 1;
                continue;
            }

            // 6. Identifiers, keywords, numbers, or words
            let start = idx;
            while idx < len {
                let c = bytes[idx];
                if c.is_ascii_whitespace()
                    || c == b'('
                    || c == b')'
                    || c == b':'
                    || c == b','
                    || c == b'>'
                    || c == b'<'
                    || c == b'='
                    || c == b'"'
                    || c == b'\''
                {
                    break;
                }
                if c == b'&' && idx + 1 < len && bytes[idx + 1] == b'&' {
                    break;
                }
                if c == b'|' && idx + 1 < len && bytes[idx + 1] == b'|' {
                    break;
                }
                idx += 1;
            }

            if start == idx {
                return Err(DslParseError::InvalidSyntax {
                    message: "Unexpected character",
                    position: start,
                });
            }

            let word = &self.input[start..idx];
            if word.eq_ignore_ascii_case("AND") {
                tokens.push(DslToken::And);
            } else if word.eq_ignore_ascii_case("OR") {
                tokens.push(DslToken::Or);
            } else if word.eq_ignore_ascii_case("NOT") {
                tokens.push(DslToken::Not);
            } else if let Ok(num) = word.parse::<i64>() {
                tokens.push(DslToken::NumberLiteral(num));
            } else {
                tokens.push(DslToken::Identifier(word));
            }
        }

        Ok(tokens)
    }
}
