// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// 16 1v1 PK
final class AllFormatsPkSuiteTests: XCTestCase {

    /// 7z, Zst, Gz (passes: 1) PK
    func testAllFormatsPkLeaderboardAndIntegrity() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Full 500MB competitor PK benchmark requires TTZIP_RUN_BENCHMARKS=1, skipping in regular swift test以杜绝卡主")
        }
        
        try await withTimeout(seconds: 1200.0, description: "AllFormatsPkLeaderboard") {
            TTLogger.info("\n================================================================================")
            TTLogger.info("   🏆 [TTZip Suite] Full 16 formats competitor 1v1 PK and integrity verification")
            TTLogger.info("================================================================================")
            
            let targetFormats: [ArchiveCompressionFormat] = [
                .sevenZip, .zip, .tarZst, .tarGz,
                .tarBz2, .tarXz, .tar, .lzip,
                .lz4, .brotli, .lrzip, .aar,
                .snappy, .wim, .dmg, .iso
            ]
            
            let rows = try await CompetitorBenchmarkRunner.runCompetitorMatrix(
                selectedFormats: targetFormats,
                selectedLevels: [.level1, .level6],
                stopOnLagOrError: false,
                autoBestCompetitor: true,
                verifyAllDominance: false,
                passes: 2,
                progressHandler: { msg in
                    TTLogger.debug("  \(msg)")
                }
            )
            
            TTLogger.info("\n================================================================================")
            TTLogger.info("   📊 [TTZip Suite] Full format PK tests completed, total scenarios: \(rows.count) evaluated against competitors")
            TTLogger.info("================================================================================\n")
            
            XCTAssertGreaterThan(rows.count, 0, "Full format PK test results list must not be empty")
        }
    }
}
