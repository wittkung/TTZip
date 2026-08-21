// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation
import TTZipCore

extension BenchCommandRunner {
    
    // MARK: - Table & Report Serialization
    
    public static func printMatrixTable(summary: CodecBenchmarkMatrixSummary) {
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

    public static func serializeMatrixReport(summary: CodecBenchmarkMatrixSummary) -> [String: Any] {
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
}
