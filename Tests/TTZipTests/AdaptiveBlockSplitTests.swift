// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class AdaptiveBlockSplitTests: XCTestCase {

    func testAdaptiveBlockSplit_ObservationSampling_L1Drift() {
        var stats = ttzip_block_split_stats_t()
        ttzip_block_split_init(&stats)

        // Simulate 6000 ASCII lowercase characters
        for _ in 0..<6000 {
            ttzip_block_split_observe_lit(&stats, UInt8(ascii: "a"))
        }

        // Simulate buffer pointers
        let dummyBuf = [UInt8](repeating: 0, count: 20000)
        dummyBuf.withUnsafeBufferPointer { ptr in
            let blockBegin = ptr.baseAddress!
            let nextPtr = blockBegin + 6000
            let endPtr = blockBegin + 20000

            // Initially before shift, merge stats
            _ = ttzip_should_end_block(&stats, blockBegin, nextPtr, endPtr)

            // Now introduce sudden phase shift: 1000 high-bit binary bytes
            for _ in 0..<1000 {
                ttzip_block_split_observe_lit(&stats, 0xFE)
            }

            let shiftPtr = blockBegin + 7000
            let shouldSplit = ttzip_should_end_block(&stats, blockBegin, shiftPtr, endPtr)
            XCTAssertTrue(shouldSplit, "Sharp entropy shift from ASCII to binary high-bits must trigger should_end_block")
        }
    }

    func testAdaptiveBlockSplit_ThreeWayArbitration() {
        // 1. Incompressible random noise: Store should win
        let (storeType, _) = AdaptiveBlockSplitAdapter.evaluateBestBlockType(
            dynamicCost: 80000,
            staticCost: 82000,
            blockLength: 8000
        )
        XCTAssertEqual(storeType, .stored, "High entropy payload should select .stored")

        // 2. Structured text: Dynamic Huffman should win
        let (dynamicType, _) = AdaptiveBlockSplitAdapter.evaluateBestBlockType(
            dynamicCost: 24000,
            staticCost: 35000,
            blockLength: 8000
        )
        XCTAssertEqual(dynamicType, .dynamicHuffman, "Highly compressible structured payload should select .dynamicHuffman")

        // 3. Small block where static is smaller than dynamic header: Static should win
        let (staticType, _) = AdaptiveBlockSplitAdapter.evaluateBestBlockType(
            dynamicCost: 15000, // Large tree header penalty
            staticCost: 12000,
            blockLength: 2000
        )
        XCTAssertEqual(staticType, .staticHuffman, "Small block where static cost < dynamic cost should select .staticHuffman")
    }

    func testAdaptiveBlockSplit_TailAbsorption() {
        let dummyBuf = [UInt8](repeating: 0, count: 304000)
        dummyBuf.withUnsafeBufferPointer { ptr in
            let blockBegin = ptr.baseAddress!
            let endPtr = blockBegin + 304000

            // Remainder 4000 < MIN_BLOCK_LENGTH (5000), so choose_max_block_end absorbs to in_end
            let maxEnd = ttzip_choose_max_block_end(blockBegin, endPtr, 300000)
            XCTAssertEqual(maxEnd, endPtr, "Sub-5000B tail should be absorbed into current block to avoid micro-block expansion")
        }
    }
}
