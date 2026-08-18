// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class AppleSiliconTunerTests: XCTestCase {
    
    func testAppleSiliconHardwareDetection() {
        let tuner = AppleSiliconTuner.shared
        let topology = tuner.topology
        
        XCTAssertGreaterThan(topology.totalCores, 0)
        XCTAssertGreaterThan(topology.performanceCores, 0)
        XCTAssertGreaterThan(topology.unifiedMemoryBytes, 0)
        XCTAssertGreaterThanOrEqual(topology.pageSizeBytes, 4096)
        
        XCTAssertGreaterThan(tuner.optimalCompressionThreads, 0)
        XCTAssertEqual(tuner.optimalAlignedBufferSize % topology.pageSizeBytes, 0, "Buffer size must be a multiple of page size")
        
        let summary = tuner.hardwareSummary
        XCTAssertTrue(summary.contains("Apple") || summary.contains("Silicon"))
        XCTAssertTrue(summary.contains("Cores"))
    }
}
