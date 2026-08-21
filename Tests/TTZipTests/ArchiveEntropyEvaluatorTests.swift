// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveEntropyEvaluatorTests: XCTestCase {

    func testZeroAndHomogeneousDataEntropy() {
        let zeros = [UInt8](repeating: 0, count: 4096)
        zeros.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            let entropy = ArchiveEntropyEvaluator.estimateEntropy(buffer: base, count: raw.count)
            XCTAssertEqual(entropy, 0.0, accuracy: 1e-4)
            XCTAssertFalse(ArchiveEntropyEvaluator.shouldBypassCompression(buffer: base, count: raw.count))
        }
    }

    func testHighEntropyDataEvaluationAndBypass() {
        // Generate pseudo-random 1MB data
        var highEntropyData = [UInt8](repeating: 0, count: 1024 * 1024)
        var state: UInt64 = 0xABCD1234EF567890
        for i in 0..<(1024 * 1024) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            highEntropyData[i] = UInt8((state >> 32) & 0xFF)
        }

        let data = Data(highEntropyData)
        let shouldBypass = ArchiveEntropyEvaluator.shouldBypassCompression(data: data)
        XCTAssertTrue(shouldBypass, "1MB random data should trigger Store bypass")

        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            let entropy = ArchiveEntropyEvaluator.estimateEntropyDynamic(buffer: base, count: raw.count)
            XCTAssertGreaterThan(entropy, 7.90)
        }
    }

    func testSmallPayloadDoesNotBypass() {
        // High entropy but below minimumSampleSizeBytes (1MB)
        var smallRandom = [UInt8](repeating: 0, count: 512 * 1024)
        var state: UInt64 = 0xFEEDBEEF
        for i in 0..<smallRandom.count {
            state = state &* 6364136223846793005 &+ 1
            smallRandom[i] = UInt8((state >> 32) & 0xFF)
        }

        let data = Data(smallRandom)
        let shouldBypass = ArchiveEntropyEvaluator.shouldBypassCompression(data: data)
        XCTAssertFalse(shouldBypass, "Payload under 1MB should not trigger bypass")
    }
}
