// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for SIMD Shannon Entropy Evaluation and Cascaded Codec Recommendation.

use std::os::raw::c_char;
use std::panic::catch_unwind;
use std::slice;

use crate::analytics::codec_selector::{CascadedCodecSelector, Scenario};
use crate::analytics::entropy::{
    compute_shannon_entropy, compute_shannon_entropy_strided,
    should_bypass_compression as should_bypass_compression_impl,
};
use crate::types::TTZipStatus;

/// Target compression scenario profile for C-ABI.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TTZipSelectorScenario {
    InstantTransfer = 0,
    BalancedDaily = 1,
    ColdStorage = 2,
}

impl From<TTZipSelectorScenario> for Scenario {
    fn from(s: TTZipSelectorScenario) -> Self {
        match s {
            TTZipSelectorScenario::InstantTransfer => Scenario::InstantTransfer,
            TTZipSelectorScenario::BalancedDaily => Scenario::BalancedDaily,
            TTZipSelectorScenario::ColdStorage => Scenario::ColdStorage,
        }
    }
}

/// Standardized C-ABI representation of recommendation result.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct TTZipRecommendationResult {
    pub scenario: i32,
    pub measured_entropy: f64,
    pub trial_compressibility_ratio: f64,
    pub recommended_algorithm: [c_char; 32],
    pub recommended_level: i32,
    pub rationale: [c_char; 512],
    pub projected_throughput_mbs: f64,
    pub projected_space_savings_pct: f64,
    pub probe_duration_ms: f64,
}

fn copy_str_to_c_buffer(src: &str, dst: &mut [c_char]) {
    let bytes = src.as_bytes();
    let max_len = dst.len().saturating_sub(1);
    let copy_len = bytes.len().min(max_len);
    for i in 0..copy_len {
        dst[i] = bytes[i] as c_char;
    }
    dst[copy_len] = 0;
}

/// Computes Shannon entropy ($0.0 \dots 8.0$) for a memory buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_estimate_entropy(buf: *const u8, len: usize) -> f64 {
    if buf.is_null() || len == 0 {
        return 0.0;
    }
    let result = catch_unwind(|| {
        let slice = unsafe { slice::from_raw_parts(buf, len) };
        compute_shannon_entropy(slice)
    });
    result.unwrap_or(0.0)
}

/// Computes Shannon entropy ($0.0 \dots 8.0$) using strided sampling if buffer exceeds sample_limit.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_estimate_entropy_strided(
    buf: *const u8,
    len: usize,
    sample_limit: usize,
) -> f64 {
    if buf.is_null() || len == 0 {
        return 0.0;
    }
    let result = catch_unwind(|| {
        let slice = unsafe { slice::from_raw_parts(buf, len) };
        compute_shannon_entropy_strided(slice, sample_limit)
    });
    result.unwrap_or(0.0)
}

/// Determines whether a buffer should bypass compression to Store mode based on entropy and size threshold.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_should_bypass_compression(
    buf: *const u8,
    len: usize,
    threshold: f64,
    min_sample_bytes: usize,
) -> bool {
    if buf.is_null() || len == 0 {
        return false;
    }
    let result = catch_unwind(|| {
        let slice = unsafe { slice::from_raw_parts(buf, len) };
        should_bypass_compression_impl(slice, threshold, min_sample_bytes)
    });
    result.unwrap_or(false)
}

/// Evaluates payload and generates intelligent codec & level recommendation in $<10\,\text{ms}$.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_recommend_codec(
    buf: *const u8,
    len: usize,
    scenario: i32,
    out_result: *mut TTZipRecommendationResult,
) -> TTZipStatus {
    if out_result.is_null() {
        return TTZipStatus::ErrInvalidParam;
    }
    let data = if buf.is_null() || len == 0 {
        &[][..]
    } else {
        unsafe { slice::from_raw_parts(buf, len) }
    };

    let result = catch_unwind(|| {
        let sc = Scenario::from_code(scenario);
        let rec = CascadedCodecSelector::recommend(data, sc);

        let mut res = TTZipRecommendationResult {
            scenario: rec.scenario as i32,
            measured_entropy: rec.measured_entropy,
            trial_compressibility_ratio: rec.trial_compressibility_ratio,
            recommended_algorithm: [0; 32],
            recommended_level: rec.recommended_level,
            rationale: [0; 512],
            projected_throughput_mbs: rec.projected_throughput_mbs,
            projected_space_savings_pct: rec.projected_space_savings_pct,
            probe_duration_ms: rec.probe_duration_ms,
        };

        copy_str_to_c_buffer(rec.recommended_algorithm, &mut res.recommended_algorithm);
        copy_str_to_c_buffer(&rec.rationale, &mut res.rationale);

        unsafe {
            *out_result = res;
        }
        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_ffi_entropy_and_bypass() {
        let data = [0x41u8; 1024];
        let h = unsafe { ttzip_rust_estimate_entropy(data.as_ptr(), data.len()) };
        assert!(h < 1e-4);

        let bypass = unsafe { ttzip_rust_should_bypass_compression(data.as_ptr(), data.len(), 7.90, 1024) };
        assert!(!bypass);
    }

    #[test]
    fn test_ffi_recommend_codec() {
        let sample = b"Performance Benchmark Data 1234567890\n".repeat(500);
        let mut raw = TTZipRecommendationResult {
            scenario: 0,
            measured_entropy: 0.0,
            trial_compressibility_ratio: 0.0,
            recommended_algorithm: [0; 32],
            recommended_level: 0,
            rationale: [0; 512],
            projected_throughput_mbs: 0.0,
            projected_space_savings_pct: 0.0,
            probe_duration_ms: 0.0,
        };

        let st = unsafe { ttzip_rust_recommend_codec(sample.as_ptr(), sample.len(), 1, &mut raw) };
        assert_eq!(st, TTZipStatus::Ok);
        assert_eq!(raw.scenario, 1);
        let algo_str = unsafe { CStr::from_ptr(raw.recommended_algorithm.as_ptr()) }.to_str().unwrap();
        assert!(!algo_str.is_empty());
        let rationale_str = unsafe { CStr::from_ptr(raw.rationale.as_ptr()) }.to_str().unwrap();
        assert!(!rationale_str.is_empty());
    }
}
