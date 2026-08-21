// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import TTZipCore

extension BenchCommandRunner {
    
    // MARK: - Diff and Delta Command Subroutines
    
    public static func runDiff(args: [String]) {
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
    }

    public static func runDiffCommand(basePath: String, candPath: String, failPct: Double, thresholdPct: Double, jsonOut: String?) {
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

    public static func runDelta(args: [String]) {
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
    }
}
