// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SmartCodecSelectorTests: XCTestCase {

    func testHighEntropyDataSelection() {
        // Generate pseudo-random high entropy data (64KB) with 64-bit state (period 2^64)
        var randomData = [UInt8](repeating: 0, count: 65536)
        var state: UInt64 = 0x853c49e6748fea9b
        for i in 0..<65536 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            randomData[i] = UInt8((state >> 32) & 0xFF)
        }

        let recommendation = SmartCodecSelector.shared.recommend(
            for: randomData,
            length: randomData.count,
            scenario: .balancedDaily
        )

        // Random data has high entropy and low compressibility
        XCTAssertGreaterThan(recommendation.measuredEntropy, 7.8)
        XCTAssertGreaterThan(recommendation.trialCompressibilityRatio, 0.95)
        XCTAssertEqual(recommendation.recommendedAlgorithm, "Store")
        XCTAssertEqual(recommendation.recommendedLevel, 0)
        XCTAssertLessThan(recommendation.probeDurationMs, 20.0, "Probe should complete in under 20ms")
    }

    func testTextDataScenarioRecommendations() {
        // Generate repetitive text data (128KB)
        let sampleText = "The quick brown fox jumps over the lazy dog. TTZip high performance compression engine.\n"
        let repeatCount = 128 * 1024 / sampleText.utf8.count
        let repeatedStr = String(repeating: sampleText, count: repeatCount)
        let data = Data(repeatedStr.utf8)

        data.withUnsafeBytes { rawPtr in
            guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            // 1. Instant Transfer Scenario
            let recInstant = SmartCodecSelector.shared.recommend(for: base, length: data.count, scenario: .instantTransfer)
            XCTAssertTrue(recInstant.recommendedAlgorithm == "Zstandard" || recInstant.recommendedAlgorithm == "LZ4")
            XCTAssertEqual(recInstant.recommendedLevel, 1)

            // 2. Cold Storage Scenario
            let recCold = SmartCodecSelector.shared.recommend(for: base, length: data.count, scenario: .coldStorage)
            XCTAssertEqual(recCold.recommendedAlgorithm, "7Z-LZMA2")
            XCTAssertEqual(recCold.recommendedLevel, 9)
        }
    }
}
