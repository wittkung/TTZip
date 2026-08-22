// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 50-Point Matrix Gate Benchmark Runner and Metric Evaluator.
//!
//! Executes multi-algorithm compression/decompression runs, calculates MB/s throughputs,
//! space savings, Pareto ranks, and convex envelope frontiers.

use std::time::{Instant, SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

use super::codecs_driver::MatrixCodecDriver;
use super::corpus::{BenchmarkCorpusGenerator, BenchmarkCorpusType};
use super::pareto::{calculate_pareto_frontier, ParetoCodecPoint};
use crate::types::TTZipStatus;

/// Metrics for an individual algorithm benchmark point.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BenchmarkPointResult {
    pub algorithm: String,
    pub level: i32,
    pub display_name: String,
    pub original_size_bytes: usize,
    pub compressed_size_bytes: usize,
    pub compression_ratio: f64,
    pub space_savings_pct: f64,
    pub compress_throughput_mbs: f64,
    pub decompress_throughput_mbs: f64,
    pub compress_time_nanos: u64,
    pub decompress_time_nanos: u64,
    pub pareto_rank: u32,
    pub is_pareto_optimal: bool,
    pub is_on_convex_hull: bool,
}

/// Comprehensive benchmark matrix report across all evaluated codecs.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BenchmarkMatrixReport {
    pub corpus_type: BenchmarkCorpusType,
    pub corpus_name: String,
    pub corpus_size_bytes: usize,
    pub timestamp_epoch_secs: u64,
    pub total_points_evaluated: usize,
    pub pareto_optimal_count: usize,
    pub peak_compress_throughput_mbs: f64,
    pub peak_decompress_throughput_mbs: f64,
    pub max_space_savings_pct: f64,
    pub points: Vec<BenchmarkPointResult>,
    pub passed_gate: bool,
}

impl BenchmarkMatrixReport {
    /// Formats and prints a structured ASCII table to stdout.
    pub fn print_table(&self) {
        println!("==========================================================================================================================");
        println!("⚡️ TTZip Unified In-Memory Matrix (Total Points: {})", self.points.len());
        println!("==========================================================================================================================");
        println!("[Idx] Engine     | Level | Original   | Compressed | Space Saved | Comp Speed  | Decomp Speed | Pareto Status");
        println!("--------------------------------------------------------------------------------------------------------------------------");
        for (idx, pt) in self.points.iter().enumerate() {
            let pareto_str = if pt.is_pareto_optimal {
                "⭐ Optimal (Rank 1)"
            } else {
                "   Dominated"
            };
            println!(
                "[{:>2}] {:<10} | L{:<3} | {:>8} B | {:>8} B | {:>10.1}% | {:>9.1} MB/s | {:>10.1} MB/s | {}",
                idx + 1,
                pt.algorithm,
                pt.level,
                pt.original_size_bytes,
                pt.compressed_size_bytes,
                pt.space_savings_pct,
                pt.compress_throughput_mbs,
                pt.decompress_throughput_mbs,
                pareto_str
            );
        }
        println!("--------------------------------------------------------------------------------------------------------------------------");
        println!(
            "Summary: {} Points Evaluated | {} Pareto Optimal | Peak Comp: {:.1} MB/s | Gate: {}",
            self.total_points_evaluated,
            self.pareto_optimal_count,
            self.peak_compress_throughput_mbs,
            if self.passed_gate { "✅ PASS" } else { "❌ FAIL" }
        );
        println!("==========================================================================================================================");
    }
}

/// Matrix gate benchmark executor engine.
pub struct BenchmarkMatrixRunner;

