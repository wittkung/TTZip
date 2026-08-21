// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension InMemoryBenchmarkEngine {
    
    // MARK: - Output Formatting & Report Serialization

    public func formatRowOutput(result: AlgorithmBenchmarkResult, turboBenchFormat: Bool) -> String {
        let verifyStr = result.integrityVerified ? "PASSED (OK)" : "FAILED (ERR)"
        let cSizeStr = "\(result.compressedBytes)"
        let algoPadded = result.algorithm.padding(toLength: 16, withPad: " ", startingAt: 0)
        let cSizePadded = cSizeStr.padding(toLength: 11, withPad: " ", startingAt: 0)

        if turboBenchFormat {
            return String(format: "%@ | %2d | %@ | %6.2fx | %5.1f%% | %11.1f MB/s | %11.1f MB/s | %5d | %@",
                          algoPadded,
                          result.level,
                          cSizePadded,
                          result.ratio,
                          result.spaceSavingsPct,
                          result.compressionSpeedMBs,
                          result.decompressionSpeedMBs,
                          result.iterationsCompleted,
                          verifyStr)
        } else {
            return String(format: "%@ | L%-2d | CSize: %@ | Ratio: %5.2fx (%4.1f%%) | Comp: %9.1f MB/s | Decomp: %9.1f MB/s | Iters: %4d | %@",
                          algoPadded,
                          result.level,
                          cSizePadded,
                          result.ratio,
                          result.spaceSavingsPct,
                          result.compressionSpeedMBs,
                          result.decompressionSpeedMBs,
                          result.iterationsCompleted,
                          verifyStr)
        }
    }

    public func generateTurboBenchTable(report: BenchmarkSuiteReport) -> String {
        var out = ""
        out += "========================================================================================================================\n"
        out += "📊 In-Memory Benchmark Results (TurboBench / lzbench Model / Apple Silicon RAM)\n"
        out += "========================================================================================================================\n"
        out += "Algorithm        | Lvl| CSize (B)   |  Ratio | Space % |    Comp (MB/s) |   Decomp (MB/s) | Iters | Integrity\n"
        out += "------------------------------------------------------------------------------------------------------------------------\n"
        for r in report.results {
            out += formatRowOutput(result: r, turboBenchFormat: true) + "\n"
        }
        out += "========================================================================================================================\n"
        out += String(format: "⏱️ Wall Duration: %.2f ms | Processed Throughput: %.1f MB | Clock: %@ (%llu Hz) | Resolution: %.1f ns\n",
                      report.totalWallDurationMs,
                      Double(report.totalInputBytes) / (1024.0 * 1024.0),
                      report.timerCalibration.timerBackend as NSString,
                      report.timerCalibration.frequencyHz,
                      report.timerCalibration.resolutionNanos)
        return out
    }
}
