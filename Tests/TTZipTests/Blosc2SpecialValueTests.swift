// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2SpecialValueTests: XCTestCase {

    func testSpecialZeroDetectionAndFastFill() {
        let size = 1024 * 1024 // 1MB zero buffer
        let zeroBuffer = Data(count: size)

        let desc = zeroBuffer.withUnsafeBytes { raw in
            ttzip_detect_uniform_block(raw.baseAddress!, size, 1)
        }

        XCTAssertTrue(desc.is_uniform, "All-zero buffer must be detected as uniform")
        XCTAssertEqual(desc.special_code, TTZIP_SPECIAL_ZERO, "All-zero buffer code must be TTZIP_SPECIAL_ZERO")

        var outData = Data(repeating: 0xFF, count: size)
        let filledBytes = outData.withUnsafeMutableBytes { rawOut in
            ttzip_fill_special_value(rawOut.baseAddress!, size, desc)
        }

        XCTAssertEqual(filledBytes, size)
        XCTAssertEqual(outData, zeroBuffer, "Special zero fill must restore all zeros")
    }

    func testSpecialPatternValueDetectionAndFill() {
        let count = 32768 // 256KB of repeating UInt64
        let pattern: UInt64 = 0xCAFEBABE12345678
        let patternArray = [UInt64](repeating: pattern, count: count)
        let byteCount = count * MemoryLayout<UInt64>.size
        let rawData = Data(bytes: patternArray, count: byteCount)

        let desc = rawData.withUnsafeBytes { raw in
            ttzip_detect_uniform_block(raw.baseAddress!, byteCount, 8)
        }

        XCTAssertTrue(desc.is_uniform, "Uniform pattern array must be detected as uniform")
        XCTAssertEqual(desc.special_code, TTZIP_SPECIAL_VALUE, "Special code must be TTZIP_SPECIAL_VALUE")
        XCTAssertEqual(desc.repeat_pattern, pattern, "Detected pattern must match exact UInt64 word")

        var outData = Data(count: byteCount)
        let filledBytes = outData.withUnsafeMutableBytes { rawOut in
            ttzip_fill_special_value(rawOut.baseAddress!, byteCount, desc)
        }

        XCTAssertEqual(filledBytes, byteCount)
        XCTAssertEqual(outData, rawData, "Special pattern fill must reconstruct exact pattern")
    }

    func testSpecialNaNDetection() {
        let count = 1024
        let nanPattern: UInt32 = 0x7FC00000 // IEEE-754 Single Precision Quiet NaN
        let nanArray = [UInt32](repeating: nanPattern, count: count)
        let byteCount = count * 4
        let rawData = Data(bytes: nanArray, count: byteCount)

        let desc = rawData.withUnsafeBytes { raw in
            ttzip_detect_uniform_block(raw.baseAddress!, byteCount, 4)
        }

        XCTAssertTrue(desc.is_uniform)
        XCTAssertEqual(desc.special_code, TTZIP_SPECIAL_NAN, "Single precision NaN must be recognized as TTZIP_SPECIAL_NAN")
    }

    func testNonUniformDataRejection() {
        let size = 65536
        var mixedData = Data(count: size)
        for i in 0..<size {
            mixedData[i] = UInt8(i % 256)
        }

        let desc = mixedData.withUnsafeBytes { raw in
            ttzip_detect_uniform_block(raw.baseAddress!, size, 1)
        }

        XCTAssertFalse(desc.is_uniform, "Non-uniform data must not be flagged as special value")
        XCTAssertEqual(desc.special_code, TTZIP_SPECIAL_STANDARD)
    }
}