impl BenchmarkMatrixRunner {
    /// Executes the benchmark pass across all 60 standard configurations for the given corpus.
    pub fn run_matrix(
        corpus_type: BenchmarkCorpusType,
        corpus_size: usize,
        iterations: usize,
    ) -> Result<BenchmarkMatrixReport, TTZipStatus> {
        let corpus_size = corpus_size.max(64 * 1024);
        let iterations = iterations.max(1);
        let corpus_data = BenchmarkCorpusGenerator::generate(corpus_type, corpus_size);
        let configs = MatrixCodecDriver::all_matrix_configs();

        let mut point_results = Vec::with_capacity(configs.len());
        let mut pareto_points = Vec::with_capacity(configs.len());

        for cfg in &configs {
            // Warmup & trial run
            let mut comp_data = MatrixCodecDriver::compress(cfg, &corpus_data)?;
            let decomp_data =
                MatrixCodecDriver::decompress(cfg, &comp_data, corpus_data.len())?;

            if decomp_data != corpus_data {
                return Err(TTZipStatus::ErrExtractionFailed);
            }

            // High-resolution monotonic timing: Compression
            let t_comp_start = Instant::now();
            for _ in 0..iterations {
                comp_data = MatrixCodecDriver::compress(cfg, &corpus_data)?;
            }
            let comp_elapsed_nanos = t_comp_start.elapsed().as_nanos() as u64;
            let comp_time_per_iter_sec =
                (comp_elapsed_nanos as f64) / (iterations as f64 * 1_000_000_000.0);

            // High-resolution monotonic timing: Decompression
            let t_decomp_start = Instant::now();
            for _ in 0..iterations {
                let _ = MatrixCodecDriver::decompress(cfg, &comp_data, corpus_data.len())?;
            }
            let decomp_elapsed_nanos = t_decomp_start.elapsed().as_nanos() as u64;
            let decomp_time_per_iter_sec =
                (decomp_elapsed_nanos as f64) / (iterations as f64 * 1_000_000_000.0);

            let orig_len = corpus_data.len();
            let comp_len = comp_data.len();
            let ratio = if orig_len > 0 {
                (comp_len as f64) / (orig_len as f64)
            } else {
                1.0
            };
            let space_savings = ((1.0 - ratio) * 100.0).max(0.0);

            let comp_mb = (orig_len as f64) / (1024.0 * 1024.0);
            let comp_speed_mbs = if comp_time_per_iter_sec > 1e-9 {
                comp_mb / comp_time_per_iter_sec
            } else {
                0.0
            };
            let decomp_speed_mbs = if decomp_time_per_iter_sec > 1e-9 {
                comp_mb / decomp_time_per_iter_sec
            } else {
                0.0
            };

            pareto_points.push(ParetoCodecPoint::new(
                &cfg.display_name,
                space_savings, // Optimization target: maximize space savings %
                comp_speed_mbs, // Optimization target: maximize speed MB/s
                0.0,
            ));

            point_results.push(BenchmarkPointResult {
                algorithm: cfg.algorithm.clone(),
                level: cfg.level,
                display_name: cfg.display_name.clone(),
                original_size_bytes: orig_len,
                compressed_size_bytes: comp_len,
                compression_ratio: ratio,
                space_savings_pct: space_savings,
                compress_throughput_mbs: comp_speed_mbs,
                decompress_throughput_mbs: decomp_speed_mbs,
                compress_time_nanos: comp_elapsed_nanos / (iterations as u64),
                decompress_time_nanos: decomp_elapsed_nanos / (iterations as u64),
                pareto_rank: 1,
                is_pareto_optimal: false,
                is_on_convex_hull: false,
            });
        }

        // Compute 2D Pareto frontier and Convex Hull
        calculate_pareto_frontier(&mut pareto_points);

        let mut pareto_count = 0;
        let mut peak_comp = 0.0;
        let mut peak_decomp = 0.0;
        let mut max_savings = 0.0;

        for (pt, pareto) in point_results.iter_mut().zip(pareto_points.iter()) {
            pt.pareto_rank = pareto.pareto_rank;
            pt.is_pareto_optimal = pareto.is_pareto_optimal;
            pt.is_on_convex_hull = pareto.is_on_convex_hull;

            if pt.is_pareto_optimal {
                pareto_count += 1;
            }
            if pt.compress_throughput_mbs > peak_comp {
                peak_comp = pt.compress_throughput_mbs;
            }
            if pt.decompress_throughput_mbs > peak_decomp {
                peak_decomp = pt.decompress_throughput_mbs;
            }
            if pt.space_savings_pct > max_savings {
                max_savings = pt.space_savings_pct;
            }
        }

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let passed = point_results.len() >= 50 && pareto_count > 0;

        Ok(BenchmarkMatrixReport {
            corpus_type,
            corpus_name: corpus_type.name().to_string(),
            corpus_size_bytes: corpus_data.len(),
            timestamp_epoch_secs: timestamp,
            total_points_evaluated: point_results.len(),
            pareto_optimal_count: pareto_count,
            peak_compress_throughput_mbs: peak_comp,
            peak_decompress_throughput_mbs: peak_decomp,
            max_space_savings_pct: max_savings,
            points: point_results,
            passed_gate: passed,
        })
    }

    /// Executes standard 50-point Matrix Gate pass (128KB Silesia corpus, 2 iterations).
    pub fn run_gate() -> Result<BenchmarkMatrixReport, TTZipStatus> {
        Self::run_matrix(BenchmarkCorpusType::Silesia, 128 * 1024, 2)
    }
}
