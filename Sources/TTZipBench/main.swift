// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

func printHelp() {
    print("""
    OVERVIEW: TTZip Benchmark & Compression Telemetry CLI (Rust Native C-ABI)

    USAGE: ttzip-bench <subcommand> [options]

    SUBCOMMANDS:
      matrix        Execute multi-engine in-memory benchmark matrix (libdeflate, zstd, lz4, lzfse, snappy, brotli, bzip2)
      gate          Run automated regression and hardware stability checks for CI/CD
      plot          Generate interactive Pareto frontier charts (SVG / HTML dashboard)
      help          Display this help message

    OPTIONS (matrix & plot):
      --json-out <path>    Write structured telemetry report to JSON file
      --svg-out <path>     Write interactive vector SVG Pareto chart
      --html-out <path>    Write self-contained Zen UI HTML dashboard
    """)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, command != "--help", command != "-h", command != "help" else {
    printHelp()
    exit(0)
}

var jsonOut: String?
var svgOut: String?
var htmlOut: String?
var idx = 1
while idx < args.count {
    if args[idx] == "--json-out", idx + 1 < args.count {
        jsonOut = args[idx + 1]
        idx += 2
    } else if args[idx] == "--svg-out", idx + 1 < args.count {
        svgOut = args[idx + 1]
        idx += 2
    } else if args[idx] == "--html-out", idx + 1 < args.count {
        htmlOut = args[idx + 1]
        idx += 2
    } else {
        idx += 1
    }
}

switch command {
case "matrix", "plot":
    print("⚡️ Executing TTZip Multi-Engine Matrix Benchmark (Rust C-ABI)...")
    let bufSize = 512 * 1024
    let jsonBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
    defer { jsonBuffer.deallocate() }

    let written = ttzip_rust_bench_run_matrix(0, jsonBuffer, bufSize)
    guard written > 0 else {
        print("❌ Benchmark matrix execution failed with status: \(written)")
        exit(1)
    }

    let jsonString = String(cString: jsonBuffer)
    if let jsonPath = jsonOut {
        try? jsonString.write(toFile: jsonPath, atomically: true, encoding: .utf8)
        print("📄 Telemetry JSON report exported to: \(jsonPath)")
    }

    if let svgPath = svgOut, let svgPtr = ttzip_rust_bench_generate_svg_pareto(0, 960, 480) {
        let svgStr = String(cString: svgPtr)
        ttzip_rust_bench_free_string(svgPtr)
        try? svgStr.write(toFile: svgPath, atomically: true, encoding: .utf8)
        print("📈 Interactive SVG Pareto chart exported to: \(svgPath)")
    }

    if let htmlPath = htmlOut, let htmlPtr = ttzip_rust_bench_generate_html_dashboard(0) {
        let htmlStr = String(cString: htmlPtr)
        ttzip_rust_bench_free_string(htmlPtr)
        try? htmlStr.write(toFile: htmlPath, atomically: true, encoding: .utf8)
        print("🌐 Self-contained Zen UI HTML Dashboard exported to: \(htmlPath)")
    }
    print("✅ Matrix benchmark completed successfully.")
    exit(0)

case "gate":
    print("⚡️ Running TTZip Automated Benchmark Gate (Rust Native C-ABI)...")
    let status = ttzip_rust_bench_run_gate()
    if status == 0 {
        print("✅ GATE PASSED: All hardware & codec invariants verified.")
        exit(0)
    } else {
        print("❌ GATE FAILED with status code: \(status)")
        exit(70)
    }

default:
    print("❌ Unknown subcommand: '\(command)'\n")
    printHelp()
    exit(64)
}
