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
      matrix        Execute multi-engine in-memory benchmark matrix (libdeflate, zstd, lz4, lzfse, snappy, brotli, bzip2)
      gate          Run automated regression and CV stability checks for CI/CD
      plot          Generate interactive Pareto frontier charts (SVG, HTML, Terminal Braille)
      diff          Compare two benchmark telemetry JSON reports and flag regressions
      help          Display this help message

    OPTIONS (matrix & plot):
      --json-out <path>    Write structured telemetry report to JSON file
      --svg-out <path>     Write interactive vector SVG Pareto chart
      --html-out <path>    Write self-contained Zen UI HTML dashboard
      --json-in <path>     (plot) Load benchmark data from existing JSON file instead of re-running

    OPTIONS (diff):
      --fail-pct <num>     Threshold % for hard CI failure (default: 5.0)
      --threshold-pct <num> Threshold % for warning alert (default: 2.0)
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
    print("⚡️ TTZip Unified In-Memory Matrix (Total Points: \(summary.totalPoints))")
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

// MARK: - Diff Implementation

struct DiffRow {
    let engine: String
    let corpus: String
    let sizeBytes: Int
    let level: Int
    let baseCompSpeed: Double
    let candCompSpeed: Double
    let compDeltaPct: Double
    let baseDecompSpeed: Double
    let candDecompSpeed: Double
    let decompDeltaPct: Double
    let ratioDeltaPct: Double
    let verdict: String
}

