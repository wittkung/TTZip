#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.

import sys
import os
import math
import json
import re
import argparse
from datetime import datetime, timezone

# ============================================================================
# 1. Zero-Dependency Numerical & Statistical Mathematics
# ============================================================================

def sample_mean(data):
    if not data:
        return 0.0
    return sum(data) / len(data)

def sample_std(data, mean_val=None):
    n = len(data)
    if n < 2:
        return 0.0
    if mean_val is None:
        mean_val = sample_mean(data)
    variance = sum((x - mean_val) ** 2 for x in data) / (n - 1)
    return math.sqrt(max(0.0, variance))

def log_gamma(x):
    return math.lgamma(x)

def betacf(a, b, x, max_iter=200, eps=1e-14):
    """Evaluates regularized incomplete beta fraction using Lentz method."""
    qab = a + b
    qap = a + 1.0
    qam = a - 1.0
    c = 1.0
    d = 1.0 - qab * x / qap
    if abs(d) < 1e-30:
        d = 1e-30
    d = 1.0 / d
    h = d
    for m in range(1, max_iter + 1):
        m2 = 2 * m
        # Even step
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        if abs(d) < 1e-30:
            d = 1e-30
        c = 1.0 + aa / c
        if abs(c) < 1e-30:
            c = 1e-30
        d = 1.0 / d
        h *= d * c
        # Odd step
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        if abs(d) < 1e-30:
            d = 1e-30
        c = 1.0 + aa / c
        if abs(c) < 1e-30:
            c = 1e-30
        d = 1.0 / d
        del_val = d * c
        h *= del_val
        if abs(del_val - 1.0) < eps:
            break
    return h

def incbeta(a, b, x):
    """Returns regularized incomplete beta function I_x(a, b)."""
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 1.0
    bt = math.exp(log_gamma(a + b) - log_gamma(a) - log_gamma(b) + a * math.log(x) + b * math.log(1.0 - x))
    if x < (a + 1.0) / (a + b + 2.0):
        return bt * betacf(a, b, x) / a
    else:
        return 1.0 - bt * betacf(b, a, 1.0 - x) / b

def student_t_pvalue(t_stat, df):
    """Computes two-tailed p-value for Student t distribution."""
    if df <= 0:
        return 1.0
    t_sq = t_stat * t_stat
    x = df / (df + t_sq)
    try:
        # P(|T| > |t|) = I_{df / (df + t^2)}(df/2, 1/2)
        p = incbeta(df / 2.0, 0.5, x)
        return min(1.0, max(0.0, p))
    except Exception:
        # Fallback to Gaussian approximation for large df or edge cases
        return math.erfc(abs(t_stat) / math.sqrt(2.0))

def welch_t_test(data_a, data_b):
    """Performs Welch unequal-variance two-sample t-test."""
    n_a = len(data_a)
    n_b = len(data_b)
    if n_a < 2 or n_b < 2:
        return 0.0, 1.0, 1.0
    
    mean_a = sample_mean(data_a)
    mean_b = sample_mean(data_b)
    s_a = sample_std(data_a, mean_a)
    s_b = sample_std(data_b, mean_b)
    
    var_a = (s_a ** 2) / n_a
    var_b = (s_b ** 2) / n_b
    denom = math.sqrt(var_a + var_b)
    
    if denom < 1e-12:
        return 0.0, float(n_a + n_b - 2), 1.0
    
    t_stat = (mean_b - mean_a) / denom
    
    # Welch-Satterthwaite degrees of freedom
    num_df = (var_a + var_b) ** 2
    den_df = ((var_a ** 2) / (n_a - 1)) + ((var_b ** 2) / (n_b - 1))
    df = num_df / den_df if den_df > 1e-15 else 1.0
    
    p_val = student_t_pvalue(t_stat, df)
    return t_stat, df, p_val

# ============================================================================
# 2. Benchmark Log Parser
# ============================================================================

