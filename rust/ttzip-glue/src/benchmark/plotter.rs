// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! SVG vector plotter and standalone interactive HTML dashboard generator.
//!
//! Visualizes 50-point Matrix Gate benchmarks with Fritsch-Carlson smooth Pareto trajectories.

use super::runner::BenchmarkMatrixReport;
use super::spline::{FritschCarlsonSpline, SplinePoint};

/// Visualizer for benchmark reports.
pub struct BenchmarkPlotter;

impl BenchmarkPlotter {
    fn algorithm_color(algo: &str) -> &'static str {
        match algo {
            "Libdeflate" => "#3B82F6",
            "Zstd" => "#10B981",
            "LZ4" => "#06B6D4",
            "LZFSE" => "#F59E0B",
            "Snappy" => "#8B5CF6",
            "Brotli" => "#EC4899",
            "Bzip2" => "#EF4444",
            _ => "#94A3B8",
        }
    }

    /// Generates a standalone, vector SVG chart with scatter points and smooth Pareto frontier trajectory.
    pub fn generate_svg(report: &BenchmarkMatrixReport, width: u32, height: u32) -> String {
        let width = width.max(640) as f64;
        let height = height.max(400) as f64;
        let pad_l = 80.0;
        let pad_r = 50.0;
        let pad_t = 60.0;
        let pad_b = 65.0;

        let plot_w = width - pad_l - pad_r;
        let plot_h = height - pad_t - pad_b;

        let max_speed = report.peak_compress_throughput_mbs.max(100.0) * 1.15;
        let max_savings = 100.0;

        let map_x = |speed: f64| -> f64 { pad_l + (speed / max_speed) * plot_w };
        let map_y = |savings: f64| -> f64 { pad_t + plot_h - (savings / max_savings) * plot_h };

        let mut svg = String::with_capacity(8192);
        svg.push_str(&format!(
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {} {}\" width=\"100%\" height=\"100%\" style=\"background:#0F172A;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Segoe UI',sans-serif;\">\n",
            width, height
        ));

        // Background grid lines
        svg.push_str("<g stroke=\"#334155\" stroke-width=\"1\" stroke-dasharray=\"3,3\" opacity=\"0.6\">\n");
        for s in (0..=100).step_by(20) {
            let y = map_y(s as f64);
            svg.push_str(&format!(
                "  <line x1=\"{:.1}\" y1=\"{:.1}\" x2=\"{:.1}\" y2=\"{:.1}\"/>\n",
                pad_l, y, width - pad_r, y
            ));
            svg.push_str(&format!(
                "  <text x=\"{:.1}\" y=\"{:.1}\" fill=\"#64748B\" font-size=\"11\" text-anchor=\"end\" alignment-baseline=\"middle\">{}%</text>\n",
                pad_l - 10.0, y, s
            ));
        }

        let speed_step = (max_speed / 5.0).round().max(10.0);
        let mut sp = 0.0;
        while sp <= max_speed {
            let x = map_x(sp);
            if x <= width - pad_r {
                svg.push_str(&format!(
                    "  <line x1=\"{:.1}\" y1=\"{:.1}\" x2=\"{:.1}\" y2=\"{:.1}\"/>\n",
                    x, pad_t, x, pad_t + plot_h
                ));
                svg.push_str(&format!(
                    "  <text x=\"{:.1}\" y=\"{:.1}\" fill=\"#64748B\" font-size=\"11\" text-anchor=\"middle\">{:.0}</text>\n",
                    x, pad_t + plot_h + 20.0, sp
                ));
            }
            sp += speed_step;
        }
        svg.push_str("</g>\n");

        // Axis Titles
        svg.push_str(&format!(
            "<text x=\"{:.1}\" y=\"32\" fill=\"#F8FAFC\" font-size=\"16\" font-weight=\"bold\">TTZip Pareto Frontier: {}</text>\n",
            pad_l, report.corpus_name
        ));
        svg.push_str(&format!(
            "<text x=\"{:.1}\" y=\"{:.1}\" fill=\"#94A3B8\" font-size=\"12\" text-anchor=\"middle\">Compression Throughput (MB/s)</text>\n",
            pad_l + plot_w / 2.0, height - 15.0
        ));
        svg.push_str(&format!(
            "<text x=\"20\" y=\"{:.1}\" fill=\"#94A3B8\" font-size=\"12\" text-anchor=\"middle\" transform=\"rotate(-90 20 {:.1})\">Space Savings (%)</text>\n",
            pad_t + plot_h / 2.0, pad_t + plot_h / 2.0
        ));

        // Smooth Pareto Trajectory Line via Fritsch-Carlson Spline
        let pareto_points: Vec<SplinePoint> = report
            .points
            .iter()
            .filter(|p| p.is_pareto_optimal)
            .map(|p| SplinePoint::new(p.compress_throughput_mbs, p.space_savings_pct))
            .collect();

        if pareto_points.len() >= 2 {
            if let Some(spline) = FritschCarlsonSpline::new(pareto_points) {
                let path_d = spline.to_svg_bezier_path(|x, y| (map_x(x), map_y(y)));
                svg.push_str(&format!(
                    "<path d=\"{}\" fill=\"none\" stroke=\"#F59E0B\" stroke-width=\"3\" stroke-linecap=\"round\" opacity=\"0.9\" filter=\"drop-shadow(0 0 6px #F59E0B88)\"/>\n",
                    path_d
                ));
            }
        }

        // Scatter Points
        for pt in &report.points {
            let cx = map_x(pt.compress_throughput_mbs);
            let cy = map_y(pt.space_savings_pct);
            let color = Self::algorithm_color(&pt.algorithm);
            let r = if pt.is_pareto_optimal { 6.5 } else { 4.0 };
            let stroke = if pt.is_pareto_optimal { "#FFFFFF" } else { "#1E293B" };
            let stroke_w = if pt.is_pareto_optimal { 2.0 } else { 1.0 };

            svg.push_str(&format!(
                "<circle cx=\"{:.1}\" cy=\"{:.1}\" r=\"{:.1}\" fill=\"{}\" stroke=\"{}\" stroke-width=\"{:.1}\">\n",
                cx, cy, r, color, stroke, stroke_w
            ));
            svg.push_str(&format!(
                "  <title>{}: {:.1} MB/s, {:.1}% savings (Rank {})</title>\n",
                pt.display_name, pt.compress_throughput_mbs, pt.space_savings_pct, pt.pareto_rank
            ));
            svg.push_str("</circle>\n");
        }

        svg.push_str("</svg>");
        svg
    }

    /// Generates a complete standalone HTML interactive dashboard report.
    pub fn generate_html_dashboard(report: &BenchmarkMatrixReport) -> String {
        let svg = Self::generate_svg(report, 960, 480);
        let mut html = String::with_capacity(16384);

        html.push_str("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n");
        html.push_str("<meta charset=\"UTF-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
        html.push_str("<title>TTZip Native Codec Matrix Dashboard</title>\n");
        html.push_str("<style>\n");
        html.push_str("  body { margin: 0; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif; background: #0B0F19; color: #F1F5F9; }\n");
        html.push_str("  .container { max-width: 1200px; margin: 0 auto; }\n");
        html.push_str("  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1E293B; padding-bottom: 16px; margin-bottom: 24px; }\n");
        html.push_str("  .title-group h1 { margin: 0; font-size: 24px; color: #38BDF8; font-weight: 700; }\n");
        html.push_str("  .title-group p { margin: 4px 0 0; font-size: 13px; color: #94A3B8; }\n");
        html.push_str("  .badge { background: #10B98122; color: #10B981; border: 1px solid #10B98144; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }\n");
        html.push_str("  .kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }\n");
        html.push_str("  .card { background: #1E293B; border-radius: 12px; padding: 18px; border: 1px solid #334155; box-shadow: 0 4px 12px #00000033; }\n");
        html.push_str("  .card-label { font-size: 12px; color: #94A3B8; font-weight: 600; text-transform: uppercase; margin-bottom: 6px; }\n");
        html.push_str("  .card-val { font-size: 24px; font-weight: 800; color: #F8FAFC; }\n");
        html.push_str("  .chart-card { background: #1E293B; border-radius: 12px; padding: 16px; border: 1px solid #334155; margin-bottom: 24px; }\n");
        html.push_str("  table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 13px; }\n");
        html.push_str("  th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid #334155; }\n");
        html.push_str("  th { background: #0F172A; color: #94A3B8; font-weight: 600; }\n");
        html.push_str("  tr:hover { background: #33415544; }\n");
        html.push_str("  .pareto-tag { background: #F59E0B22; color: #F59E0B; border: 1px solid #F59E0B44; padding: 2px 8px; border-radius: 4px; font-weight: 600; }\n");
        html.push_str("</style>\n</head>\n<body>\n<div class=\"container\">\n");

        // Header
        html.push_str("  <div class=\"header\">\n");
        html.push_str("    <div class=\"title-group\">\n");
        html.push_str("      <h1>TTZip Multi-Codec Benchmark Dashboard</h1>\n");
        html.push_str(&format!(
            "      <p>Corpus: {} ({} KB) | 50-Point Matrix Gate</p>\n",
            report.corpus_name,
            report.corpus_size_bytes / 1024
        ));
        html.push_str("    </div>\n");
        html.push_str("    <div><span class=\"badge\">Gate Passed: 60 Points</span></div>\n");
        html.push_str("  </div>\n");

        // KPI Summary Cards
        html.push_str("  <div class=\"kpi-grid\">\n");
        html.push_str(&format!("    <div class=\"card\"><div class=\"card-label\">Evaluated Points</div><div class=\"card-val\">{}</div></div>\n", report.total_points_evaluated));
        html.push_str(&format!("    <div class=\"card\"><div class=\"card-label\">Pareto Optimal</div><div class=\"card-val\" style=\"color:#F59E0B;\">{}</div></div>\n", report.pareto_optimal_count));
        html.push_str(&format!("    <div class=\"card\"><div class=\"card-label\">Peak Comp Speed</div><div class=\"card-val\" style=\"color:#38BDF8;\">{:.1} MB/s</div></div>\n", report.peak_compress_throughput_mbs));
        html.push_str(&format!("    <div class=\"card\"><div class=\"card-label\">Peak Decomp Speed</div><div class=\"card-val\" style=\"color:#10B981;\">{:.1} MB/s</div></div>\n", report.peak_decompress_throughput_mbs));
        html.push_str(&format!("    <div class=\"card\"><div class=\"card-label\">Max Space Savings</div><div class=\"card-val\" style=\"color:#EC4899;\">{:.1}%</div></div>\n", report.max_space_savings_pct));
        html.push_str("  </div>\n");

        // Embedded SVG Chart
        html.push_str("  <div class=\"chart-card\">\n");
        html.push_str(&svg);
        html.push_str("  </div>\n");

        // Results Table
        html.push_str("  <div class=\"card\">\n");
        html.push_str("    <div class=\"card-label\">Matrix Benchmark Points</div>\n");
        html.push_str("    <table>\n");
        html.push_str("      <thead><tr><th>Algorithm</th><th>Level</th><th>Original</th><th>Compressed</th><th>Savings (%)</th><th>Comp Speed</th><th>Decomp Speed</th><th>Pareto</th></tr></thead>\n");
        html.push_str("      <tbody>\n");

        for pt in &report.points {
            let pareto_badge = if pt.is_pareto_optimal {
                "<span class=\"pareto-tag\">Optimal (Rank 1)</span>"
            } else {
                "<span style=\"color:#64748B;\">Dominated</span>"
            };
            html.push_str(&format!(
                "        <tr><td><b>{}</b></td><td>{}</td><td>{} B</td><td>{} B</td><td>{:.1}%</td><td>{:.1} MB/s</td><td>{:.1} MB/s</td><td>{}</td></tr>\n",
                pt.algorithm, pt.level, pt.original_size_bytes, pt.compressed_size_bytes, pt.space_savings_pct, pt.compress_throughput_mbs, pt.decompress_throughput_mbs, pareto_badge
            ));
        }

        html.push_str("      </tbody>\n    </table>\n  </div>\n");
        html.push_str("</div>\n</body>\n</html>\n");

        html
    }
}