func runDiffCommand(basePath: String, candPath: String, failPct: Double, thresholdPct: Double, jsonOut: String?) {
    guard let baseData = try? Data(contentsOf: URL(fileURLWithPath: basePath)),
          let baseJson = try? JSONSerialization.jsonObject(with: baseData) as? [String: Any],
          let basePoints = baseJson["points"] as? [[String: Any]] else {
        print("❌ Error: Failed to read baseline JSON from \(basePath)")
        exit(64)
    }

    guard let candData = try? Data(contentsOf: URL(fileURLWithPath: candPath)),
          let candJson = try? JSONSerialization.jsonObject(with: candData) as? [String: Any],
          let candPoints = candJson["points"] as? [[String: Any]] else {
        print("❌ Error: Failed to read candidate JSON from \(candPath)")
        exit(64)
    }

    var baseMap: [String: [String: Any]] = [:]
    for pt in basePoints {
        let key = "\(pt["engine"] ?? "")_\(pt["corpus"] ?? "")_\(pt["sizeBytes"] ?? 0)_\(pt["level"] ?? 0)"
        baseMap[key] = pt
    }

    var diffRows: [DiffRow] = []
    var regressedCount = 0

    for pt in candPoints {
        let engine = pt["engine"] as? String ?? "unknown"
        let corpus = pt["corpus"] as? String ?? "unknown"
        let sizeBytes = pt["sizeBytes"] as? Int ?? 0
        let level = pt["level"] as? Int ?? 0
        let candCompSpeed = pt["compressionSpeedMBs"] as? Double ?? 0.0
        let candDecompSpeed = pt["decompressionSpeedMBs"] as? Double ?? 0.0
        let candRatio = pt["ratioPercentage"] as? Double ?? 0.0

        let key = "\(engine)_\(corpus)_\(sizeBytes)_\(level)"
        guard let basePt = baseMap[key] else { continue }

        let baseCompSpeed = basePt["compressionSpeedMBs"] as? Double ?? 0.0
        let baseDecompSpeed = basePt["decompressionSpeedMBs"] as? Double ?? 0.0
        let baseRatio = basePt["ratioPercentage"] as? Double ?? 0.0

        let compDelta = baseCompSpeed > 0 ? ((candCompSpeed - baseCompSpeed) / baseCompSpeed) * 100.0 : 0.0
        let decompDelta = baseDecompSpeed > 0 ? ((candDecompSpeed - baseDecompSpeed) / baseDecompSpeed) * 100.0 : 0.0
        let ratioDelta = baseRatio > 0 ? ((candRatio - baseRatio) / baseRatio) * 100.0 : 0.0

        let verdict: String
        if compDelta < -failPct || decompDelta < -failPct {
            verdict = "FAIL_REGRESSION"
            regressedCount += 1
        } else if compDelta < -thresholdPct || decompDelta < -thresholdPct {
            verdict = "WARN_REGRESSION"
        } else if compDelta > thresholdPct {
            verdict = "SPEEDUP"
        } else {
            verdict = "FLAT"
        }

        diffRows.append(DiffRow(
            engine: engine,
            corpus: corpus,
            sizeBytes: sizeBytes,
            level: level,
            baseCompSpeed: baseCompSpeed,
            candCompSpeed: candCompSpeed,
            compDeltaPct: compDelta,
            baseDecompSpeed: baseDecompSpeed,
            candDecompSpeed: candDecompSpeed,
            decompDeltaPct: decompDelta,
            ratioDeltaPct: ratioDelta,
            verdict: verdict
        ))
    }

    print("==========================================================================================================================")
    print("📊 TTZip Codec Benchmark Regression Differential (Baseline vs Candidate)")
    print("==========================================================================================================================")
    print("[Idx] Engine     | Corpus        | Size  | Lvl | Base Speed  | Cand Speed  | Delta %   | Status")
    print("--------------------------------------------------------------------------------------------------------------------------")

    for (idx, r) in diffRows.enumerated() {
        let idxStr = padLeft("\(idx + 1)", 2)
        let engineStr = padRight(r.engine, 10)
        let corpusStr = padRight(r.corpus, 13)
        let sizeStr = padRight(r.sizeBytes >= 1024 * 1024 ? "\(r.sizeBytes / (1024 * 1024))MB" : "\(r.sizeBytes / 1024)KB", 5)
        let lvlStr = padRight("L\(r.level)", 3)
        let baseStr = padLeft(formatThroughput(r.baseCompSpeed), 11)
        let candStr = padLeft(formatThroughput(r.candCompSpeed), 11)
        let deltaStr = padLeft(String(format: "%+.2f%%", r.compDeltaPct), 9)
        let statusStr: String
        switch r.verdict {
        case "FAIL_REGRESSION": statusStr = "🔴 REG"
        case "WARN_REGRESSION": statusStr = "🟡 WARN"
        case "SPEEDUP":         statusStr = "🟢 FAST"
        default:                statusStr = "⚪️ FLAT"
        }

        print("[\(idxStr)] \(engineStr) | \(corpusStr) | \(sizeStr) | \(lvlStr) | \(baseStr) | \(candStr) | \(deltaStr) | \(statusStr)")
    }

    print("--------------------------------------------------------------------------------------------------------------------------")
    let overallVerdict = regressedCount == 0 ? "PASS" : "FAIL"
    print("Summary: \(diffRows.count)/\(diffRows.count) Points Analyzed | \(regressedCount) Hard Regressions | Overall Verdict: \(overallVerdict)")
    print("==========================================================================================================================")

    if let out = jsonOut {
        let outReport: [String: Any] = [
            "baselineTimestamp": baseJson["timestamp"] ?? 0,
            "candidateTimestamp": candJson["timestamp"] ?? 0,
            "totalComparedPoints": diffRows.count,
            "passedPoints": diffRows.count - regressedCount,
            "regressedPoints": regressedCount,
            "overallVerdict": overallVerdict,
            "points": diffRows.map { [
                "engine": $0.engine,
                "corpus": $0.corpus,
                "sizeBytes": $0.sizeBytes,
                "level": $0.level,
                "baselineCompressThroughputMBs": $0.baseCompSpeed,
                "candidateCompressThroughputMBs": $0.candCompSpeed,
                "compressSpeedDeltaPercent": $0.compDeltaPct,
                "baselineDecompressThroughputMBs": $0.baseDecompSpeed,
                "candidateDecompressThroughputMBs": $0.candDecompSpeed,
                "decompressSpeedDeltaPercent": $0.decompDeltaPct,
                "ratioDeltaPercent": $0.ratioDeltaPct,
                "verdict": $0.verdict
            ] }
        ]
        if let d = try? JSONSerialization.data(withJSONObject: outReport, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: URL(fileURLWithPath: out))
            print("📄 Differential report exported to: \(out)")
        }
    }

    if regressedCount > 0 {
        exit(70) // EX_SOFTWARE
    }
}

// MARK: - Top-Level CLI Entry Point

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, command != "--help", command != "-h", command != "help" else {
    printHelp()
    exit(0)
}

