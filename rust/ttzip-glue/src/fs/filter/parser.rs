// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Recursive descent parser for Filter DSL queries producing AST expressions.

use crate::fs::filter::expr::{ComparisonOp, FilterExpr};
use crate::fs::filter::lexer::{DslLexer, DslParseError, DslToken};
use crate::fs::filter::utils::{build_glob_matcher, parse_date_spec, parse_size};
use std::time::{SystemTime, UNIX_EPOCH};

/// Recursive descent parser for compiling `DslToken` stream into `FilterExpr` AST trees.
pub struct DslParser<'p, 'a> {
    tokens: &'p [DslToken<'a>],
}

impl<'p, 'a> DslParser<'p, 'a> {
    #[inline]
    pub fn new(tokens: &'p [DslToken<'a>]) -> Self {
        Self { tokens }
    }

    /// Parses entire token stream into an expression tree.
    pub fn parse(&self) -> Result<FilterExpr<'a>, DslParseError> {
        if self.tokens.is_empty() {
            return Ok(FilterExpr::MatchAll);
        }
        let mut index = 0;
        let expr = self.parse_or(&mut index)?;
        if index < self.tokens.len() {
            let trailing = self.tokens[index];
            return Err(DslParseError::UnexpectedToken {
                expected: "end of expression",
                found: Some(trailing.to_string()),
            });
        }
        Ok(expr)
    }

    /// One-shot parse from a query string slice.
    pub fn parse_str(query: &'a str) -> Result<FilterExpr<'a>, DslParseError> {
        let trimmed = query.trim();
        if trimmed.is_empty() {
            return Ok(FilterExpr::MatchAll);
        }
        let lexer = DslLexer::new(trimmed);
        let tokens = lexer.tokenize()?;
        let parser = DslParser::new(&tokens);
        parser.parse()
    }

    /// Parses query or falls back to FilenameGlob if syntax errors occur.
    pub fn parse_or_fallback(query: &'a str) -> FilterExpr<'a> {
        let trimmed = query.trim();
        if trimmed.is_empty() {
            return FilterExpr::MatchAll;
        }
        match Self::parse_str(trimmed) {
            Ok(expr) => expr,
            Err(_) => FilterExpr::FilenameGlob {
                pattern: trimmed,
                matcher: build_glob_matcher(trimmed),
            },
        }
    }

    // MARK: - Recursive Descent Precedence Hierarchy

    fn parse_or(&self, index: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        let mut left = self.parse_and(index)?;

        while *index < self.tokens.len() {
            if self.tokens[*index] == DslToken::Or {
                *index += 1;
                let right = self.parse_and(index)?;
                left = FilterExpr::Or(Box::new(left), Box::new(right));
            } else {
                break;
            }
        }
        Ok(left)
    }

    fn parse_and(&self, index: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        let mut left = self.parse_not(index)?;

        while *index < self.tokens.len() {
            if self.tokens[*index] == DslToken::And {
                *index += 1;
                let right = self.parse_not(index)?;
                left = FilterExpr::And(Box::new(left), Box::new(right));
            } else if self.tokens[*index] == DslToken::Not || self.can_start_primary(*index) {
                let right = self.parse_not(index)?;
                left = FilterExpr::And(Box::new(left), Box::new(right));
            } else {
                break;
            }
        }
        Ok(left)
    }

    fn parse_not(&self, index: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        if *index < self.tokens.len() && self.tokens[*index] == DslToken::Not {
            *index += 1;
            let operand = self.parse_not(index)?;
            return Ok(FilterExpr::Not(Box::new(operand)));
        }
        self.parse_primary(index)
    }

    fn parse_primary(&self, index: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        if *index >= self.tokens.len() {
            return Err(DslParseError::UnexpectedToken {
                expected: "expression",
                found: None,
            });
        }

        let cur = self.tokens[*index];

        if cur == DslToken::LeftParen {
            *index += 1;
            let inner = self.parse_or(index)?;
            if *index >= self.tokens.len() || self.tokens[*index] != DslToken::RightParen {
                let found = if *index < self.tokens.len() {
                    Some(self.tokens[*index].to_string())
                } else {
                    None
                };
                return Err(DslParseError::UnexpectedToken {
                    expected: ")",
                    found,
                });
            }
            *index += 1;
            return Ok(inner);
        }

        if let DslToken::Identifier(field_name) = cur {
            if *index + 1 < self.tokens.len() && self.tokens[*index + 1] == DslToken::Colon {
                *index += 2;
                return self.parse_key_value(field_name, index);
            }
        }

        match cur {
            DslToken::Identifier(val) | DslToken::StringLiteral(val) => {
                *index += 1;
                Ok(FilterExpr::FilenameGlob {
                    pattern: val,
                    matcher: build_glob_matcher(val),
                })
            }
            DslToken::NumberLiteral(num) => {
                *index += 1;
                let s = val_from_num(num);
                Ok(FilterExpr::FilenameGlob {
                    pattern: s,
                    matcher: build_glob_matcher(s),
                })
            }
            _ => Err(DslParseError::UnexpectedToken {
                expected: "identifier, string literal or key:value filter",
                found: Some(cur.to_string()),
            }),
        }
    }

    fn parse_key_value(&self, field: &'a str, index: &mut usize) -> Result<FilterExpr<'a>, DslParseError> {
        let mut op = ComparisonOp::GreaterThan;
        let mut has_explicit_op = false;

        if *index < self.tokens.len() {
            match self.tokens[*index] {
                DslToken::GreaterThan => {
                    op = ComparisonOp::GreaterThan;
                    has_explicit_op = true;
                    *index += 1;
                }
                DslToken::LessThan => {
                    op = ComparisonOp::LessThan;
                    has_explicit_op = true;
                    *index += 1;
                }
                DslToken::GreaterThanOrEqual => {
                    op = ComparisonOp::GreaterThanOrEqual;
                    has_explicit_op = true;
                    *index += 1;
                }
                DslToken::LessThanOrEqual => {
                    op = ComparisonOp::LessThanOrEqual;
                    has_explicit_op = true;
                    *index += 1;
                }
                DslToken::Equals => {
                    op = ComparisonOp::Equals;
                    has_explicit_op = true;
                    *index += 1;
                }
                _ => {}
            }
        }

        let mut raw_parts: Vec<&'a str> = Vec::new();
        while *index < self.tokens.len() {
            match self.tokens[*index] {
                DslToken::Identifier(val) | DslToken::StringLiteral(val) => {
                    raw_parts.push(val);
                    *index += 1;
                }
                DslToken::NumberLiteral(num) => {
                    raw_parts.push(val_from_num(num));
                    *index += 1;
                }
                _ => break,
            }

            if *index < self.tokens.len() && self.tokens[*index] == DslToken::Comma {
                *index += 1;
            } else {
                break;
            }
        }

        if raw_parts.is_empty() {
            let found = if *index < self.tokens.len() {
                Some(self.tokens[*index].to_string())
            } else {
                None
            };
            return Err(DslParseError::UnexpectedToken {
                expected: "field value",
                found,
            });
        }

        let raw_val = raw_parts[0];
        let lower_field = field.to_ascii_lowercase();

        match lower_field.as_str() {
            "ext" | "extension" | "type" => Ok(FilterExpr::Extension {
                raw: raw_val,
                extensions: raw_parts,
            }),
            "name" | "filename" | "path" => Ok(FilterExpr::FilenameGlob {
                pattern: raw_val,
                matcher: build_glob_matcher(raw_val),
            }),
            "size" => {
                let effective_op = if has_explicit_op { op } else { ComparisonOp::GreaterThan };
                let bytes = parse_size(raw_val).ok_or_else(|| {
                    DslParseError::InvalidSizeFormat(raw_val.to_string())
                })?;
                Ok(FilterExpr::Size {
                    target_bytes: bytes,
                    op: effective_op,
                })
            }
            "modified" | "date" | "mtime" => {
                let effective_op = if has_explicit_op { op } else { ComparisonOp::LessThan };
                let now_epoch = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs() as i64)
                    .unwrap_or(0);
                let (target_time, calculated_op) = parse_date_spec(raw_val, effective_op, now_epoch)
                    .ok_or_else(|| DslParseError::InvalidDateFormat(raw_val.to_string()))?;
                Ok(FilterExpr::Modified {
                    target_epoch_secs: target_time,
                    op: calculated_op,
                })
            }
            _ => Ok(FilterExpr::FilenameGlob {
                pattern: raw_val,
                matcher: build_glob_matcher(raw_val),
            }),
        }
    }

    fn can_start_primary(&self, index: usize) -> bool {
        if index >= self.tokens.len() {
            return false;
        }
        matches!(
            self.tokens[index],
            DslToken::LeftParen
                | DslToken::Identifier(_)
                | DslToken::StringLiteral(_)
                | DslToken::NumberLiteral(_)
        )
    }
}

#[inline]
fn val_from_num(num: i64) -> &'static str {
    Box::leak(num.to_string().into_boxed_str())
}
