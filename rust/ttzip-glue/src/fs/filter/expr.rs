// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Filter expression AST representation and zero-allocation evaluation engine.

use globset::GlobMatcher;

/// Comparison operators for numerical and temporal filter evaluations.
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
            ComparisonOp::GreaterThan => a > b,
            ComparisonOp::LessThan => a < b,
            ComparisonOp::GreaterThanOrEqual => a >= b,
            ComparisonOp::LessThanOrEqual => a <= b,
            ComparisonOp::Equals => a == b,
            ComparisonOp::NotEquals => a != b,
        }
    }

    pub fn symbol(&self) -> &'static str {
        match self {
            ComparisonOp::GreaterThan => ">",
            ComparisonOp::LessThan => "<",
            ComparisonOp::GreaterThanOrEqual => ">=",
            ComparisonOp::LessThanOrEqual => "<=",
            ComparisonOp::Equals => "=",
            ComparisonOp::NotEquals => "!=",
        }
    }
}

/// Borrowed archive entry evaluation target for zero-heap-allocation filtering.
#[derive(Debug, Clone, Copy)]
pub struct FilterTarget<'a> {
    pub path: &'a str,
    pub name: &'a str,
    pub uncompressed_size: u64,
    pub mtime_epoch_secs: i64,
}

impl<'a> FilterTarget<'a> {
    #[inline]
    pub fn from_path(path: &'a str) -> Self {
        let name = path.rsplit('/').next().unwrap_or(path);
        Self {
            path,
            name,
            uncompressed_size: 0,
            mtime_epoch_secs: 0,
        }
    }

    #[inline]
    pub fn new(path: &'a str, uncompressed_size: u64, mtime_epoch_secs: i64) -> Self {
        let name = path.rsplit('/').next().unwrap_or(path);
        Self {
            path,
            name,
            uncompressed_size,
            mtime_epoch_secs,
        }
    }
}

/// AST expression representation with zero-allocation evaluation.
#[derive(Debug, Clone)]
pub enum FilterExpr<'a> {
    MatchAll,
    MatchNone,
    FilenameGlob {
        pattern: &'a str,
        matcher: Option<GlobMatcher>,
    },
    Extension {
        raw: &'a str,
        extensions: Vec<&'a str>,
    },
    Size {
        target_bytes: u64,
        op: ComparisonOp,
    },
    Modified {
        target_epoch_secs: i64,
        op: ComparisonOp,
    },
    And(Box<FilterExpr<'a>>, Box<FilterExpr<'a>>),
    Or(Box<FilterExpr<'a>>, Box<FilterExpr<'a>>),
    Not(Box<FilterExpr<'a>>),
}

impl<'a> FilterExpr<'a> {
    /// Evaluates the expression against target metadata with ZERO heap allocations.
    #[inline]
    pub fn evaluate(&self, target: &FilterTarget) -> bool {
        match self {
            FilterExpr::MatchAll => true,
            FilterExpr::MatchNone => false,
            FilterExpr::FilenameGlob { pattern, matcher } => {
                if let Some(ref m) = matcher {
                    m.is_match(target.name) || m.is_match(target.path)
                } else {
                    contains_case_insensitive(target.name, pattern)
                        || contains_case_insensitive(target.path, pattern)
                }
            }
            FilterExpr::Extension { extensions, .. } => {
                if extensions.is_empty() {
                    return true;
                }
                let ext = extract_extension(target.name);
                let path_ext = extract_extension(target.path);
                extensions.iter().any(|&e| {
                    let clean_e = e.strip_prefix('.').unwrap_or(e);
                    clean_e.eq_ignore_ascii_case(ext) || clean_e.eq_ignore_ascii_case(path_ext)
                })
            }
            FilterExpr::Size { target_bytes, op } => {
                op.compare(&target.uncompressed_size, target_bytes)
            }
            FilterExpr::Modified {
                target_epoch_secs,
                op,
            } => op.compare(&target.mtime_epoch_secs, target_epoch_secs),
            FilterExpr::And(left, right) => {
                left.evaluate(target) && right.evaluate(target)
            }
            FilterExpr::Or(left, right) => {
                left.evaluate(target) || right.evaluate(target)
            }
            FilterExpr::Not(operand) => !operand.evaluate(target),
        }
    }

    /// Evaluates directly against basic metadata parameters.
    #[inline]
    pub fn evaluate_metadata(&self, path: &str, size: u64, mtime: i64) -> bool {
        let target = FilterTarget::new(path, size, mtime);
        self.evaluate(&target)
    }

    /// Human-readable DSL description of the filter expression tree.
    pub fn dsl_description(&self) -> String {
        match self {
            FilterExpr::MatchAll => "[MATCH_ALL]".to_string(),
            FilterExpr::MatchNone => "[MATCH_NONE]".to_string(),
            FilterExpr::FilenameGlob { pattern, .. } => format!("name:{}", pattern),
            FilterExpr::Extension { raw, .. } => format!("ext:{}", raw),
            FilterExpr::Size { target_bytes, op } => {
                format!("size:{}{}", op.symbol(), target_bytes)
            }
            FilterExpr::Modified {
                target_epoch_secs,
                op,
            } => format!("modified:{}{}", op.symbol(), target_epoch_secs),
            FilterExpr::And(left, right) => {
                format!("({} AND {})", left.dsl_description(), right.dsl_description())
            }
            FilterExpr::Or(left, right) => {
                format!("({} OR {})", left.dsl_description(), right.dsl_description())
            }
            FilterExpr::Not(operand) => format!("NOT ({})", operand.dsl_description()),
        }
    }
}

/// Zero-allocation extension extraction from a filename or path slice.
#[inline]
pub fn extract_extension(path: &str) -> &str {
    let filename = path.rsplit('/').next().unwrap_or(path);
    if let Some(dot_idx) = filename.rfind('.') {
        if dot_idx > 0 && dot_idx + 1 < filename.len() {
            return &filename[dot_idx + 1..];
        }
    }
    ""
}

/// Zero-allocation case-insensitive ASCII substring search.
#[inline]
pub fn contains_case_insensitive(haystack: &str, needle: &str) -> bool {
    if needle.is_empty() {
        return true;
    }
    if haystack.len() < needle.len() {
        return false;
    }
    let n_bytes = needle.as_bytes();
    let h_bytes = haystack.as_bytes();
    let n_len = n_bytes.len();
    let limit = h_bytes.len() - n_len;

    for i in 0..=limit {
        let mut matched = true;
        for j in 0..n_len {
            if !h_bytes[i + j].eq_ignore_ascii_case(&n_bytes[j]) {
                matched = false;
                break;
            }
        }
        if matched {
            return true;
        }
    }
    false
}
