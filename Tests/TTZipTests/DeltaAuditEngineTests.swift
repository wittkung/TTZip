// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import XCTest
@testable import TTZipCore

final class DeltaAuditEngineTests: XCTestCase {
    func testCompressionDeltaSweep() throws {
        let engine = CompressionDeltaEngine.shared
        let points = engine.runCompressionSweep(corpora: [.text, .mixed])
        
        XCTAssertGreaterThanOrEqual(points.count, 80)
        XCTAssertTrue(points.allSatisfy { $0.uncompressedBytes == 1024 * 1024 })
        XCTAssertTrue(points.allSatisfy { $0.headCompressedBytes > 0 })
        XCTAssertTrue(points.allSatisfy { $0.verdict == "IDENTICAL" || $0.verdict == "OPTIMIZATION" })
    }

    func testBinaryDeltaDiffCalculation() throws {
        let baseSnapshot = BinarySectionSnapshot(
            binaryPath: "/bin/ls",
            rawSizeBytes: 100_000,
            strippedSizeBytes: 80_000,
            textSectionBytes: 60_000,
            dataSectionBytes: 15_000,
            bssSectionBytes: 5_000,
            exportedSymbols: ["_sym_a", "_sym_b", "_sym_c"]
        )

        let headSnapshot = BinarySectionSnapshot(
            binaryPath: "/bin/ls",
            rawSizeBytes: 105_000,
            strippedSizeBytes: 82_000,
            textSectionBytes: 61_000,
            dataSectionBytes: 16_000,
            bssSectionBytes: 5_000,
            exportedSymbols: ["_sym_a", "_sym_c", "_sym_d"]
        )

        let diff = BinaryInspector.shared.diff(base: baseSnapshot, head: headSnapshot, targetName: "test-target")

        XCTAssertEqual(diff.targetName, "test-target")
        XCTAssertEqual(diff.rawDeltaBytes, 5_000)
        XCTAssertEqual(diff.rawDeltaPercent, 5.0)
        XCTAssertEqual(diff.strippedDeltaBytes, 2_000)
        XCTAssertEqual(diff.strippedDeltaPercent, 2.5)
        XCTAssertEqual(diff.textDeltaBytes, 1_000)
        XCTAssertEqual(diff.dataDeltaBytes, 1_000)
        XCTAssertEqual(diff.bssDeltaBytes, 0)
        XCTAssertEqual(diff.addedSymbols, ["_sym_d"])
        XCTAssertEqual(diff.removedSymbols, ["_sym_b"])
    }

    func testDeltaReportMarkdownFormatting() throws {
        let baseSnapshot = BinarySectionSnapshot(
            binaryPath: "test",
            rawSizeBytes: 1000,
            strippedSizeBytes: 800,
            textSectionBytes: 500,
            dataSectionBytes: 200,
            bssSectionBytes: 100,
            exportedSymbols: ["_sym1"]
        )
        let binaryDelta = BinaryInspector.shared.diff(base: baseSnapshot, head: baseSnapshot, targetName: "ttzip-test")
        let points = CompressionDeltaEngine.shared.runCompressionSweep(corpora: [.text])

        let summary = DeltaAuditSummary(
            headSha: "abc1234",
            headBranch: "feature-branch",
            baseSha: "def5678",
            baseBranch: "main",
            architecture: "arm64",
            binaryDelta: binaryDelta,
            compressionPoints: points,
            totalRegressions: 0,
            overallVerdict: "PASS"
        )

        let md = DeltaReportFormatter.shared.formatMarkdown(summary: summary)
        XCTAssertTrue(md.contains("## ⚡️ TTZip Delta Report"))
        XCTAssertTrue(md.contains("`feature-branch` @ `abc1234`"))
        XCTAssertTrue(md.contains("<details open>"))
        XCTAssertTrue(md.contains("<details>"))
    }
}
