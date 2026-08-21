// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 3-Stage Cascaded Codec Recommendation Engine.
//!
//! Evaluates incoming data payloads in $<10\,\text{ms}$ through:
//! 1. Stage 1: Hardware SIMD Shannon Entropy Probe (up to 1MB sample);
//! 2. Stage 2: 64KB Strided Micro-Trial Compression (`libdeflate` L1);
//! 3. Stage 3: Scenario-specific classification decision matrix.

use std::time::Instant;

use super::entropy::compute_shannon_entropy;

/// Target compression scenario profile.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scenario {
    InstantTransfer = 0,
    BalancedDaily = 1,
    ColdStorage = 2,
}

impl Scenario {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::InstantTransfer => "Instant Transfer (AirDrop/10G LAN)",
            Self::BalancedDaily => "Balanced Daily Archive",
            Self::ColdStorage => "Cold Storage / Maximum Ratio",
        }
    }

    pub fn from_code(code: i32) -> Self {
        match code {
            0 => Self::InstantTransfer,
            2 => Self::ColdStorage,
            _ => Self::BalancedDaily,
        }
    }

    pub fn from_str_lenient(s: &str) -> Self {
        let lower = s.to_lowercase();
        if lower.contains("airdrop") || lower.contains("instant") || lower.contains("lan") || lower.contains("fast") {
            Self::InstantTransfer
        } else if lower.contains("cold") || lower.contains("max") || lower.contains("backup") || lower.contains("archive") {
            Self::ColdStorage
        } else {
            Self::BalancedDaily
        }
    }
}

/// Comprehensive recommendation outcome and metrics.
#[derive(Debug, Clone, PartialEq)]
pub struct RecommendationResult {
    pub scenario: Scenario,
    pub measured_entropy: f64,
    pub trial_compressibility_ratio: f64,
    pub recommended_algorithm: &'static str,
    pub recommended_level: i32,
    pub rationale: String,
    pub projected_throughput_mbs: f64,
    pub projected_space_savings_pct: f64,
    pub probe_duration_ms: f64,
}

/// Cascaded Codec Selector.
pub struct CascadedCodecSelector;

impl CascadedCodecSelector {
    /// Evaluates input payload and generates optimal algorithm & level recommendation in $<10\,\text{ms}$.
    pub fn recommend(data: &[u8], scenario: Scenario) -> RecommendationResult {
        let t0 = Instant::now();

        // 1. Stage 1: SIMD Shannon Entropy Probe (Up to 1MB)
        let sample_len = data.len().min(1024 * 1024);
        let sample_data = if sample_len > 0 { &data[..sample_len] } else { &[] };
        let entropy = compute_shannon_entropy(sample_data);

        // 2. Stage 2: 64KB Strided Micro-Trial Compression (libdeflate Level 1)
        let trial_ratio = compute_trial_compressibility(data);

        let probe_duration_ms = (t0.elapsed().as_nanos() as f64) / 1_000_000.0;

        // 3. Stage 3: Scenario Decision Matrix
        let (algo, lvl, rationale, tp_mbs, space_pct) = if entropy > 7.92 && trial_ratio > 0.98 {
            // High entropy incompressible payload (encrypted, video, compressed package)
            (
                "Store",
                0,
                format!(
                    "检测到数据处于高熵状态 (H={:.2})，经 64KB 微试压不可压缩 (比率 {:.1}%)，直通 Store 存储可彻底节省 CPU 算力。",
                    entropy,
                    trial_ratio * 100.0
                ),
                6500.0,
                0.0,
            )
        } else {
            match scenario {
                Scenario::InstantTransfer => {
                    if trial_ratio < 0.50 {
                        (
                            "Zstandard",
                            1,
                            "检测到高可压缩数据，在极速分发场景下推荐 Zstandard L1，解压吞吐可突破 40 GB/s 内存极限，大幅压缩全链路耗时。".to_string(),
                            3000.0,
                            ((1.0 - trial_ratio) * 100.0).max(0.0),
                        )
                    } else {
                        (
                            "LZ4",
                            1,
                            "在高速局域网与即时分发场景下推荐 LZ4，提供极致的编解码速率 (30+ GB/s) 消除传输与计算等待。".to_string(),
                            4000.0,
                            ((1.0 - trial_ratio) * 100.0).max(0.0),
                        )
                    }
                }
                Scenario::BalancedDaily => {
                    if trial_ratio < 0.40 {
                        (
                            "Zstandard",
                            3,
                            "日常存储推荐 Zstandard L3，在保持超高解压性能的同时获得优于传统 ZIP 的压缩比。".to_string(),
                            1800.0,
                            ((1.0 - trial_ratio * 0.9) * 100.0).max(0.0),
                        )
                    } else {
                        (
                            "ZIP-Deflate",
                            6,
                            "日常通用兼容归档推荐标准 ZIP-Deflate L6，全平台原生兼容且经过 Apple Silicon 硬件加速。".to_string(),
                            1200.0,
                            ((1.0 - trial_ratio) * 100.0).max(0.0),
                        )
                    }
                }
                Scenario::ColdStorage => {
                    (
                        "7Z-LZMA2",
                        9,
                        "冷备份与极限归档场景推荐 7Z-LZMA2 Ultra (L9)，利用最大字典匹配器压榨每一字节存储空间。".to_string(),
                        500.0,
                        ((1.0 - trial_ratio * 0.75) * 100.0).max(0.0),
                    )
                }
            }
        };

        RecommendationResult {
            scenario,
            measured_entropy: entropy,
            trial_compressibility_ratio: trial_ratio,
            recommended_algorithm: algo,
            recommended_level: lvl,
            rationale,
            projected_throughput_mbs: tp_mbs,
            projected_space_savings_pct: space_pct,
            probe_duration_ms,
        }
    }
}