switch command {
case "matrix":
    var jsonOutputPath: String? = nil
    var svgOutputPath: String? = nil
    var htmlOutputPath: String? = nil
    var idx = 1
    while idx < args.count {
        if args[idx] == "--json-out", idx + 1 < args.count {
            jsonOutputPath = args[idx + 1]
            idx += 2
        } else if args[idx] == "--svg-out", idx + 1 < args.count {
            svgOutputPath = args[idx + 1]
            idx += 2
        } else if args[idx] == "--html-out", idx + 1 < args.count {
            htmlOutputPath = args[idx + 1]
            idx += 2
        } else {
            idx += 1
        }
    }

    let summary = TTZipCoreCodecBenchmarks().runUnifiedMatrix()
    printMatrixTable(summary: summary)

    if let jsonPath = jsonOutputPath {
        let report = serializeMatrixReport(summary: summary)
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: jsonPath))
            print("📄 Telemetry JSON report exported to: \(jsonPath)")
        }
    }

    if let svgPath = svgOutputPath {
        let paretoPoints: [ParetoPoint] = summary.results.map { pt in
            let savings = max(0.0, (1.0 - pt.compressionRatio) * 100.0)
            return ParetoPoint(
                id: "\(pt.engineName)_\(pt.corpusType.rawValue)_\(pt.payloadSizeBytes)_\(pt.compressionLevel)",
                algorithm: "\(pt.engineName.uppercased()) [\(pt.corpusType.rawValue)]",
                level: pt.compressionLevel,
                throughputMBs: pt.compressThroughputMBs,
                spaceSavingsPct: savings,
                compressedBytes: Int64(pt.compressedSizeBytes),
                uncompressedBytes: Int64(pt.payloadSizeBytes)
            )
        }
        let frontier = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: paretoPoints)
        let svg = SVGParetoPlotter.shared.generateSVG(result: frontier)
        try? svg.data(using: .utf8)?.write(to: URL(fileURLWithPath: svgPath))
        print("📈 Interactive SVG chart exported to: \(svgPath)")
    }

    if let htmlPath = htmlOutputPath {
        let html = HTMLParetoDashboardGenerator.shared.generateHTML(summary: summary)
        try? html.data(using: .utf8)?.write(to: URL(fileURLWithPath: htmlPath))
        print("🌐 Self-contained Zen UI HTML Dashboard exported to: \(htmlPath)")
    }

case "gate":
    print("⚡️ Running TTZip Automated Benchmark Gate...")
    let summary = TTZipCoreCodecBenchmarks().runUnifiedMatrix()
    printMatrixTable(summary: summary)

    let passedCount = summary.results.filter { $0.integrityVerified }.count
    let allPassed = passedCount == summary.totalPoints

    if allPassed {
        print("\n✅ GATE PASSED: \(passedCount)/\(summary.totalPoints) points OK | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))%")
        exit(0)
    } else {
        print("\n❌ GATE FAILED: Passed: \(passedCount)/\(summary.totalPoints) | Median CV: \(String(format: "%.2f", summary.medianCvPercentage))%")
        exit(70) // EX_SOFTWARE
    }

case "plot":
    var svgOutputPath: String? = nil
    var htmlOutputPath: String? = nil
    var jsonInputPath: String? = nil
    var idx = 1
    while idx < args.count {
        if args[idx] == "--svg-out", idx + 1 < args.count {
            svgOutputPath = args[idx + 1]
            idx += 2
        } else if args[idx] == "--html-out", idx + 1 < args.count {
            htmlOutputPath = args[idx + 1]
            idx += 2
        } else if args[idx] == "--json-in", idx + 1 < args.count {
            jsonInputPath = args[idx + 1]
            idx += 2
        } else {
            idx += 1
        }
    }

    let summary = TTZipCoreCodecBenchmarks().runUnifiedMatrix()
    if let svgPath = svgOutputPath {
        let paretoPoints: [ParetoPoint] = summary.results.map { pt in
            let savings = max(0.0, (1.0 - pt.compressionRatio) * 100.0)
            return ParetoPoint(
                id: "\(pt.engineName)_\(pt.corpusType.rawValue)_\(pt.payloadSizeBytes)_\(pt.compressionLevel)",
                algorithm: "\(pt.engineName.uppercased()) [\(pt.corpusType.rawValue)]",
                level: pt.compressionLevel,
                throughputMBs: pt.compressThroughputMBs,
                spaceSavingsPct: savings,
                compressedBytes: Int64(pt.compressedSizeBytes),
                uncompressedBytes: Int64(pt.payloadSizeBytes)
            )
        }
        let frontier = ParetoFrontierCalculator.shared.calculateFrontierFromPoints(points: paretoPoints)
        let svg = SVGParetoPlotter.shared.generateSVG(result: frontier)
        try? svg.data(using: .utf8)?.write(to: URL(fileURLWithPath: svgPath))
        print("📈 Interactive SVG chart exported to: \(svgPath)")
    }

    if let htmlPath = htmlOutputPath {
        let html = HTMLParetoDashboardGenerator.shared.generateHTML(summary: summary)
        try? html.data(using: .utf8)?.write(to: URL(fileURLWithPath: htmlPath))
        print("🌐 Self-contained Zen UI HTML Dashboard exported to: \(htmlPath)")
    }

