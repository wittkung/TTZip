// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Helper functions for date civil parsing, size parsing, and string matching.

use globset::{GlobBuilder, GlobMatcher};

use super::models::ComparisonOp;

pub fn build_glob_matcher(pattern: &str) -> Option<GlobMatcher> {
    let pat = if !pattern.contains('*') && !pattern.contains('?') {
        format!("*{}*", pattern)
    } else {
        pattern.to_string()
    };
    GlobBuilder::new(&pat)
        .case_insensitive(true)
        .literal_separator(false)
        .build()
        .map(|g| g.compile_matcher())
        .ok()
}

pub fn parse_size(raw: &str) -> Option<u64> {
    let t = raw.trim();
    if t.is_empty() { return None; }
    let end = t.char_indices()
        .take_while(|(_, c)| c.is_ascii_digit() || *c == '.')
        .map(|(i, c)| i + c.len_utf8())
        .last()
        .unwrap_or(0);
    let (num_str, unit) = (&t[..end], t[end..].trim().to_ascii_uppercase());
    let val: f64 = num_str.parse().ok()?;
    let mult = match unit.as_str() {
        "B" | "" => 1.0,
        "K" | "KB" => 1024.0,
        "M" | "MB" => 1024.0 * 1024.0,
        "G" | "GB" => 1024.0 * 1024.0 * 1024.0,
        "T" | "TB" => 1024.0 * 1024.0 * 1024.0 * 1024.0,
        _ => return None,
    };
    Some((val * mult) as u64)
}

pub fn parse_civil_date(s: &str) -> Option<i64> {
    let parts: Vec<&str> = s.trim().split(['T', ' ']).collect();
    let dsegs: Vec<&str> = parts.first()?.split('-').collect();
    if dsegs.len() != 3 { return None; }
    let y: i64 = dsegs[0].parse().ok()?;
    let m: u32 = dsegs[1].parse().ok()?;
    let d: u32 = dsegs[2].parse().ok()?;
    if !(1..=12).contains(&m) || !(1..=31).contains(&d) { return None; }
    let (mut h, mut min, mut sec) = (0u32, 0u32, 0u32);
    if parts.len() > 1 {
        let tsegs: Vec<&str> = parts[1].trim_end_matches('Z').split(':').collect();
        if !tsegs.is_empty() { h = tsegs[0].parse().ok()?; }
        if tsegs.len() > 1 { min = tsegs[1].parse().ok()?; }
        if tsegs.len() > 2 { sec = tsegs[2].parse().ok()?; }
    }
    let adj_y = y - if m <= 2 { 1 } else { 0 };
    let era = if adj_y >= 0 { adj_y } else { adj_y - 399 } / 400;
    let yoe = (adj_y - era * 400) as u32;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146097 + (doe as i64) - 719468;
    Some(days * 86400 + (h as i64) * 3600 + (min as i64) * 60 + (sec as i64))
}

pub fn parse_date_spec(spec: &str, default_op: ComparisonOp, ref_epoch: i64) -> Option<(i64, ComparisonOp)> {
    let t = spec.trim();
    if t.is_empty() { return None; }
    if let Some(epoch) = parse_civil_date(t) { return Some((epoch, default_op)); }
    let end = t.char_indices()
        .take_while(|(_, c)| c.is_ascii_digit() || *c == '.')
        .map(|(i, c)| i + c.len_utf8())
        .last()
        .unwrap_or(0);
    if end > 0 && end < t.len() {
        if let Ok(val) = t[..end].parse::<f64>() {
            let secs = match t[end..].trim().to_ascii_lowercase().as_str() {
                "s" | "sec" => val,
                "m" | "min" => val * 60.0,
                "h" | "hr" => val * 3600.0,
                "d" | "day" | "days" => val * 86400.0,
                "w" | "week" | "weeks" => val * 7.0 * 86400.0,
                "mth" | "month" | "months" => val * 30.0 * 86400.0,
                "y" | "yr" | "years" => val * 365.0 * 86400.0,
                _ => return None,
            };
            let mapped = match default_op {
                ComparisonOp::LessThan | ComparisonOp::LessThanOrEqual => ComparisonOp::GreaterThanOrEqual,
                ComparisonOp::GreaterThan | ComparisonOp::GreaterThanOrEqual => ComparisonOp::LessThanOrEqual,
                op => op,
            };
            return Some((ref_epoch - (secs as i64), mapped));
        }
    }
    t.parse::<i64>().ok().map(|e| (e, default_op))
}

#[inline]
pub fn extract_extension(path: &str) -> &str {
    let f = path.rsplit('/').next().unwrap_or(path);
    if let Some(dot) = f.rfind('.') {
        if dot > 0 && dot + 1 < f.len() { return &f[dot + 1..]; }
    }
    ""
}

#[inline]
pub fn contains_case_insensitive(haystack: &str, needle: &str) -> bool {
    if needle.is_empty() { return true; }
    if haystack.len() < needle.len() { return false; }
    let (h, n) = (haystack.as_bytes(), needle.as_bytes());
    (0..=h.len() - n.len()).any(|i| (0..n.len()).all(|j| h[i + j].eq_ignore_ascii_case(&n[j])))
}
