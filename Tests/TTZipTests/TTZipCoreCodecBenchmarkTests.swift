// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class TTZipCoreCodecBenchmarkTests: XCTestCase {
    func testInPlaceCorpusGeneration() throws {
        let pool = BenchmarkBufferPool(size: 65536)
        for type in BenchmarkCorpusType.allCases {
            pool.prepareCorpus(type)
            let ptr = pool.inputBuffer.assumingMemoryBound(to: UInt8.self)
            var hasNonZero = false
            for i in 0..<1024 {
                if ptr[i] != 0 { hasNonZero = true; break }
            }
            XCTAssertTrue(hasNonZero, "Corpus \(type.rawValue) generated all zeros!")
        }
    }

    func test50PointInMemeoryMatrixExecution() throws {
        let runner = TTZipCoreCodecBenchmarks()
        let summary = runner.run50PointMatrix()

        func formatTime(_ ns: Double) -> String {
            if ns < 1000.0 {
                return String(format: "%5.0f ns", ns)
            } else if ns < 1_000_000.0 {
                return String(format: "%6.1f µs", ns / 1000.0)
            } else {
                return String(format: "%6.2f ms", ns / 1_000_000.0)
            }
        }

        func formatRate(_ mbps: Double) -> String {
            if mbps >= 10240.0 {
                return String(format: "%5.1f GB/s", mbps / 1024.0)
            } else {
                return String(format: "%6.1f MB/s", mbps)
            }
        }

        print("==========================================================================================================================")
        print("⚡️ TTZip Deflate-Bench Unified In-Memory Matrix (Total Points: \(summary.totalPoints))")
        print("==========================================================================================================================")
        print("[Idx] Engine     | Corpus        | Size  | Lvl | Comp Time  | Comp Rate   | Decomp Time| Decomp Rate | Ratio  | Status")
        print("--------------------------------------------------------------------------------------------------------------------------")
        
        for (i, r) in summary.results.enumerated() {
            let pStr = r.payloadSizeBytes == 131072 ? "128KB" : "  1MB"
            let compTimeStr = formatTime(r.compressDurationNs)
            let compRateStr = formatRate(r.compressThroughputMBs)
            let decompTimeStr = formatTime(r.decompressDurationNs)
            let decompRateStr = formatRate(r.decompressThroughputMBs)
            let ratioPercent = (Double(r.compressedSizeBytes) / Double(r.payloadSizeBytes)) * 100.0
            let ratioStr = String(format: "%5.1f%%", ratioPercent)
            let status = r.integrityVerified ? "OK" : "FAIL"
            let numStr = String(format: "%2d", i + 1)
            let enginePad = r.engineName.padding(toLength: 10, withPad: " ", startingAt: 0)
            let corpusPad = r.corpusType.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)
            let lvlPad = String(format: "%-2d", r.compressionLevel)
            
            print("[\(numStr)] \(enginePad) | \(corpusPad) | \(pStr) | L\(lvlPad) | \(compTimeStr) | \(compRateStr) | \(decompTimeStr) | \(decompRateStr) | \(ratioStr) | \(status)")
        }

        print("--------------------------------------------------------------------------------------------------------------------------")
        let sumLine = String(format: "Summary: %d/%d Points PASSED | Total Matrix Time: %.3fs | Median CV: %.2f%%",
                             summary.results.filter { $0.integrityVerified }.count, summary.totalPoints,
                             summary.totalDurationMs / 1000.0, summary.medianCvPercentage)
        print(sumLine)
        print("==========================================================================================================================")

        XCTAssertGreaterThanOrEqual(summary.totalPoints, 40)
        XCTAssertTrue(summary.allIntegrityPassed)
        XCTAssertLessThanOrEqual(summary.totalDurationMs, 2000.0)
    }
}
