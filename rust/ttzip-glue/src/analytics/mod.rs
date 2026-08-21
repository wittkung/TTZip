// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Analytics, Hardware SIMD Shannon Entropy, and Cascaded Codec Recommendation module.

pub mod codec_selector;
pub mod entropy;

pub use codec_selector::{compute_trial_compressibility, CascadedCodecSelector, RecommendationResult, Scenario};
pub use entropy::{
    compute_histogram_256, compute_shannon_entropy, compute_shannon_entropy_strided, fast_log2,
    should_bypass_compression, DEFAULT_ENTROPY_THRESHOLD, MIN_SAMPLE_SIZE_BYTES,
};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_analytics_integration_roundtrip() {
        let sample = b"TTZip Analytics SIMD Entropy Engine Verification".repeat(100);
        let h = compute_shannon_entropy(&sample);
        assert!(h > 3.0 && h < 5.5);

        let rec = CascadedCodecSelector::recommend(&sample, Scenario::InstantTransfer);
        assert!(!rec.recommended_algorithm.is_empty());
        assert!(rec.probe_duration_ms >= 0.0);
    }
}
