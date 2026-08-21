// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use std::ffi::CStr;
use ttzip_glue::ffi::analytics_ffi::{
    ttzip_rust_estimate_entropy, ttzip_rust_estimate_entropy_strided,
    ttzip_rust_recommend_codec, ttzip_rust_should_bypass_compression,
    TTZipRecommendationResult,
};
use ttzip_glue::types::TTZipStatus;

#[test]
fn test_analytics_ffi_entropy_precision_and_speed() {
    // 1MB Random data for throughput / latency benchmark
    let mut buffer = vec![0u8; 1024 * 1024];
    let mut state: u64 = 0xDEADBEEFCAFE;
    for b in buffer.iter_mut() {
        state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        *b = ((state >> 32) & 0xFF) as u8;
    }

    let t0 = std::time::Instant::now();
    let entropy = unsafe { ttzip_rust_estimate_entropy(buffer.as_ptr(), buffer.len()) };
    let elapsed = t0.elapsed();

    assert!(entropy > 7.90, "Random data entropy expected > 7.90, got {}", entropy);
    println!("1MB Direct SIMD Entropy duration: {:?}", elapsed);

    let strided_entropy = unsafe {
        ttzip_rust_estimate_entropy_strided(buffer.as_ptr(), buffer.len(), 65536)
    };
    assert!(strided_entropy > 7.85);

    let bypass = unsafe {
        ttzip_rust_should_bypass_compression(buffer.as_ptr(), buffer.len(), 7.90, 1024 * 1024)
    };
    assert!(bypass, "High entropy payload should trigger bypass");
}

#[test]
fn test_analytics_ffi_recommend_all_scenarios() {
    let text = b"The quick brown fox jumps over the lazy dog. Repetitive text payload.\n".repeat(2000);

    for (scenario_idx, expected_algo_candidates) in [
        (0, vec!["Zstandard", "LZ4"]),
        (1, vec!["Zstandard", "ZIP-Deflate"]),
        (2, vec!["7Z-LZMA2"]),
    ] {
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

        let status = unsafe {
            ttzip_rust_recommend_codec(text.as_ptr(), text.len(), scenario_idx, &mut raw)
        };
        assert_eq!(status, TTZipStatus::Ok);
        assert_eq!(raw.scenario, scenario_idx);

        let algo = unsafe { CStr::from_ptr(raw.recommended_algorithm.as_ptr()) }.to_str().unwrap();
        assert!(
            expected_algo_candidates.contains(&algo),
            "Unexpected algo {} for scenario {}",
            algo,
            scenario_idx
        );
        assert!(raw.probe_duration_ms < 10.0, "Probe took too long: {} ms", raw.probe_duration_ms);
    }
}