def parse_benchmark_log(log_text):
    """Parses ttzip_benchmark_runner text output into flat dictionary of metrics."""
    metrics = {}
    
    # 1. Codec Throughput: Codec (Level) | Ratio | Comp (MB/s) | Comp CPB | Decomp (MB/s) | Decomp CPB
    codec_pattern = re.compile(r"^\s*([A-Za-z0-9\(\)\s\.\-_]+?)\s*\|\s*([0-9\.]+\s*%)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+)", re.MULTILINE)
    for match in codec_pattern.finditer(log_text):
        name = match.group(1).strip().lstrip("-").strip()
        if not name or "Codec" in name or "Level" in name:
            continue
        comp_mbs = float(match.group(3))
        comp_cpb = float(match.group(4))
        decomp_mbs = float(match.group(5))
        decomp_cpb = float(match.group(6))
        
        metrics[f"Codec_{name}_Comp_MBs"] = ("codec_throughput", f"{name} (Compress)", "MB/s", comp_mbs, True) # True: higher is better
        metrics[f"Codec_{name}_Comp_CPB"] = ("codec_throughput", f"{name} (Comp CPB)", "CPB", comp_cpb, False) # False: lower is better
        metrics[f"Codec_{name}_Decomp_MBs"] = ("codec_throughput", f"{name} (Decompress)", "MB/s", decomp_mbs, True)
        metrics[f"Codec_{name}_Decomp_CPB"] = ("codec_throughput", f"{name} (Decomp CPB)", "CPB", decomp_cpb, False)
        
    # 2. Checksum Throughput: Kernel | Speed (GB/s) | Speed (MB/s) | Cycles/Byte
    chk_pattern = re.compile(r"^\s*([A-Za-z0-9\(\)\s\.\-_\/]+?)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+)", re.MULTILINE)
    for match in chk_pattern.finditer(log_text):
        name = match.group(1).strip().lstrip("-").strip()
        if not name or "Algorithm" in name or "Kernel" in name or "Container" in name:
            continue
        gbs = float(match.group(2))
        cpb = float(match.group(4))
        metrics[f"Checksum_{name}_GBs"] = ("checksum_throughput", f"{name} (Throughput)", "GB/s", gbs, True)
        metrics[f"Checksum_{name}_CPB"] = ("checksum_throughput", f"{name} (Cycles/Byte)", "CPB", cpb, False)

    # 3. Container Format: Container | Pack (MB/s) | Extract (MB/s) | Ratio | Peak RSS
    cnt_pattern = re.compile(r"^\s*([A-Za-z0-9\(\)\s\.\-_\/]+?)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+)\s*\|\s*([0-9\.]+\s*%)\s*\|\s*([0-9\.]+)\s*MB", re.MULTILINE)
    for match in cnt_pattern.finditer(log_text):
        name = match.group(1).strip().lstrip("-").strip()
        if not name or "Container" in name or "Format" in name:
            continue
        pack_mbs = float(match.group(2))
        ext_mbs = float(match.group(3))
        rss_mb = float(match.group(5))
        metrics[f"Container_{name}_Pack_MBs"] = ("container_io", f"{name} (Pack)", "MB/s", pack_mbs, True)
        metrics[f"Container_{name}_Extract_MBs"] = ("container_io", f"{name} (Extract)", "MB/s", ext_mbs, True)
        metrics[f"Container_{name}_Peak_RSS"] = ("peak_rss", f"{name} (Peak RSS)", "MB", rss_mb, False)

    return metrics

# ============================================================================
# 3. Aggregation & Report Generation
# ============================================================================

