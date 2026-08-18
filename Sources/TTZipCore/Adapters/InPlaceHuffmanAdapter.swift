// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance zero-heap in-place Canonical Huffman Tree Builder Adapter.
///
/// Direct passthrough to CTTZipBridge `ttzip_make_canonical_huffman_code_inplace`
/// with single-cycle ARM64 RBIT bit-reversal and length-limited ($\le 15$) clipping.
public enum InPlaceHuffmanAdapter {

    public struct HuffmanCodeTable: Sendable {
        public let numSymbols: Int
        public let codewordLengths: [UInt8]
        public let reversedCodewords: [UInt32]

        public init(numSymbols: Int, codewordLengths: [UInt8], reversedCodewords: [UInt32]) {
            self.numSymbols = numSymbols
            self.codewordLengths = codewordLengths
            self.reversedCodewords = reversedCodewords
        }
    }

    /// Computes canonical length-limited Huffman codes in-place with zero heap allocations.
    ///
    /// - Parameters:
    ///   - frequencies: Array of symbol frequencies.
    ///   - maxCodewordLen: Maximum allowed codeword bit length ($\le 15$).
    ///   - bitReverse: If true, emits RFC 1951 bit-reversed codewords for LSB-first output.
    /// - Returns: Complete `HuffmanCodeTable` containing lengths and codewords.
    @inlinable
    public static func makeCanonicalCode(
        frequencies: [UInt32],
        maxCodewordLen: UInt8 = 15,
        bitReverse: Bool = true
    ) -> HuffmanCodeTable {
        let count = frequencies.count
        guard count >= 2 else {
            return HuffmanCodeTable(
                numSymbols: count,
                codewordLengths: Array(repeating: 0, count: count),
                reversedCodewords: Array(repeating: 0, count: count)
            )
        }

        var lengths = [UInt8](repeating: 0, count: count)
        var codewords = [UInt32](repeating: 0, count: count)

        frequencies.withUnsafeBufferPointer { freqBuf in
            lengths.withUnsafeMutableBufferPointer { lenBuf in
                codewords.withUnsafeMutableBufferPointer { codeBuf in
                    ttzip_make_canonical_huffman_code_inplace(
                        UInt32(count),
                        UInt32(maxCodewordLen),
                        freqBuf.baseAddress,
                        lenBuf.baseAddress,
                        codeBuf.baseAddress,
                        bitReverse
                    )
                }
            }
        }

        return HuffmanCodeTable(
            numSymbols: count,
            codewordLengths: lengths,
            reversedCodewords: codewords
        )
    }

    /// Computes canonical Huffman codes directly using provided memory buffers (zero allocation).
    @inlinable
    public static func makeCanonicalCode(
        freqPtr: UnsafePointer<UInt32>,
        lensPtr: UnsafeMutablePointer<UInt8>,
        codewordsPtr: UnsafeMutablePointer<UInt32>,
        count: Int,
        maxCodewordLen: UInt8 = 15,
        bitReverse: Bool = true
    ) {
        guard count >= 2 else { return }
        ttzip_make_canonical_huffman_code_inplace(
            UInt32(count),
            UInt32(maxCodewordLen),
            freqPtr,
            lensPtr,
            codewordsPtr,
            bitReverse
        )
    }

    /// Flips the lowest `len` bits of a codeword using single-cycle ARM64 RBIT instruction.
    @inlinable
    public static func bitReverse(code: UInt32, len: UInt8) -> UInt32 {
        return ttzip_canonical_bit_reverse(code, len)
    }
}
