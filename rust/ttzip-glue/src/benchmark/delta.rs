// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Binary segment delta auditor and compression divergence metric report generator.
//!
//! Performs chunk-level entropy profiling, identifies compressible vs incompressible segments,
//! and calculates byte distribution divergence between raw and compressed payloads.

use serde::{Deserialize, Serialize};

use crate::analytics::entropy::compute_shannon_entropy;

/// Audit metrics for an individual contiguous binary segment.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SegmentDeltaAudit {
    pub segment_index: usize,
    pub raw_offset: usize,
    pub raw_length: usize,
    pub raw_entropy: f64,
    pub is_compressible: bool,
}

/// Comprehensive binary divergence and delta audit report.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BinaryDeltaReport {
    pub algorithm_name: String,
    pub total_raw_bytes: usize,
    pub total_compressed_bytes: usize,
    pub overall_space_savings_pct: f64,
    pub segment_size_bytes: usize,
    pub total_segments: usize,
    pub compressible_segments: usize,
    pub incompressible_segments: usize,
    pub mean_raw_entropy: f64,
    pub byte_divergence_score: f64,
    pub segments: Vec<SegmentDeltaAudit>,
}

impl BinaryDeltaReport {
    /// Serializes report to JSON string.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    /// Generates human-readable Markdown summary report.
    pub fn to_markdown(&self) -> String {
        let mut md = String::with_capacity(2048);
        md.push_str(&format!("# Binary Delta & Divergence Audit: {}\n\n", self.algorithm_name));
        md.push_str(&format!("- **Raw Size**: {} bytes\n", self.total_raw_bytes));
        md.push_str(&format!("- **Compressed Size**: {} bytes\n", self.total_compressed_bytes));
        md.push_str(&format!("- **Overall Space Savings**: {:.2}%\n", self.overall_space_savings_pct));
        md.push_str(&format!("- **Mean Shannon Entropy**: {:.4} bits/byte\n", self.mean_raw_entropy));
        md.push_str(&format!("- **Byte Divergence Score**: {:.4}\n", self.byte_divergence_score));
        md.push_str(&format!(
            "- **Segment Breakdown**: {} total ({} compressible, {} incompressible)\n\n",
            self.total_segments, self.compressible_segments, self.incompressible_segments
        ));
        md.push_str("| Segment # | Offset | Length | Entropy | Status |\n");
        md.push_str("|-----------|--------|--------|---------|--------|\n");

        for seg in self.segments.iter().take(20) {
            let status = if seg.is_compressible { "Compressible" } else { "Incompressible (High Entropy)" };
            md.push_str(&format!(
                "| {} | 0x{:06X} | {} B | {:.2} | {} |\n",
                seg.segment_index, seg.raw_offset, seg.raw_length, seg.raw_entropy, status
            ));
        }

        if self.segments.len() > 20 {
            md.push_str(&format!("| ... | ... | ... | ... | ({} more segments omitted) |\n", self.segments.len() - 20));
        }

        md
    }
}

/// Binary delta and chunk-level entropy auditor.
pub struct BinaryDeltaAuditor;

impl BinaryDeltaAuditor {
    /// Computes Jensen-Shannon style normalized divergence score between two byte histograms.
    pub fn compute_byte_divergence(raw: &[u8], compressed: &[u8]) -> f64 {
        if raw.is_empty() || compressed.is_empty() {
            return 0.0;
        }

        let mut raw_hist = [0usize; 256];
        let mut comp_hist = [0usize; 256];

        for &b in raw {
            raw_hist[b as usize] += 1;
        }
        for &b in compressed {
            comp_hist[b as usize] += 1;
        }

        let raw_total = raw.len() as f64;
        let comp_total = compressed.len() as f64;

        let mut l1_dist = 0.0;
        for i in 0..256 {
            let p = (raw_hist[i] as f64) / raw_total;
            let q = (comp_hist[i] as f64) / comp_total;
            l1_dist += (p - q).abs();
        }

        // L1 distance is in [0, 2]; normalize to [0, 1]
        (l1_dist * 0.5).clamp(0.0, 1.0)
    }

    /// Audits raw vs compressed payload at chunk level.
    pub fn audit(
        raw_data: &[u8],
        compressed_data: &[u8],
        segment_size: usize,
        algorithm_name: &str,
    ) -> BinaryDeltaReport {
        let segment_size = segment_size.clamp(1024, 1024 * 1024);
        let total_raw = raw_data.len();
        let total_comp = compressed_data.len();

        let ratio = if total_raw > 0 {
            (total_comp as f64) / (total_raw as f64)
        } else {
            1.0
        };
        let space_savings = ((1.0 - ratio) * 100.0).max(0.0);

        let mut segments = Vec::new();
        let mut entropy_sum = 0.0;
        let mut compressible_count = 0;
        let mut incompressible_count = 0;

        let mut offset = 0;
        let mut seg_idx = 0;

        while offset < total_raw {
            let end = (offset + segment_size).min(total_raw);
            let chunk = &raw_data[offset..end];
            let entropy = compute_shannon_entropy(chunk);
            entropy_sum += entropy;

            // Threshold: Shannon entropy < 7.5 indicates compressible structure
            let is_comp = entropy < 7.5;
            if is_comp {
                compressible_count += 1;
            } else {
                incompressible_count += 1;
            }

            segments.push(SegmentDeltaAudit {
                segment_index: seg_idx,
                raw_offset: offset,
                raw_length: chunk.len(),
                raw_entropy: entropy,
                is_compressible: is_comp,
            });

            offset = end;
            seg_idx += 1;
        }

        let mean_entropy = if !segments.is_empty() {
            entropy_sum / (segments.len() as f64)
        } else {
            0.0
        };

        let divergence = Self::compute_byte_divergence(raw_data, compressed_data);

        BinaryDeltaReport {
            algorithm_name: algorithm_name.to_string(),
            total_raw_bytes: total_raw,
            total_compressed_bytes: total_comp,
            overall_space_savings_pct: space_savings,
            segment_size_bytes: segment_size,
            total_segments: segments.len(),
            compressible_segments: compressible_count,
            incompressible_segments: incompressible_count,
            mean_raw_entropy: mean_entropy,
            byte_divergence_score: divergence,
            segments,
        }
    }
}