def process_benchmark_runs(base_runs_logs, cand_runs_logs, meta, regression_threshold=0.03):
    """Aggregates multi-run logs and computes statistical delta."""
    base_samples = {}
    cand_samples = {}
    metric_meta = {} # key -> (category, display_name, unit, higher_is_better)
    
    for log in base_runs_logs:
        parsed = parse_benchmark_log(log)
        for k, (cat, disp, unit, val, hib) in parsed.items():
            base_samples.setdefault(k, []).append(val)
            metric_meta[k] = (cat, disp, unit, hib)
            
    for log in cand_runs_logs:
        parsed = parse_benchmark_log(log)
        for k, (cat, disp, unit, val, hib) in parsed.items():
            cand_samples.setdefault(k, []).append(val)
            metric_meta[k] = (cat, disp, unit, hib)
            
    common_keys = sorted(set(base_samples.keys()) & set(cand_samples.keys()))
    
    evaluated_metrics = []
    speedups = 0
    regressions = 0
    noise = 0
    
    thresh_pct = max(1.0, regression_threshold * 100.0)
    for k in common_keys:
        cat, disp, unit, hib = metric_meta[k]
        s_a = base_samples[k]
        s_b = cand_samples[k]
        
        m_a = sample_mean(s_a)
        std_a = sample_std(s_a, m_a)
        m_b = sample_mean(s_b)
        std_b = sample_std(s_b, m_b)
        
        delta_pct = ((m_b - m_a) / m_a * 100.0) if m_a != 0 else 0.0
        t_stat, df, p_val = welch_t_test(s_a, s_b)
        
        is_improved = (delta_pct > thresh_pct) if hib else (delta_pct < -thresh_pct)
        is_regressed = (delta_pct < -thresh_pct) if hib else (delta_pct > thresh_pct)
        
        if p_val < 0.05 and is_improved:
            verdict = "SIGNIFICANT_SPEEDUP"
            speedups += 1
        elif p_val < 0.05 and is_regressed:
            verdict = "SIGNIFICANT_REGRESSION"
            regressions += 1
        else:
            verdict = "NOISE_FLAT"
            noise += 1
            
        evaluated_metrics.append({
            "key": k,
            "category": cat,
            "metric_name": disp,
            "unit": unit,
            "higher_is_better": hib,
            "baseline_mean": round(m_a, 2),
            "baseline_std": round(std_a, 2),
            "candidate_mean": round(m_b, 2),
            "candidate_std": round(std_b, 2),
            "delta_percent": round(delta_pct, 2),
            "t_statistic": round(t_stat, 3),
            "degrees_of_freedom": round(df, 2),
            "p_value": round(p_val, 4),
            "verdict": verdict
        })
        
    overall_verdict = "REGRESSION_DETECTED" if regressions > 0 else "PASSED_NO_REGRESSION"
    
    report_json = {
        "session": {
            "session_id": meta.get("session_id", "ab_session"),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "baseline_ref": meta.get("baseline_ref", "unknown"),
            "baseline_commit": meta.get("baseline_commit", "unknown"),
            "candidate_ref": meta.get("candidate_ref", "unknown"),
            "candidate_commit": meta.get("candidate_commit", "unknown"),
            "sample_runs": len(base_runs_logs),
            "platform": meta.get("platform", "macOS arm64"),
            "overall_verdict": overall_verdict
        },
        "metrics": evaluated_metrics,
        "summary": {
            "total_metrics_evaluated": len(evaluated_metrics),
            "speedups_count": speedups,
            "regressions_count": regressions,
            "noise_count": noise
        }
    }
    
    return report_json

# ============================================================================
# 4. Terminal ANSI & Markdown Printers
# ============================================================================

def print_terminal_table(report):
    session = report["session"]
    metrics = report["metrics"]
    summary = report["summary"]
    
    print("\n\033[1;36m================================================================================\033[0m")
    print(f"\033[1;36m  TTZip Git Worktree A/B Statistical Benchmark Telemetry (Runs = {session['sample_runs']})\033[0m")
    print(f"  Baseline  (A): \033[1;33m{session['baseline_ref']}\033[0m ({session['baseline_commit'][:8]})")
    print(f"  Candidate (B): \033[1;32m{session['candidate_ref']}\033[0m ({session['candidate_commit'][:8]})")
    print("\033[1;36m================================================================================\033[0m")
    print(f"{'Metric / Algorithm':<34} | {'Baseline (Mean ± σ)':<18} | {'Candidate (Mean ± σ)':<18} | {'Delta (%)':<10} | {'p-val':<7} | {'Verdict'}")
    print("-" * 105)
    
    for m in metrics:
        hib = m["higher_is_better"]
        dp = m["delta_percent"]
        pval = m["p_value"]
        verdict = m["verdict"]
        
        base_str = f"{m['baseline_mean']} ± {m['baseline_std']} {m['unit']}"
        cand_str = f"{m['candidate_mean']} ± {m['candidate_std']} {m['unit']}"
        delta_str = f"{dp:+.2f} %"
        pval_str = f"{pval:.3f}"
        
        if verdict == "SIGNIFICANT_SPEEDUP":
            c_tag = "\033[1;32m⭐ SPEEDUP\033[0m"
            delta_disp = f"\033[1;32m{delta_str:<10}\033[0m"
        elif verdict == "SIGNIFICANT_REGRESSION":
            c_tag = "\033[1;31m❌ REGRESS\033[0m"
            delta_disp = f"\033[1;31m{delta_str:<10}\033[0m"
        else:
            c_tag = "\033[0;37m~ NOISE\033[0m"
            delta_disp = f"\033[0;37m{delta_str:<10}\033[0m"
            
        print(f"{m['metric_name']:<34} | {base_str:<18} | {cand_str:<18} | {delta_disp} | {pval_str:<7} | {c_tag}")
        
    print("-" * 105)
    v_color = "\033[1;32m" if session["overall_verdict"] == "PASSED_NO_REGRESSION" else "\033[1;31m"
    print(f"Summary: {summary['total_metrics_evaluated']} Evaluated | \033[1;32m{summary['speedups_count']} Speedups\033[0m | \033[1;31m{summary['regressions_count']} Regressions\033[0m | \033[0;37m{summary['noise_count']} Noise\033[0m | {v_color}{session['overall_verdict']}\033[0m")
    print("\033[1;36m================================================================================\033[0m\n")