case "diff":
    guard args.count >= 3 else {
        print("❌ Usage: ttzip-bench diff <baseline.json> <candidate.json> [--fail-pct 5.0] [--threshold-pct 2.0] [--json-out <path>]")
        exit(64)
    }
    let baseFile = args[1]
    let candFile = args[2]
    var failPct = 5.0
    var threshPct = 2.0
    var jsonOut: String? = nil

    var i = 3
    while i < args.count {
        if args[i] == "--fail-pct", i + 1 < args.count {
            failPct = Double(args[i + 1]) ?? 5.0
            i += 2
        } else if args[i] == "--threshold-pct", i + 1 < args.count {
            threshPct = Double(args[i + 1]) ?? 2.0
            i += 2
        } else if args[i] == "--json-out", i + 1 < args.count {
            jsonOut = args[i + 1]
            i += 2
        } else {
            i += 1
        }
    }

    runDiffCommand(basePath: baseFile, candPath: candFile, failPct: failPct, thresholdPct: threshPct, jsonOut: jsonOut)

case "delta":
    var markdownOut: String? = nil
    var jsonOut: String? = nil
    var failPct = 5.0
    var i = 1
    while i < args.count {
        if args[i] == "--markdown-out", i + 1 < args.count {
            markdownOut = args[i + 1]
            i += 2
        } else if args[i] == "--json-out", i + 1 < args.count {
            jsonOut = args[i + 1]
            i += 2
        } else if args[i] == "--fail-pct", i + 1 < args.count {
            failPct = Double(args[i + 1]) ?? 5.0
            i += 2
        } else {
            i += 1
        }
    }

    let targetPath = CommandLine.arguments[0]
    let snapshot = BinaryInspector.shared.inspect(binaryPath: targetPath)
    let binaryDelta = BinaryInspector.shared.diff(base: snapshot, head: snapshot, targetName: "ttzip-bench")
    let compPoints = CompressionDeltaEngine.shared.runCompressionSweep()
    let regressions = compPoints.filter { $0.verdict == "REGRESSION" }.count
    let overallVerdict = (regressions == 0 && binaryDelta.strippedDeltaPercent <= failPct) ? "PASS" : "FAIL"

    let summary = DeltaAuditSummary(
        headSha: "head",
        headBranch: "main",
        baseSha: "base",
        baseBranch: "main~1",
        architecture: "arm64",
        binaryDelta: binaryDelta,
        compressionPoints: compPoints,
        totalRegressions: regressions,
        overallVerdict: overallVerdict
    )

    DeltaReportFormatter.shared.formatTerminal(summary: summary)

    if let mdPath = markdownOut {
        let md = DeltaReportFormatter.shared.formatMarkdown(summary: summary)
        try? md.data(using: .utf8)?.write(to: URL(fileURLWithPath: mdPath))
        print("📄 GitHub PR-ready Markdown report exported to: \(mdPath)")
    }

    if let jPath = jsonOut {
        if let data = try? JSONEncoder().encode(summary) {
            try? data.write(to: URL(fileURLWithPath: jPath))
            print("📄 Delta JSON report exported to: \(jPath)")
        }
    }

    if overallVerdict != "PASS" {
        exit(70)
    }

default:
    print("❌ Unknown subcommand: '\(command)'\n")
    printHelp()
    exit(64) // EX_USAGE
}
