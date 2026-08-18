// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2BitGroomingTests: XCTestCase {

    func testBitGroomingAccuracyAndCompressionSynergy() throws {
        let count = 16384 // 64KB floats
        var rawFloats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            rawFloats[i] = 12.3456789 + Float(i) * 0.01234567
        }

        // Test 1: Bit-Grooming preserving NSD = 3
        let groomedFloats = Blosc2FilterBridge.bitGroom(floats: rawFloats, nsd: 3)
        XCTAssertEqual(groomedFloats.count, count)

        // Verify Bounded Relative Error: |x - x_quant| / |x| <= 0.5 * 10^(1 - NSD) = 0.5 * 10^(-2) = 0.005 (0.5%)
        let maxAllowedRelError: Float = 0.005
        for i in 0..<min(count, 500) {
            let orig = rawFloats[i]
            let quant = groomedFloats[i]
            let relError = abs(orig - quant) / abs(orig)
            XCTAssertLessThanOrEqual(relError, maxAllowedRelError, "Relative error must be bounded by 0.5% for NSD=3 at index \(i)")
        }

        // Test 2: Compression Synergy with BitShuffle + Deflate
        let rawBytes = Data(bytes: rawFloats, count: count * MemoryLayout<Float>.size)
        let groomedBytes = Data(bytes: groomedFloats, count: count * MemoryLayout<Float>.size)

        let deflateConfig = DeflateStreamConfig(compressionLevel: 6, windowBits: -15)

        // Baseline: Raw floats Deflate
        let rawDeflate = try DeflateStreamEngine.compress(data: rawBytes, config: deflateConfig)

        // Groomed + BitShuffle + Deflate
        var shuffled = [UInt8](repeating: 0, count: groomedBytes.count)
        groomedBytes.withUnsafeBytes { rawIn in
            shuffled.withUnsafeMutableBytes { rawOut in
                ttzip_filter_bitshuffle_forward_neon(
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    groomedBytes.count,
                    4
                )
            }
        }
        let groomedBitShuffleDeflate = try DeflateStreamEngine.compress(data: Data(shuffled), config: deflateConfig)

        let rawRatio = Double(rawBytes.count) / Double(rawDeflate.count)
        let groomedRatio = Double(rawBytes.count) / Double(groomedBitShuffleDeflate.count)

        print(String(format: "BitGroom (NSD=3) Baseline Deflate: %d B (%.2fx) vs BitGroom+BitShuffle+Deflate: %d B (%.2fx)", rawDeflate.count, rawRatio, groomedBitShuffleDeflate.count, groomedRatio))
        XCTAssertGreaterThan(groomedRatio, rawRatio * 2.0, "Bit-Grooming with BitShuffle must dramatically boost compression ratio")

        // Test 3: BitRound nearest-even rounding
        let roundedFloats = Blosc2FilterBridge.bitRound(floats: rawFloats, nsd: 3)
        XCTAssertEqual(roundedFloats.count, count)
        for i in 0..<min(count, 500) {
            let orig = rawFloats[i]
            let quant = roundedFloats[i]
            let relError = abs(orig - quant) / abs(orig)
            XCTAssertLessThanOrEqual(relError, maxAllowedRelError, "BitRound relative error must be bounded")
        }
    }
}