def export_markdown_report(report, out_path):
    session = report["session"]
    metrics = report["metrics"]
    summary = report["summary"]
    
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    
    lines = [
        "# ⚡️ TTZip Git Worktree A/B 基准对标与统计差分报告",
        "",
        f"> **生成时间**: `{session['timestamp']}`  ",
        f"> **基准版本 (Baseline A)**: `{session['baseline_ref']}` (`{session['baseline_commit'][:10]}`)  ",
        f"> **候选版本 (Candidate B)**: `{session['candidate_ref']}` (`{session['candidate_commit'][:10]}`)  ",
        f"> **采样轮数**: $N = {session['sample_runs']}$ (交替交叉采样)  ",
        f"> **统计检验**: Welch Unequal-Variance t-Test ($\alpha = 0.05$)  ",
        f"> **总体判定**: **{session['overall_verdict']}**",
        "",
        "---",
        "",
        "## 1. 核心指标统计显著性对标矩阵",
        "",
        "| 评估指标 / 算法 | 基准版本 (Mean ± σ) | 候选版本 (Mean ± σ) | 相对变化 (Δ%) | p-value | 统计学判定 |",
        "| :--- | ---: | ---: | :---: | :---: | :---: |"
    ]
    
    for m in metrics:
        base_str = f"{m['baseline_mean']} ± {m['baseline_std']} {m['unit']}"
        cand_str = f"{m['candidate_mean']} ± {m['candidate_std']} {m['unit']}"
        delta_str = f"{m['delta_percent']:+.2f} %"
        pval_str = f"{m['p_value']:.4f}"
        
        if m["verdict"] == "SIGNIFICANT_SPEEDUP":
            v_str = "🟢 **显著提速 (Gain)**"
            delta_str = f"**{delta_str}**"
        elif m["verdict"] == "SIGNIFICANT_REGRESSION":
            v_str = "🔴 **显著回退 (Regression)**"
            delta_str = f"**{delta_str}**"
        else:
            v_str = "⚪ 正常抖动 (Noise)"
            
        lines.append(f"| {m['metric_name']} | {base_str} | {cand_str} | {delta_str} | {pval_str} | {v_str} |")
        
    lines.extend([
        "",
        "---",
        "",
        "## 2. 统计摘要与回归判定",
        f"- **评估指标总数**: {summary['total_metrics_evaluated']}",
        f"- **显著提速项数**: {summary['speedups_count']}",
        f"- **显著回退项数**: {summary['regressions_count']}",
        f"- **统计无关抖动项数**: {summary['noise_count']}",
        f"- **最终门禁状态**: **{session['overall_verdict']}**"
    ])
    
    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")

# ============================================================================
# 5. CLI Entrypoint
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="TTZip Statistical Delta Benchmark Engine")
    parser.add_argument("--base-logs", nargs="+", required=True, help="Paths to baseline benchmark stdout logs")
    parser.add_argument("--cand-logs", nargs="+", required=True, help="Paths to candidate benchmark stdout logs")
    parser.add_argument("--meta", type=str, default="{}", help="JSON metadata dictionary")
    parser.add_argument("--json-out", type=str, default="", help="Output path for JSON report")
    parser.add_argument("--md-out", type=str, default="", help="Output path for Markdown report")
    parser.add_argument("--threshold", type=float, default=0.03, help="Allowed regression threshold fraction (e.g. 0.03)")
    
    args = parser.parse_args()
    
    base_texts = []
    for p in args.base_logs:
        with open(p, "r") as f:
            base_texts.append(f.read())
            
    cand_texts = []
    for p in args.cand_logs:
        with open(p, "r") as f:
            cand_texts.append(f.read())
            
    meta = json.loads(args.meta) if args.meta else {}
    
    report = process_benchmark_runs(base_texts, cand_texts, meta, args.threshold)
    
    print_terminal_table(report)
    
    if args.json_out:
        os.makedirs(os.path.dirname(os.path.abspath(args.json_out)), exist_ok=True)
        with open(args.json_out, "w") as f:
            json.dump(report, f, indent=2)
            
    if args.md_out:
        export_markdown_report(report, args.md_out)
        
    if report["summary"]["regressions_count"] > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