/// 64KB Strided 4x16KB Micro-Trial Compression using libdeflate Level 1.
pub fn compute_trial_compressibility(data: &[u8]) -> f64 {
    if data.is_empty() {
        return 1.0;
    }
    let stride_size = 16384; // 16KB
    let num_strides = (data.len() / stride_size).clamp(1, 4);
    let total_trial_bytes = num_strides * stride_size;

    let mut src = vec![0u8; total_trial_bytes];
    let step = data.len() / num_strides;
    for i in 0..num_strides {
        let src_offset = (i * step).min(data.len().saturating_sub(stride_size));
        let copy_len = stride_size.min(data.len() - src_offset);
        src[i * stride_size..i * stride_size + copy_len].copy_from_slice(&data[src_offset..src_offset + copy_len]);
    }

    let mut dst = vec![0u8; total_trial_bytes + 4096];
    match crate::codecs::deflate::deflate_compress(&src[..total_trial_bytes], &mut dst, 1) {
        Ok(out_len) if out_len > 0 => (out_len as f64) / (total_trial_bytes as f64),
        _ => 1.0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_high_entropy_store_bypass() {
        let mut random_data = vec![0u8; 65536];
        let mut state: u64 = 0x853c49e6748fea9b;
        for byte in random_data.iter_mut() {
            state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            *byte = ((state >> 32) & 0xFF) as u8;
        }

        let res = CascadedCodecSelector::recommend(&random_data, Scenario::BalancedDaily);
        assert!(res.measured_entropy > 7.8);
        assert!(res.trial_compressibility_ratio > 0.95);
        assert_eq!(res.recommended_algorithm, "Store");
        assert_eq!(res.recommended_level, 0);
        assert!(res.probe_duration_ms < 20.0);
    }

    #[test]
    fn test_text_data_scenario_matrix() {
        let text = b"The quick brown fox jumps over the lazy dog. TTZip high performance compression engine.\n".repeat(1500);

        let rec_instant = CascadedCodecSelector::recommend(&text, Scenario::InstantTransfer);
        assert!(rec_instant.recommended_algorithm == "Zstandard" || rec_instant.recommended_algorithm == "LZ4");
        assert_eq!(rec_instant.recommended_level, 1);

        let rec_balanced = CascadedCodecSelector::recommend(&text, Scenario::BalancedDaily);
        assert!(rec_balanced.recommended_algorithm == "Zstandard" || rec_balanced.recommended_algorithm == "ZIP-Deflate");

        let rec_cold = CascadedCodecSelector::recommend(&text, Scenario::ColdStorage);
        assert_eq!(rec_cold.recommended_algorithm, "7Z-LZMA2");
        assert_eq!(rec_cold.recommended_level, 9);
    }
}
