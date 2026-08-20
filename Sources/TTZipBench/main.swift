// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import TTZipCore
import CTTZipBridge

func printHelp() {
    print("""
    OVERVIEW: TTZip Benchmark & Compression Telemetry CLI

    USAGE: ttzip-bench <subcommand> [options]

    SUBCOMMANDS:
      matrix        Execute the 50-point in-memory codec benchmark matrix
      gate          Run automated regression and CV stability checks for CI/CD
      plot          Generate Pareto frontier charts
      help          Display this help message

    OPTIONS (matrix):
      --json-out <path>    Write structured telemetry report to JSON file
    """)
}

func padLeft(_ s: String, _ length: Int) -> String {
    if s.count >= length { return s }
    return String(repeating: " ", count: length - s.count) + s
}

func padRight(_ s: String, _ length: Int) -> String {
    if s.count >= length { return s }
    return s + String(repeating: " ", count: length - s.count)
}

func formatDuration(_ durationNs: Double) -> String {
    let micros = durationNs / 1000.0
    if micros >= 1000.0 {
        return String(format: "%.2f ms", micros / 1000.0)
    } else {
        return String(format: "%.1f µs", micros)
    }
}

func formatThroughput(_ mbPerSec: Double) -> String {
    if mbPerSec >= 10000.0 {
        return String(format: "%.1f GB/s", mbPerSec / 1024.0)
    } else {
        return String(format: "%.1f MB/s", mbPerSec)
    }
}

func printMatrixTable(summary: CodecBenchmarkMatrixSummary) {
    print("==========================================================================================================================")
    print("⚡️ TTZip Deflate-Bench Unified In-Memory Matrix (Total Points: \(summary.totalPoints))")
    print("==========================================================================================================================")
    print("[Idx] Engine     | Corpus        | Size  | Lvl | Comp Time  | Comp Rate   | Decomp Time| Decomp Rate | Ratio  | Status")
    print("--------------------------------------------------------------------------------------------------------------------------")

    for (idx, point) in summary.results.enumerated() {
        let idxStr = padLeft("\(idx + 1)", 2)
        let engineStr = padRight(point.engineName, 10)
        let corpusStr = padRight(point.corpusType.rawValue, 13)
        let sizeStr = padRight(point.payloadSizeBytes == 131072 ? "128KB" : "1MB", 5)
        let lvlStr = padRight("L\(point.compressionLevel)", 3)
        let cTimeStr = padLeft(formatDuration(point.compressDurationNs), 10)
        let cSpeedStr = padLeft(formatThroughput(point.compressThroughputMBs), 11)
        let dTimeStr = padLeft(formatDuration(point.decompressDurationNs), 10)
        let dSpeedStr = padLeft(formatThroughput(point.decompressThroughputMBs), 11)
        let ratioStr = padLeft(String(format: "%.1f%%", point.compressionRatio * 100.0), 6)
        let status = point.integrityVerified ? "OK" : "FAIL"

        let line = "[\(idxStr)] \(engineStr) | \(corpusStr) | \(sizeStr) | \(lvlStr) | \(cTimeStr) | \(cSpeedStr) | \(dTimeStr) | \(dSpeedStr) | \(ratioStr) | \(status)"
        print(line)
    }

    print("--------------------------------------------------------------------------------------------------------------------------")
    let passedCount = summary.results.filter { $0.integrityVerified }.count
    let durSec = String(format: "%.3f", summary.totalDurationMs / 1000.0)
    let cvStr = String(format: "%.2f", summary.medianCvPercentage)
    print("Summary: \(passedCount)/\(summary.totalPoints) Points PASSED | Total Matrix Time: \(durSec)s | Median CV: \(cvStr)%")
    print("==========================================================================================================================")
}

func serializeMatrixReport(summary: CodecBenchmarkMatrixSummary) -> [String: Any] {
    var pointsArr: [[String: Any]] = []
    for (i, r) in summary.results.enumerated() {
        pointsArr.append([
            "index": i + 1,
            "engine": r.engineName,
            "corpus": r.corpusType.rawValue,
            "sizeBytes": r.payloadSizeBytes,
            "level": r.compressionLevel,
            "compressionTimeMicros": r.compressDurationNs / 1000.0,
            "compressionSpeedMBs": r.compressThroughputMBs,
            "decompressionTimeMicros": r.decompressDurationNs / 1000.0,
            "decompressionSpeedMBs": r.decompressThroughputMBs,
            "ratioPercentage": r.compressionRatio * 100.0,
            "integrityPassed": r.integrityVerified,
            "cvPercentage": r.cvPercentage
        ])
    }

    let passedCount = summary.results.filter { $0.integrityVerified }.count
    let gatePassed = (passedCount == summary.totalPoints && summary.medianCvPercentage <= 1.50)

    return [
        "timestamp": Int(Date().timeIntervalSince1970),
        "osVersion": "macOS 15.3",
        "architecture": "arm64",
        "totalPoints": summary.totalPoints,
        "passedPoints": passedCount,
        "totalDurationSeconds": summary.totalDurationMs / 1000.0,
        "medianCvPercentage": summary.medianCvPercentage,
        "gateVerdict": gatePassed ? "PASS" : "FAIL",
        "points": pointsArr
    ]
}

// Top-level CLI entry point
let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, command != "--help", command != "-h", command != "help" else {
    printHelp()
    exit(0)
}

switch command {
case "matrix":
    var jsonOutputPath: String? = nil
    var idx = 1
    while idx < args.count {
        if args[idx] == "--json-out", idx + 1 < args.count {
            jsonOutputPath = args[idx + 1]
            idx += 2
        } else {
            idx += 1
        }
    }

    let summary = TTZipCoreCodecBenchmarks().run50PointMatrix()
    printMatrixTable(summary: summary)

    if let jsonPath = jsonOutputPath {
        let report = serializeMatrixReport(summary: summary)
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: jsonPath))
            print("📄 Telemetry JSON report exported to: \(jsonPath)")
        }
    }

case "gate":
    print("⚡️ Running TTZip Automated Benchmark Gate...")
    let summary = TTZipCoreCodecBenchmarks().run50PointMatrix()
    printMatrixTable(summary: summary)

    let passedCount = summary.results.filter { $0.integrityVerified }.count
    let allPassed = passedCount == summary.totalPoints
    let cvPassed = summary.medianCvPercentage <= 1.50

    if allPassed && cvPassed {
        print("\n✅ GATE PASSED: 50/50 points OK | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))% <= 1.50%")
        exit(0)
    } else {
        print("\n❌ GATE FAILED: Passed: \(passedCount)/\(summary.totalPoints) | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))%")
        exit(70) // EX_SOFTWARE
    }

case "plot":
    print("⚡️ Pareto plot generation ready. Run full suite via 'ttzip-bench matrix' or custom input.")

default:
    print("❌ Unknown subcommand: '\(command)'\n")
    printHelp()
    exit(64) // EX_USAGE
}
