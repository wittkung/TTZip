// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// Test suite validating ARM64 RBIT-accelerated in-place canonical Huffman code generation and Kraft-McMillan limits.
final class InPlaceHuffmanTests: XCTestCase {

    /// Verifies bit reversal correctness using ARM64 RBIT instructions.
    func testInPlaceHuffman_ARM64RBIT_BitReversal_Correctness() {
        // Known bit patterns
        XCTAssertEqual(InPlaceHuffmanAdapter.bitReverse(code: 0b1, len: 1), 0b1)
        XCTAssertEqual(InPlaceHuffmanAdapter.bitReverse(code: 0b10, len: 2), 0b01)
        XCTAssertEqual(InPlaceHuffmanAdapter.bitReverse(code: 0b110, len: 3), 0b011)
        XCTAssertEqual(InPlaceHuffmanAdapter.bitReverse(code: 0b10110, len: 5), 0b01101)
        XCTAssertEqual(InPlaceHuffmanAdapter.bitReverse(code: 0b101010101010101, len: 15), 0b101010101010101)
    }

    /// Verifies Kraft-McMillan inequality and maximum codeword length limit (<= 15 bits) on standard 288-symbol alphabet.
    func testInPlaceHuffman_StandardAlphabet_KraftEqualityAndLengthLimit() {
        // 288 symbols litlen alphabet with realistic zip frequency distribution
        var freqs = [UInt32](repeating: 0, count: 288)
        for i in 0..<288 {
            freqs[i] = UInt32((i + 1) * (i + 1))
        }

        let table = InPlaceHuffmanAdapter.makeCanonicalCode(frequencies: freqs, maxCodewordLen: 15, bitReverse: false)

        XCTAssertEqual(table.numSymbols, 288)
        XCTAssertEqual(table.codewordLengths.count, 288)
        XCTAssertEqual(table.reversedCodewords.count, 288)

        // Verify all codeword lengths <= 15
        for (sym, len) in table.codewordLengths.enumerated() {
            XCTAssertGreaterThanOrEqual(len, 1, "Non-zero frequency symbol \(sym) must have len >= 1")
            XCTAssertLessThanOrEqual(len, 15, "Symbol \(sym) must not exceed 15 bits")
        }

        // Verify Kraft-McMillan inequality: Sum(2^-len) <= 1.0
        var kraftSum: Double = 0.0
        for len in table.codewordLengths {
            if len > 0 {
                kraftSum += pow(2.0, -Double(len))
            }
        }
        XCTAssertLessThanOrEqual(kraftSum, 1.0000000001, "Kraft-McMillan inequality must hold: sum = \(kraftSum)")
    }

    /// Verifies length-limited clipping on extreme skewed symbol frequencies.
    func testInPlaceHuffman_ExtremeSkewedDistribution_LengthLimitedClipping() {
        // Fibonacci-like extreme skew trying to force tree depth > 15
        var freqs = [UInt32](repeating: 0, count: 288)
        var a: UInt32 = 1
        var b: UInt32 = 1
        for i in 0..<30 {
            freqs[i] = a
            let next = a &+ b
            a = b
            b = next
        }

        let table = InPlaceHuffmanAdapter.makeCanonicalCode(frequencies: freqs, maxCodewordLen: 15, bitReverse: true)

        for len in table.codewordLengths {
            XCTAssertLessThanOrEqual(len, 15, "Even on extreme skew, codeword lengths must be clipped to <= 15")
        }
    }

    /// Verifies canonical code generation edge cases with 1 or 2 non-zero symbols.
    func testInPlaceHuffman_EdgeCases_FewSymbols() {
        // Single symbol
        var singleFreq = [UInt32](repeating: 0, count: 288)
        singleFreq[42] = 100
        let singleTable = InPlaceHuffmanAdapter.makeCanonicalCode(frequencies: singleFreq, maxCodewordLen: 15)
        XCTAssertEqual(singleTable.codewordLengths[42], 1)

        // Two symbols
        var twoFreq = [UInt32](repeating: 0, count: 288)
        twoFreq[10] = 50
        twoFreq[20] = 50
        let twoTable = InPlaceHuffmanAdapter.makeCanonicalCode(frequencies: twoFreq, maxCodewordLen: 15)
        XCTAssertEqual(twoTable.codewordLengths[10], 1)
        XCTAssertEqual(twoTable.codewordLengths[20], 1)
    }

    /// Measures 288-symbol canonical Huffman tree generation latency microbenchmark.
    func testInPlaceHuffman_MicrobenchmarkLatency() {
        var freqs = [UInt32](repeating: 0, count: 288)
        for i in 0..<288 {
            freqs[i] = UInt32((i * 37 + 13) % 1000)
        }

        var lens = [UInt8](repeating: 0, count: 288)
        var codewords = [UInt32](repeating: 0, count: 288)

        let iterations = 1000
        let start = PlatformMonotonicTimer.nowNanoseconds()

        freqs.withUnsafeBufferPointer { fPtr in
            lens.withUnsafeMutableBufferPointer { lPtr in
                codewords.withUnsafeMutableBufferPointer { cPtr in
                    for _ in 0..<iterations {
                        InPlaceHuffmanAdapter.makeCanonicalCode(
                            freqPtr: fPtr.baseAddress!,
                            lensPtr: lPtr.baseAddress!,
                            codewordsPtr: cPtr.baseAddress!,
                            count: 288,
                            maxCodewordLen: 15,
                            bitReverse: true
                        )
                    }
                }
            }
        }

        let elapsedNanos = PlatformMonotonicTimer.nowNanoseconds() - start
        let avgMicros = Double(elapsedNanos) / Double(iterations) / 1000.0
        TTLogger.debug("⚡ [In-Place Huffman] 288-symbol Tree Generation Average Latency: \(String(format: "%.3f", avgMicros)) μs")

        #if DEBUG
        XCTAssertLessThanOrEqual(avgMicros, 10.0, "Debug mode latency floor")
        #else
        XCTAssertLessThanOrEqual(avgMicros, 1.5, "Release mode latency floor")
        #endif
    }
}
