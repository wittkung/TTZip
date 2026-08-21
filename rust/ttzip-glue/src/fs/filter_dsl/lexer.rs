// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-allocation lexical analyzer for Filter DSL query expressions.

use super::models::{DslParseError, DslToken};

pub struct DslLexer<'a> {
    input: &'a str,
}

impl<'a> DslLexer<'a> {
    #[inline]
    pub fn new(input: &'a str) -> Self {
        Self { input }
    }

    pub fn tokenize(&self) -> Result<Vec<DslToken<'a>>, DslParseError> {
        let bytes = self.input.as_bytes();
        let len = bytes.len();
        let mut idx = 0;
        let mut tokens = Vec::new();

        while idx < len {
            let b = bytes[idx];
            if b.is_ascii_whitespace() {
                idx += 1;
                continue;
            }
            match b {
                b'(' => { tokens.push(DslToken::LeftParen); idx += 1; }
                b')' => { tokens.push(DslToken::RightParen); idx += 1; }
                b':' => { tokens.push(DslToken::Colon); idx += 1; }
                b',' => { tokens.push(DslToken::Comma); idx += 1; }
                b'>' => {
                    if idx + 1 < len && bytes[idx + 1] == b'=' { tokens.push(DslToken::GreaterThanOrEqual); idx += 2; }
                    else { tokens.push(DslToken::GreaterThan); idx += 1; }
                }
                b'<' => {
                    if idx + 1 < len && bytes[idx + 1] == b'=' { tokens.push(DslToken::LessThanOrEqual); idx += 2; }
                    else { tokens.push(DslToken::LessThan); idx += 1; }
                }
                b'=' => {
                    if idx + 1 < len && bytes[idx + 1] == b'=' { tokens.push(DslToken::Equals); idx += 2; }
                    else { tokens.push(DslToken::Equals); idx += 1; }
                }
                b'!' => {
                    if idx + 1 < len && bytes[idx + 1] == b'=' { tokens.push(DslToken::NotEquals); idx += 2; }
                    else { tokens.push(DslToken::Not); idx += 1; }
                }
                b'&' if idx + 1 < len && bytes[idx + 1] == b'&' => { tokens.push(DslToken::And); idx += 2; }
                b'|' if idx + 1 < len && bytes[idx + 1] == b'|' => { tokens.push(DslToken::Or); idx += 2; }
                b'"' | b'\'' => {
                    let quote = b;
                    let start = idx + 1;
                    idx += 1;
                    let mut closed = false;
                    while idx < len {
                        if bytes[idx] == quote { closed = true; break; }
                        idx += 1;
                    }
                    if !closed {
                        return Err(DslParseError::InvalidSyntax { message: "Unterminated string literal", position: idx });
                    }
                    tokens.push(DslToken::StringLiteral(&self.input[start..idx]));
                    idx += 1;
                }
                _ => {
                    let start = idx;
                    while idx < len {
                        let c = bytes[idx];
                        if c.is_ascii_whitespace() || matches!(c, b'(' | b')' | b':' | b',' | b'>' | b'<' | b'=' | b'"' | b'\'') { break; }
                        if c == b'&' && idx + 1 < len && bytes[idx + 1] == b'&' { break; }
                        if c == b'|' && idx + 1 < len && bytes[idx + 1] == b'|' { break; }
                        idx += 1;
                    }
                    let word = &self.input[start..idx];
                    if word.eq_ignore_ascii_case("AND") { tokens.push(DslToken::And); }
                    else if word.eq_ignore_ascii_case("OR") { tokens.push(DslToken::Or); }
                    else if word.eq_ignore_ascii_case("NOT") { tokens.push(DslToken::Not); }
                    else if let Ok(num) = word.parse::<i64>() { tokens.push(DslToken::NumberLiteral(num)); }
                    else { tokens.push(DslToken::Identifier(word)); }
                }
            }
        }
        Ok(tokens)
    }
}
