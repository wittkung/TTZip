// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Data models, AST expressions, and tokens for Filter DSL.

use globset::GlobMatcher;
use std::fmt;

use super::helpers::{contains_case_insensitive, extract_extension};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ComparisonOp {
    GreaterThan,
    LessThan,
    GreaterThanOrEqual,
    LessThanOrEqual,
    Equals,
    NotEquals,
}

impl ComparisonOp {
    #[inline]
    pub fn compare<T: PartialOrd + Eq>(&self, a: &T, b: &T) -> bool {
        match self {
            Self::GreaterThan => a > b,
            Self::LessThan => a < b,
            Self::GreaterThanOrEqual => a >= b,
            Self::LessThanOrEqual => a <= b,
            Self::Equals => a == b,
            Self::NotEquals => a != b,
        }
    }

    pub fn symbol(&self) -> &'static str {
        match self {
            Self::GreaterThan => ">",
            Self::LessThan => "<",
            Self::GreaterThanOrEqual => ">=",
            Self::LessThanOrEqual => "<=",
            Self::Equals => "=",
            Self::NotEquals => "!=",
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct FilterTarget<'a> {
    pub path: &'a str,
    pub name: &'a str,
    pub uncompressed_size: u64,
    pub mtime_epoch_secs: i64,
}

impl<'a> FilterTarget<'a> {
    #[inline]
    pub fn new(path: &'a str, uncompressed_size: u64, mtime_epoch_secs: i64) -> Self {
        let name = path.rsplit('/').next().unwrap_or(path);
        Self { path, name, uncompressed_size, mtime_epoch_secs }
    }
}

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
    NotEquals,
    Comma,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DslParseError {
    UnexpectedToken { expected: &'static str, found: Option<String> },
    InvalidSyntax { message: &'static str, position: usize },
    InvalidSizeFormat(String),
    InvalidDateFormat(String),
}

impl fmt::Display for DslParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnexpectedToken { expected, found } => {
                write!(f, "Unexpected token '{}', expected: {}", found.as_deref().unwrap_or("EOF"), expected)
            }
            Self::InvalidSyntax { message, position } => write!(f, "Syntax error at {}: {}", position, message),
            Self::InvalidSizeFormat(val) => write!(f, "Invalid size specifier '{}'", val),
            Self::InvalidDateFormat(val) => write!(f, "Invalid date specifier '{}'", val),
        }
    }
}

impl std::error::Error for DslParseError {}

#[derive(Debug, Clone)]
pub enum FilterExpr<'a> {
    MatchAll,
    MatchNone,
    FilenameGlob { pattern: &'a str, matcher: Option<GlobMatcher> },
    Extension { raw: &'a str, extensions: Vec<&'a str> },
    Size { target_bytes: u64, op: ComparisonOp },
    Modified { target_epoch_secs: i64, op: ComparisonOp },
    And(Box<FilterExpr<'a>>, Box<FilterExpr<'a>>),
    Or(Box<FilterExpr<'a>>, Box<FilterExpr<'a>>),
    Not(Box<FilterExpr<'a>>),
}

impl<'a> FilterExpr<'a> {
    #[inline]
    pub fn evaluate(&self, target: &FilterTarget) -> bool {
        match self {
            Self::MatchAll => true,
            Self::MatchNone => false,
            Self::FilenameGlob { pattern, matcher } => {
                if let Some(ref m) = matcher {
                    m.is_match(target.name) || m.is_match(target.path)
                } else {
                    contains_case_insensitive(target.name, pattern) || contains_case_insensitive(target.path, pattern)
                }
            }
            Self::Extension { extensions, .. } => {
                if extensions.is_empty() { return true; }
                let ext = extract_extension(target.name);
                let path_ext = extract_extension(target.path);
                extensions.iter().any(|&e| {
                    let clean = e.strip_prefix('.').unwrap_or(e);
                    clean.eq_ignore_ascii_case(ext) || clean.eq_ignore_ascii_case(path_ext)
                })
            }
            Self::Size { target_bytes, op } => op.compare(&target.uncompressed_size, target_bytes),
            Self::Modified { target_epoch_secs, op } => op.compare(&target.mtime_epoch_secs, target_epoch_secs),
            Self::And(l, r) => l.evaluate(target) && r.evaluate(target),
            Self::Or(l, r) => l.evaluate(target) || r.evaluate(target),
            Self::Not(op) => !op.evaluate(target),
        }
    }

    #[inline]
    pub fn evaluate_metadata(&self, path: &str, size: u64, mtime: i64) -> bool {
        self.evaluate(&FilterTarget::new(path, size, mtime))
    }

    pub fn dsl_description(&self) -> String {
        match self {
            Self::MatchAll => "[MATCH_ALL]".into(),
            Self::MatchNone => "[MATCH_NONE]".into(),
            Self::FilenameGlob { pattern, .. } => format!("name:{}", pattern),
            Self::Extension { raw, .. } => format!("ext:{}", raw),
            Self::Size { target_bytes, op } => format!("size:{}{}", op.symbol(), target_bytes),
            Self::Modified { target_epoch_secs, op } => format!("modified:{}{}", op.symbol(), target_epoch_secs),
            Self::And(l, r) => format!("({} AND {})", l.dsl_description(), r.dsl_description()),
            Self::Or(l, r) => format!("({} OR {})", l.dsl_description(), r.dsl_description()),
            Self::Not(op) => format!("NOT ({})", op.dsl_description()),
        }
    }
}
