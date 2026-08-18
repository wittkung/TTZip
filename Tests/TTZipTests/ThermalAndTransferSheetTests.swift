// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class ThermalAndTransferSheetTests: XCTestCase {

    func testThermalBridgeGetSet() {
        ttzip_bridge_set_thermal_state(0)
        XCTAssertEqual(ttzip_bridge_get_thermal_state(), 0)

        ttzip_bridge_set_thermal_state(2) // Serious
        XCTAssertEqual(ttzip_bridge_get_thermal_state(), 2)

        ttzip_bridge_set_thermal_state(0) // Restore
    }

    func testTransferSpeedSheetFormulas() {
        let sampleResult = AlgorithmBenchmarkResult(
            algorithm: "Zstandard",
            level: 3,
            uncompressedBytes: 100_000_000, // 100MB
            compressedBytes: 40_000_000,    // 40MB
            compressionTimeNs: 100_000_000, // 0.1s -> 1000 MB/s
            decompressionTimeNs: 50_000_000,// 0.05s -> 2000 MB/s
            iterationsCompleted: 5,
            integrityVerified: true
        )

        let report = TransferSpeedSheetCalculator.shared.calculateReport(for: sampleResult)

        XCTAssertEqual(report.tiers.count, 4)

        // Tier 1: Cloud WAN (25 MB/s)
        // Raw transfer: 100MB / 25MB/s = 4.0s
        // Compressed transfer: 40MB / 25MB/s = 1.6s
        // Total: 0.1 + 1.6 + 0.05 = 1.75s
        // Speedup = 4.0 / 1.75 = 2.285x
        let wanTier = report.tiers[0]
        XCTAssertEqual(wanTier.tierName, "Cloud WAN (200Mbps)")
        XCTAssertEqual(wanTier.rawTransferSeconds, 4.0, accuracy: 0.001)
        XCTAssertEqual(wanTier.compressedTransferSeconds, 1.6, accuracy: 0.001)
        XCTAssertEqual(wanTier.totalTurnaroundSeconds, 1.75, accuracy: 0.001)
        XCTAssertEqual(wanTier.speedupRatio, 4.0 / 1.75, accuracy: 0.01)

        let tableStr = TransferSpeedSheetCalculator.shared.formatTable(reports: [report])
        XCTAssertTrue(tableStr.contains("Zstandard"))
        XCTAssertTrue(tableStr.contains("Cloud WAN"))
    }
}
