#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TTZip 自动化性能对比与零倒退审计工具 (Automated Zero-Regression Performance Auditor)
作用：
1. 自动提取最新一次 Benchmark 跑分与上一次（或指定 Baseline）跑分；
2. 逐项比对所有格式、场景、压缩级别与加密状态下的压缩/解压吞吐 (MB/s)；
3. 输出结构化对比表，严格双层判定：
   - 🟢 GAIN (> +3.0%)
   - ⚪ FLAT (±3.0% 以内)
   - 🟡 WARNING (-10.0% <= delta < -3.0%)
   - 🔴 CRITICAL REGRESSION (< -10.0%)
4. 当检测到任何 > 10.0% 的严重倒退时，返回退出码 1 阻断流水线；
5. 生成 Markdown 格式审计报告保存至 docs/benchmarks/latest_regression_audit.md
"""

import sys
import os
import glob
import json
import argparse
from datetime import datetime

def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def run_audit(baseline_path=None, latest_path=None, output_md_path="docs/benchmarks/latest_regression_audit.md", strict_mode=False):
    report_files = sorted(glob.glob("docs/benchmarks/benchmark_report_*.json"))
    if len(report_files) < 1:
        print("❌ 未找到任何 benchmark_report_*.json 文件，请先运行基准测试！")
        return 2

    if latest_path is None:
        latest_path = report_files[-1]
    
    if baseline_path is None:
        peak_matrix = "docs/benchmarks/peak_performance_matrix.json"
        if os.path.exists(peak_matrix):
            baseline_path = peak_matrix
        else:
            old_peak = "docs/benchmarks/benchmark_report_2026-08-15_071939.json"
            if os.path.exists(old_peak):
                baseline_path = old_peak
            elif len(report_files) >= 2:
                baseline_path = report_files[-2]
            else:
                baseline_path = latest_path

    print(f"================================================================================")
    print(f"📊 TTZip 自动化性能比对与零倒退审计报告 (Double-Tier Regression Auditor)")
    print(f"🔹 基准报告 (Before): {baseline_path}")
    print(f"🔹 最新报告 (After) : {latest_path}")
    print(f"🔹 严格模式 (Strict): {'开启 (>3% 阻断)' if strict_mode else '默认 (>10% 阻断)'}")
    print(f"================================================================================\n")

    base_data = load_json(baseline_path)
    late_data = load_json(latest_path)

    if isinstance(base_data, dict):
        base_map = {}
        for k, v in base_data.items():
            base_map[(v["formatRaw"], v["dimensionName"], v["levelRaw"], v.get("isEncrypted", False))] = {
                "ttzipCompressMBs": v.get("peakCompressMBs", 0.0),
                "ttzipExtractMBs": v.get("peakExtractMBs", 0.0)
            }
    else:
        base_map = {}
        for d in base_data:
            c = d.get("max_comp", d.get("ttzipCompressMBs", 0.0))
            e = d.get("max_extract", d.get("ttzipExtractMBs", 0.0))
            base_map[(d["format"], d["dimensionName"], d["level"], d.get("isEncrypted", False))] = {
                "ttzipCompressMBs": c,
                "ttzipExtractMBs": e
            }

    late_map = {(d["format"], d["dimensionName"], d["level"], d.get("isEncrypted", False)): d for d in late_data}

    hdr_fmt = "{:<8} | {:<25} | {:<4} | {:<5} | {:>9} | {:>9} | {:>8} | {:>9} | {:>9} | {:>8}"
    header_str = hdr_fmt.format("格式", "场景/维度", "级别", "加密", "压缩前", "压缩后", "压缩变化", "解压前", "解压后", "解压变化")
    separator_str = "-" * len(header_str)

    print(header_str)
    print(separator_str)

    gains = []
    warnings = []
    critical_regressions = []
    flats = []
    all_rows = []

    for key in sorted(late_map.keys()):
        fmt, dim, lvl, is_enc = key
        a = late_map[key]
        b = base_map.get(key, {})

        enc_label = "AES" if is_enc else "无"
        
        bc = b.get("ttzipCompressMBs", 0.0)
        ac = a.get("ttzipCompressMBs", 0.0)
        c_diff = ((ac - bc) / bc * 100) if bc > 0 else 0.0

        bd = b.get("ttzipExtractMBs", 0.0)
        ad = a.get("ttzipExtractMBs", 0.0)
        d_diff = ((ad - bd) / bd * 100) if bd > 0 else 0.0

        c_diff_str = f"+{c_diff:5.1f}%" if c_diff >= 0 else f"{c_diff:5.1f}%"
        d_diff_str = f"+{d_diff:5.1f}%" if d_diff >= 0 else f"{d_diff:5.1f}%"

        row_str = hdr_fmt.format(fmt, dim, f"L{lvl}", enc_label, f"{bc:.1f}", f"{ac:.1f}", c_diff_str, f"{bd:.1f}", f"{ad:.1f}", d_diff_str)
        print(row_str)

        row_data = {
            "format": fmt, "dim": dim, "level": lvl, "enc": enc_label,
            "bc": bc, "ac": ac, "c_diff": c_diff, "c_diff_str": c_diff_str,
            "bd": bd, "ad": ad, "d_diff": d_diff, "d_diff_str": d_diff_str
        }
        all_rows.append(row_data)

        # 压缩判定
        if bc > 0:
            if c_diff > 3.0:
                gains.append((fmt, dim, lvl, enc_label, "压缩", bc, ac, c_diff))
            elif c_diff < -10.0:
                critical_regressions.append((fmt, dim, lvl, enc_label, "压缩", bc, ac, c_diff))
            elif c_diff < -3.0:
                warnings.append((fmt, dim, lvl, enc_label, "压缩", bc, ac, c_diff))
            else:
                flats.append((fmt, dim, lvl, enc_label, "压缩", bc, ac, c_diff))

        # 解压判定
        if bd > 0:
            if d_diff > 3.0:
                gains.append((fmt, dim, lvl, enc_label, "解压", bd, ad, d_diff))
            elif d_diff < -10.0:
                critical_regressions.append((fmt, dim, lvl, enc_label, "解压", bd, ad, d_diff))
            elif d_diff < -3.0:
                warnings.append((fmt, dim, lvl, enc_label, "解压", bd, ad, d_diff))
            else:
                flats.append((fmt, dim, lvl, enc_label, "解压", bd, ad, d_diff))

    print("\n" + "=" * 80)
    print(f"📊 审计统计结论汇总:")
    print(f"  🟢 性能提升项数 (> +3.0%): {len(gains)}")
    print(f"  ⚪ 性能持平项数 (±3.0%以内): {len(flats)}")
    print(f"  🟡 性能轻微倒退告警 (-3.0% ~ -10.0%): {len(warnings)}")
    print(f"  🔴 严重性能倒退阻断 (< -10.0%): {len(critical_regressions)}")
    print("=" * 80)

    if gains:
        print("\n【🟢 核心提升明细】:")
        for g in gains:
            print(f"  + [{g[0]}] {g[1]} L{g[2]} ({g[3]}) {g[4]}: {g[5]:.1f} -> {g[6]:.1f} MB/s ({g[7]:+.1f}%)")

    if warnings:
        print("\n【🟡 轻微倒退告警明细 (-3.0% ~ -10.0%)】:")
        for w in warnings:
            print(f"  ~ [{w[0]}] {w[1]} L{w[2]} ({w[3]}) {w[4]}: {w[5]:.1f} -> {w[6]:.1f} MB/s ({w[7]:.1f}%)")

    if critical_regressions:
        print("\n【🔴 严重倒退阻断明细 (< -10.0%)】:")
        for r in critical_regressions:
            print(f"  ❌ [{r[0]}] {r[1]} L{r[2]} ({r[3]}) {r[4]}: {r[5]:.1f} -> {r[6]:.1f} MB/s ({r[7]:.1f}%)")
    else:
        print("\n✅ 零严重性能倒退 (Zero Critical Regression)！所有指标均在安全范围以内。")

    # 生成 Markdown 审计报告
    os.makedirs(os.path.dirname(output_md_path), exist_ok=True)
    with open(output_md_path, "w", encoding="utf-8") as f:
        f.write("# TTZip 性能比对与零倒退审计报告\n\n")
        f.write(f"- **审计时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"- **基准版本 (Before)**: `{baseline_path}`\n")
        f.write(f"- **最新版本 (After)**: `{latest_path}`\n\n")
        
        f.write("## 一、 统计摘要\n\n")
        f.write(f"- 🟢 **提升项数 (> +3.0%)**: {len(gains)}\n")
        f.write(f"- ⚪ **持平项数 (±3.0% 以内)**: {len(flats)}\n")
        f.write(f"- 🟡 **轻微倒退告警 (-3.0% ~ -10.0%)**: {len(warnings)}\n")
        f.write(f"- 🔴 **严重倒退阻断 (< -10.0%)**: {len(critical_regressions)}\n\n")

        if critical_regressions:
            f.write("## 二、 🔴 严重性能倒退阻断列表 (< -10.0%)\n\n")
            f.write("| 格式 | 场景 | 级别 | 加密 | 操作 | 优化前 (MB/s) | 优化后 (MB/s) | 变动比例 |\n")
            f.write("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n")
            for r in critical_regressions:
                f.write(f"| {r[0]} | {r[1]} | L{r[2]} | {r[3]} | {r[4]} | {r[5]:.1f} | {r[6]:.1f} | **{r[7]:.1f}%** |\n")
            f.write("\n")

        if warnings:
            f.write("## 三、 🟡 性能轻微倒退告警列表 (-3.0% ~ -10.0%)\n\n")
            f.write("| 格式 | 场景 | 级别 | 加密 | 操作 | 优化前 (MB/s) | 优化后 (MB/s) | 变动比例 |\n")
            f.write("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n")
            for w in warnings:
                f.write(f"| {w[0]} | {w[1]} | L{w[2]} | {w[3]} | {w[4]} | {w[5]:.1f} | {w[6]:.1f} | **{w[7]:.1f}%** |\n")
            f.write("\n")

        f.write("## 四、 全量维度性能逐项对比表\n\n")
        f.write("| 格式 | 场景/维度 | 级别 | 加密 | 压缩前 (MB/s) | 压缩后 (MB/s) | 压缩增益 | 解压前 (MB/s) | 解压后 (MB/s) | 解压增益 |\n")
        f.write("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n")
        for row in all_rows:
            f.write(f"| {row['format']} | {row['dim']} | L{row['level']} | {row['enc']} | {row['bc']:.1f} | {row['ac']:.1f} | {row['c_diff_str']} | {row['bd']:.1f} | {row['ad']:.1f} | {row['d_diff_str']} |\n")

    print(f"\n📄 完整审计报告已持久化至: {output_md_path}")
    
    if len(critical_regressions) > 0:
        print(f"\n❌ [AUDIT FAILED] 存在 {len(critical_regressions)} 项严重性能倒退 (> 10.0%)，阻断流水线！")
        return 1
    
    if strict_mode and len(warnings) > 0:
        print(f"\n❌ [STRICT AUDIT FAILED] 严格模式下存在 {len(warnings)} 项轻微性能倒退 (> 3.0%)，阻断流水线！")
        return 3

    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TTZip Automated Performance Regression Auditor")
    parser.add_argument("baseline", nargs="?", default=None, help="Baseline benchmark JSON file path")
    parser.add_argument("latest", nargs="?", default=None, help="Latest benchmark JSON file path")
    parser.add_argument("--strict", action="store_true", help="Enable strict mode (fail on any regression > 3.0%%)")
    parser.add_argument("--output", default="docs/benchmarks/latest_regression_audit.md", help="Output markdown path")
    args = parser.parse_args()

    sys.exit(run_audit(args.baseline, args.latest, args.output, args.strict))
