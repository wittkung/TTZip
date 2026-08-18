// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: Adaptive 300KB/5KB Deflate Block Splitter Adapter.
///
/// Direct passthrough to `ttzip_adaptive_block_split` C engine for entropy phase-shift detection.
public enum AdaptiveBlockSplitAdapter {

    public enum BlockType: Int, Sendable {
        case stored = 0
        case staticHuffman = 1
        case dynamicHuffman = 2
    }

    public struct SplitDecision: Sendable {
        public let shouldSplit: Bool
        public let selectedType: BlockType
        public let estimatedBitCost: UInt32

        public init(shouldSplit: Bool, selectedType: BlockType, estimatedBitCost: UInt32) {
            self.shouldSplit = shouldSplit
            self.selectedType = selectedType
            self.estimatedBitCost = estimatedBitCost
        }
    }

    /// Evaluates the minimal bit cost block type across Dynamic, Static, and Stored modes.
    @inlinable
    public static func evaluateBestBlockType(
        dynamicCost: UInt32,
        staticCost: UInt32,
        blockLength: UInt32,
        bitcount: UInt32 = 0
    ) -> (BlockType, UInt32) {
        var bestCost: UInt32 = 0
        let typeRaw = ttzip_eval_best_block_type(dynamicCost, staticCost, blockLength, bitcount, &bestCost)
        let blockType = BlockType(rawValue: Int(typeRaw.rawValue)) ?? .dynamicHuffman
        return (blockType, bestCost)
    }
}
