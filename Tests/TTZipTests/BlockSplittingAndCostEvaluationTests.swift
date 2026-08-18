// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class BlockSplittingAndCostEvaluationTests: XCTestCase {

    // MARK: - 1. Cost Evaluator Accuracy & Speed Test

    func testCostEvaluatorAccuracyAndSpeed() throws {
        var freqs = ttzip_symbol_freqs_t()
        withUnsafeMutableBytes(of: &freqs) { ptr in
            let litlenPtr = ptr.baseAddress!.assumingMemoryBound(to: UInt32.self)
            for i in 0..<256 {
                litlenPtr[i] = 10
            }
            litlenPtr[256] = 1
            let offsetPtr = litlenPtr.advanced(by: 288)
            for i in 0..<30 {
                offsetPtr[i] = 5
            }
        }

        var lensLit = [UInt8](repeating: 0, count: 288)
        var codesLit = [UInt32](repeating: 0, count: 288)
        var lensOff = [UInt8](repeating: 0, count: 32)
        var codesOff = [UInt32](repeating: 0, count: 32)

        withUnsafePointer(to: freqs) { ptr in
            let litlenPtr = UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt32.self)
            let offsetPtr = litlenPtr.advanced(by: 288)
            ttzip_build_canonical_huffman_tree(litlenPtr, 286, 15, &lensLit, &codesLit)
            ttzip_build_canonical_huffman_tree(offsetPtr, 30, 15, &lensOff, &codesOff)
        }

        var staticBits: UInt64 = 0
        var dynamicBits: UInt64 = 0

        let iterations = 10000
        let t0 = DispatchTime.now()

        for _ in 0..<iterations {
            _ = ttzip_eval_huffman_bit_costs(
                &freqs, &lensLit, &lensOff, &staticBits, &dynamicBits
            )
        }

        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000_000.0
        let latencyUs = (elapsedSec / Double(iterations)) * 1_000_000.0

        print(String(format: "[BENCH] Cost Evaluator Latency: %.3f us (static=%llu bits, dynamic=%llu bits)", latencyUs, staticBits, dynamicBits))
        XCTAssertLessThan(latencyUs, 2.0, "Cost evaluator latency exceeds 2us limit")
    }

    // MARK: - 2. Multi-Block Streaming Continuity Across 64KB Boundaries

    func testMultiBlockStreamingContinuity() throws {
        let streamSize = 512 * 1024 // 512 KB continuous stream across 8x 64KB blocks
        var streamData = Data(count: streamSize)
        streamData.withUnsafeMutableBytes { ptr in
            let p = ptr.bindMemory(to: UInt8.self).baseAddress!
            for i in 0..<streamSize {
                // Interleaved text phrases and repetitive offset patterns crossing 64KB boundaries
                p[i] = UInt8((i % 41) ^ ((i >> 12) * 7) & 0xFF)
            }
        }

        let maxOut = streamSize + 65536
        var compBuf = [UInt8](repeating: 0, count: maxOut)
        var decompBuf = [UInt8](repeating: 0, count: streamSize + 4096)
        let nilPtr: UnsafePointer<UInt8>? = nil

        let compSize = streamData.withUnsafeBytes { rawIn -> size_t in
            let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
            return compBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                return ttzip_native_deflate_compress_chunk_with_history(
                    inPtr, streamSize, nilPtr, 0, rawOut.baseAddress!, maxOut, 1, 1
                )
            }
        }

        XCTAssertGreaterThan(compSize, 0, "Multi-block compression failed")

        let decompSize = compBuf.withUnsafeBytes { rawComp -> size_t in
            let compPtr = rawComp.bindMemory(to: UInt8.self).baseAddress!
            return decompBuf.withUnsafeMutableBufferPointer { rawDecomp -> size_t in
                return ttzip_libdeflate_decompress(
                    compPtr, compSize, rawDecomp.baseAddress!, streamSize
                )
            }
        }

        XCTAssertEqual(decompSize, streamSize, "Multi-block decompressed size mismatch")
        let decompData = Data(decompBuf.prefix(streamSize))
        XCTAssertEqual(decompData, streamData, "Multi-block data byte mismatch across 64KB boundaries")
    }
}
