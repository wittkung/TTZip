// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use crate::benchmark::*;

#[test]
fn test_benchmark_corpus_generation_all_types() {
    let types = [
        BenchmarkCorpusType::Calgary,
        BenchmarkCorpusType::Silesia,
        BenchmarkCorpusType::Xml,
        BenchmarkCorpusType::Random,
        BenchmarkCorpusType::Binary,
    ];

    for ct in types {
        let data = BenchmarkCorpusGenerator::generate(ct, 4096);
        assert_eq!(data.len(), 4096);
        assert!(!data.is_empty());
    }
}

#[test]
fn test_matrix_codecs_roundtrip_all_families() {
    let corpus = BenchmarkCorpusGenerator::generate(BenchmarkCorpusType::Silesia, 8192);

    let test_configs = [
        MatrixCodecConfig::new("Libdeflate", 6, "Libdeflate L6"),
        MatrixCodecConfig::new("Zstd", 3, "Zstd L3"),
        MatrixCodecConfig::new("LZ4", 1, "LZ4 Fast 1"),
        MatrixCodecConfig::new("LZFSE", 1, "Apple LZFSE"),
        MatrixCodecConfig::new("Snappy", 1, "Snappy"),
        MatrixCodecConfig::new("Brotli", 4, "Brotli Q4"),
        MatrixCodecConfig::new("Bzip2", 5, "Bzip2 L5"),
    ];

    for cfg in &test_configs {
        let comp = MatrixCodecDriver::compress(cfg, &corpus)
            .unwrap_or_else(|_| panic!("Compression failed for {}", cfg.display_name));
        assert!(!comp.is_empty());

        let decomp = MatrixCodecDriver::decompress(cfg, &comp, corpus.len())
            .unwrap_or_else(|_| panic!("Decompression failed for {}", cfg.display_name));
        assert_eq!(decomp, corpus);
    }
}

#[test]
fn test_50_point_matrix_gate_execution() {
    let report = BenchmarkMatrixRunner::run_matrix(BenchmarkCorpusType::Xml, 32 * 1024, 1)
        .expect("Matrix gate run failed");

    assert!(report.total_points_evaluated >= 50);
    assert!(report.pareto_optimal_count > 0);
    assert!(report.peak_compress_throughput_mbs > 0.0);
    assert!(report.peak_decompress_throughput_mbs > 0.0);
    assert!(report.max_space_savings_pct > 0.0);
    assert!(report.passed_gate);
}

#[test]
fn test_fritsch_carlson_spline_monotonicity() {
    let points = vec![
        SplinePoint::new(10.0, 10.0),
        SplinePoint::new(20.0, 15.0),
        SplinePoint::new(30.0, 60.0),
        SplinePoint::new(40.0, 80.0),
        SplinePoint::new(50.0, 85.0),
    ];

    let spline = FritschCarlsonSpline::new(points).expect("spline creation");

    // Verify monotonicity across interpolation query points
    let mut prev_y = spline.interpolate(10.0);
    for step in 11..=50 {
        let x = step as f64;
        let y = spline.interpolate(x);
        assert!(y >= prev_y, "Monotonicity violated at x={}: y={} < prev={}", x, y, prev_y);
        prev_y = y;
    }

    let svg_path = spline.to_svg_bezier_path(|x, y| (x * 10.0, y * 10.0));
    assert!(svg_path.starts_with("M 100.00,100.00"));
    assert!(svg_path.contains(" C "));
}

#[test]
fn test_svg_and_html_dashboard_generation() {
    let report = BenchmarkMatrixRunner::run_matrix(BenchmarkCorpusType::Calgary, 32 * 1024, 1)
        .expect("Matrix run");

    let svg = BenchmarkPlotter::generate_svg(&report, 800, 450);
    assert!(svg.starts_with("<svg"));
    assert!(svg.contains("TTZip Pareto Frontier:"));
    assert!(svg.ends_with("</svg>"));

    let html = BenchmarkPlotter::generate_html_dashboard(&report);
    assert!(html.contains("<!DOCTYPE html>"));
    assert!(html.contains("TTZip Multi-Codec Benchmark Dashboard"));
    assert!(html.contains("Matrix Benchmark Points"));
    assert!(html.contains("<svg"));
}

#[test]
fn test_binary_delta_auditor() {
    let raw = BenchmarkCorpusGenerator::generate(BenchmarkCorpusType::Silesia, 16 * 1024);
    let cfg = MatrixCodecConfig::new("Zstd", 3, "Zstd L3");
    let compressed = MatrixCodecDriver::compress(&cfg, &raw).expect("compress");

    let report = BinaryDeltaAuditor::audit(&raw, &compressed, 4096, "Zstd L3");
    assert_eq!(report.total_raw_bytes, 16 * 1024);
    assert_eq!(report.total_compressed_bytes, compressed.len());
    assert_eq!(report.total_segments, 4);
    assert!(report.mean_raw_entropy > 0.0);
    assert!(report.byte_divergence_score > 0.0);

    let json = report.to_json().expect("to json");
    assert!(json.contains("overall_space_savings_pct"));

    let md = report.to_markdown();
    assert!(md.contains("# Binary Delta & Divergence Audit"));
}
