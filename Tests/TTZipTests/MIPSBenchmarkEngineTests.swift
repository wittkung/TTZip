// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class MIPSBenchmarkEngineTests: XCTestCase {
    
    func testMIPSBenchmarkPassCalculatesValidRatings() async {
        let dictMB = TestBenchmarkTier.isBenchmarkMode ? 16 : 2
        let engine = MIPSHardwareBenchmarkEngine.shared
        let metric = await engine.runMIPSBenchmark(
            dictionarySizeMB: dictMB,
            threadCount: 4,
            iterations: 1
        )
        
        XCTAssertEqual(metric.dictionarySizeMB, dictMB)
        XCTAssertEqual(metric.threadCount, 4)
        XCTAssertGreaterThan(metric.compressMIPS, 100.0)
        XCTAssertGreaterThan(metric.decompressMIPS, 100.0)
        XCTAssertGreaterThan(metric.totalMIPS, 100.0)
        XCTAssertGreaterThan(metric.compressSpeedMBs, 100.0)
        XCTAssertGreaterThan(metric.decompressSpeedMBs, 100.0)
        XCTAssertGreaterThan(metric.ratingPerUsageMIPS, 10.0)
    }
}
