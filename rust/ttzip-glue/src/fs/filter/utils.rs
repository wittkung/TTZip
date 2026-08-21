// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Utility parsers for human-readable size, duration specs, and glob matchers.

use crate::fs::filter::expr::ComparisonOp;
use globset::{GlobBuilder, GlobMatcher};

/// Compiles a GlobMatcher from pattern with case-insensitivity.
pub fn build_glob_matcher(pattern: &str) -> Option<GlobMatcher> {
    let glob_str = if !pattern.contains('*') && !pattern.contains('?') {
        format!("*{}*", pattern)
    } else {
        pattern.to_string()
    };

    GlobBuilder::new(&glob_str)
        .case_insensitive(true)
        .literal_separator(false)
        .build()
        .map(|g| g.compile_matcher())
        .ok()
}

/// Parses human-readable size specifier into byte count.
pub fn parse_size(raw: &str) -> Option<u64> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }

    let mut num_end = 0;
    for (i, c) in trimmed.char_indices() {
        if c.is_ascii_digit() || c == '.' {
            num_end = i + c.len_utf8();
        } else {
            break;
        }
    }

    let num_str = &trimmed[..num_end];
    let unit_str = trimmed[num_end..].trim().to_ascii_uppercase();
    let val: f64 = num_str.parse().ok()?;

    let multiplier: f64 = match unit_str.as_str() {
        "B" | "" => 1.0,
        "K" | "KB" => 1024.0,
        "M" | "MB" => 1024.0 * 1024.0,
        "G" | "GB" => 1024.0 * 1024.0 * 1024.0,
        "T" | "TB" => 1024.0 * 1024.0 * 1024.0 * 1024.0,
        _ => return None,
    };

    Some((val * multiplier) as u64)
}

/// Parses duration/date specifier into epoch timestamp and adjusted comparison operator.
pub fn parse_date_spec(
    spec: &str,
    default_op: ComparisonOp,
    ref_epoch_secs: i64,
) -> Option<(i64, ComparisonOp)> {
    let trimmed = spec.trim();
    if trimmed.is_empty() {
        return None;
    }

    let mut num_end = 0;
    for (i, c) in trimmed.char_indices() {
        if c.is_ascii_digit() || c == '.' {
            num_end = i + c.len_utf8();
        } else {
            break;
        }
    }

    if num_end > 0 && num_end < trimmed.len() {
        let num_str = &trimmed[..num_end];
        let unit_str = trimmed[num_end..].trim().to_ascii_lowercase();
        if let Ok(val) = num_str.parse::<f64>() {
            let seconds: f64 = match unit_str.as_str() {
                "s" | "sec" => val,
                "m" | "min" => val * 60.0,
                "h" | "hr" => val * 3600.0,
                "d" | "day" | "days" => val * 86400.0,
                "w" | "week" | "weeks" => val * 7.0 * 86400.0,
                "mth" | "month" | "months" => val * 30.0 * 86400.0,
                "y" | "yr" | "years" => val * 365.0 * 86400.0,
                _ => return None,
            };

            let target_time = ref_epoch_secs - (seconds as i64);
            let mapped_op = match default_op {
                ComparisonOp::LessThan | ComparisonOp::LessThanOrEqual => {
                    ComparisonOp::GreaterThanOrEqual
                }
                ComparisonOp::GreaterThan | ComparisonOp::GreaterThanOrEqual => {
                    ComparisonOp::LessThanOrEqual
                }
                ComparisonOp::Equals => ComparisonOp::Equals,
                ComparisonOp::NotEquals => ComparisonOp::NotEquals,
            };
            return Some((target_time, mapped_op));
        }
    }

    if let Ok(epoch) = trimmed.parse::<i64>() {
        return Some((epoch, default_op));
    }

    None
}
