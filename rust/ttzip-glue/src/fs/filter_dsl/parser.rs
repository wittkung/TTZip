// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Recursive descent parser for Filter DSL constructing `FilterExpr` AST trees.

use std::time::{SystemTime, UNIX_EPOCH};

use super::helpers::{build_glob_matcher, parse_date_spec, parse_size};
use super::lexer::DslLexer;
use super::models::{ComparisonOp, DslParseError, DslToken, FilterExpr};

pub struct DslParser<'p, 'a> {
    tokens: &'p [DslToken<'a>],
}

impl<'p, 'a> DslParser<'p, 'a> {
    #[inline]
    pub fn new(tokens: &'p [DslToken<'a>]) -> Self {
        Self { tokens }
    }

    pub fn parse(&self) -> Result<FilterExpr<'a>, DslParseError> {
        if self.tokens.is_empty() {
            return Ok(FilterExpr::MatchAll);
        }
        let mut idx = 0;
        let expr = self.parse_or(&mut idx)?;
        if idx < self.tokens.len() {
            return Err(DslParseError::UnexpectedToken {
                expected: "end of expression",
                found: Some(format!("{:?}", self.tokens[idx])),
            });
        }
        Ok(expr)
    }

    pub fn parse_str(query: &'a str) -> Result<FilterExpr<'a>, DslParseError> {
        let trimmed = query.trim();
        if trimmed.is_empty() {
            return Ok(FilterExpr::MatchAll);
        }
        let lexer = DslLexer::new(trimmed);
        let tokens = lexer.tokenize()?;
        DslParser::new(&tokens).parse()
    }

    pub fn parse_or_fallback(query: &'a str) -> FilterExpr<'a> {
        let trimmed = query.trim();
        if trimmed.is_empty() {
            return FilterExpr::MatchAll;
        }
        Self::parse_str(trimmed).unwrap_or_else(|_| FilterExpr::FilenameGlob {
            pattern: trimmed,
            matcher: build_glob_matcher(trimmed),
        })
    }

    fn parse_or(&self, idx: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        let mut left = self.parse_and(idx)?;
        while *idx < self.tokens.len() && self.tokens[*idx] == DslToken::Or {
            *idx += 1;
            let right = self.parse_and(idx)?;
            left = FilterExpr::Or(Box::new(left), Box::new(right));
        }
        Ok(left)
    }

    fn parse_and(&self, idx: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        let mut left = self.parse_not(idx)?;
        while *idx < self.tokens.len() {
            if self.tokens[*idx] == DslToken::And {
                *idx += 1;
                let right = self.parse_not(idx)?;
                left = FilterExpr::And(Box::new(left), Box::new(right));
            } else if self.tokens[*idx] == DslToken::Not || self.can_start_primary(*idx) {
                let right = self.parse_not(idx)?;
                left = FilterExpr::And(Box::new(left), Box::new(right));
            } else {
                break;
            }
        }
        Ok(left)
    }

    fn parse_not(&self, idx: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        if *idx < self.tokens.len() && self.tokens[*idx] == DslToken::Not {
            *idx += 1;
            let op = self.parse_not(idx)?;
            return Ok(FilterExpr::Not(Box::new(op)));
        }
        self.parse_primary(idx)
    }

    fn parse_primary(&self, idx: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        if *idx >= self.tokens.len() {
            return Err(DslParseError::UnexpectedToken { expected: "expression", found: None });
        }
        let cur = self.tokens[*idx];
        if cur == DslToken::LeftParen {
            *idx += 1;
            let inner = self.parse_or(idx)?;
            if *idx >= self.tokens.len() || self.tokens[*idx] != DslToken::RightParen {
                return Err(DslParseError::UnexpectedToken {
                    expected: ")",
                    found: self.tokens.get(*idx).map(|t| format!("{:?}", t)),
                });
            }
            *idx += 1;
            return Ok(inner);
        }
        if let DslToken::Identifier(field) = cur {
            if *idx + 1 < self.tokens.len() {
                let next = self.tokens[*idx + 1];
                if next == DslToken::Colon || is_comp_op(next) {
                    *idx += 1;
                    return self.parse_field_expr(field, idx);
                }
            }
        }
        match cur {
            DslToken::Identifier(val) | DslToken::StringLiteral(val) => {
                *idx += 1;
                Ok(FilterExpr::FilenameGlob { pattern: val, matcher: build_glob_matcher(val) })
            }
            DslToken::NumberLiteral(num) => {
                *idx += 1;
                let s = Box::leak(num.to_string().into_boxed_str());
                Ok(FilterExpr::FilenameGlob { pattern: s, matcher: build_glob_matcher(s) })
            }
            _ => Err(DslParseError::UnexpectedToken {
                expected: "filter term",
                found: Some(format!("{:?}", cur)),
            }),
        }
    }

    fn parse_field_expr(&self, field: &'a str, idx: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        let mut op = ComparisonOp::GreaterThan;
        let mut has_explicit_op = false;
        if *idx < self.tokens.len() && self.tokens[*idx] == DslToken::Colon {
            *idx += 1;
        }
        if *idx < self.tokens.len() {
            if let Some(parsed_op) = token_to_comp_op(self.tokens[*idx]) {
                op = parsed_op;
                has_explicit_op = true;
                *idx += 1;
            }
        }
        let mut parts = Vec::new();
        while *idx < self.tokens.len() {
            match self.tokens[*idx] {
                DslToken::Identifier(val) | DslToken::StringLiteral(val) => {
                    parts.push(val);
                    *idx += 1;
                }
                DslToken::NumberLiteral(num) => {
                    parts.push(Box::leak(num.to_string().into_boxed_str()) as &'a str);
                    *idx += 1;
                }
                _ => break,
            }
            if *idx < self.tokens.len() && self.tokens[*idx] == DslToken::Comma {
                *idx += 1;
            } else {
                break;
            }
        }
        if parts.is_empty() {
            return Err(DslParseError::UnexpectedToken {
                expected: "field value",
                found: self.tokens.get(*idx).map(|t| format!("{:?}", t)),
            });
        }
        let raw = parts[0];
        match field.to_ascii_lowercase().as_str() {
            "ext" | "extension" | "type" => {
                let expr = FilterExpr::Extension { raw, extensions: parts };
                if op == ComparisonOp::NotEquals { Ok(FilterExpr::Not(Box::new(expr))) } else { Ok(expr) }
            }
            "name" | "filename" | "path" => {
                let expr = FilterExpr::FilenameGlob { pattern: raw, matcher: build_glob_matcher(raw) };
                if op == ComparisonOp::NotEquals { Ok(FilterExpr::Not(Box::new(expr))) } else { Ok(expr) }
            }
            "size" => {
                let eff_op = if has_explicit_op { op } else { ComparisonOp::GreaterThan };
                let bytes = parse_size(raw).ok_or_else(|| DslParseError::InvalidSizeFormat(raw.to_string()))?;
                Ok(FilterExpr::Size { target_bytes: bytes, op: eff_op })
            }
            "date" | "modified" | "mtime" => {
                let eff_op = if has_explicit_op { op } else { ComparisonOp::LessThan };
                let now = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0);
                let (target_time, calc_op) = parse_date_spec(raw, eff_op, now)
                    .ok_or_else(|| DslParseError::InvalidDateFormat(raw.to_string()))?;
                Ok(FilterExpr::Modified { target_epoch_secs: target_time, op: calc_op })
            }
            _ => Ok(FilterExpr::FilenameGlob { pattern: raw, matcher: build_glob_matcher(raw) }),
        }
    }

    fn can_start_primary(&self, idx: usize) -> bool {
        idx < self.tokens.len() && matches!(
            self.tokens[idx],
            DslToken::LeftParen | DslToken::Identifier(_) | DslToken::StringLiteral(_) | DslToken::NumberLiteral(_)
        )
    }
}

#[inline]
fn is_comp_op(token: DslToken<'_>) -> bool {
    token_to_comp_op(token).is_some()
}

#[inline]
fn token_to_comp_op(token: DslToken<'_>) -> Option<ComparisonOp> {
    match token {
        DslToken::GreaterThan => Some(ComparisonOp::GreaterThan),
        DslToken::LessThan => Some(ComparisonOp::LessThan),
        DslToken::GreaterThanOrEqual => Some(ComparisonOp::GreaterThanOrEqual),
        DslToken::LessThanOrEqual => Some(ComparisonOp::LessThanOrEqual),
        DslToken::Equals => Some(ComparisonOp::Equals),
        DslToken::NotEquals => Some(ComparisonOp::NotEquals),
        _ => None,
    }
}
