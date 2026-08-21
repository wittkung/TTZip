// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

func printHelp() {
    print("""
    OVERVIEW: TTZip Benchmark & Compression Telemetry CLI

    USAGE: ttzip-bench <subcommand> [options]

    SUBCOMMANDS:
      matrix        Execute multi-engine in-memory benchmark matrix (libdeflate, zstd, lz4, lzfse, snappy, brotli, bzip2)
      gate          Run automated regression and CV stability checks for CI/CD
      plot          Generate interactive Pareto frontier charts (SVG, HTML, Terminal Braille)
      diff          Compare two benchmark telemetry JSON reports and flag regressions
      delta         Run binary size and compression ratio delta audit
      help          Display this help message

    OPTIONS (matrix & plot):
      --json-out <path>    Write structured telemetry report to JSON file
      --svg-out <path>     Write interactive vector SVG Pareto chart
      --html-out <path>    Write self-contained Zen UI HTML dashboard
      --json-in <path>     (plot) Load benchmark data from existing JSON file instead of re-running

    OPTIONS (diff):
      --fail-pct <num>     Threshold % for hard CI failure (default: 5.0)
      --threshold-pct <num> Threshold % for warning alert (default: 2.0)

    OPTIONS (delta):
      --markdown-out <path> Write Markdown delta report
      --json-out <path>     Write JSON delta summary
      --fail-pct <num>      Allowed binary delta threshold (default: 5.0)
    """)
}

// MARK: - Top-Level CLI Entry Point

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, command != "--help", command != "-h", command != "help" else {
    printHelp()
    exit(0)
}

switch command {
case "matrix":
    BenchCommandRunner.runMatrix(args: args)

case "gate":
    BenchCommandRunner.runGate(args: args)

case "plot":
    BenchCommandRunner.runPlot(args: args)

case "diff":
    BenchCommandRunner.runDiff(args: args)

case "delta":
    BenchCommandRunner.runDelta(args: args)

default:
    print("❌ Unknown subcommand: '\(command)'\n")
    printHelp()
    exit(64) // EX_USAGE
}
