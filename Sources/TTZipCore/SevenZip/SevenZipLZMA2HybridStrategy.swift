// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// LZMA2 codec execution routing mode.
public enum LZMA2RouteMode: String, Sendable, Codable {
    /// Level 1 fast mode: Direct ARM64 NEON vectorized match finder and branchless range coder.
    case neonFastPath
    /// Level 3-9 high compression: Parallel radix match finder with multi-threaded pipeline.
    case fastLZMA2Parallel
    /// Sparse zero-block fast bypass.
    case zeroBlockBypass
}

/// Hybrid dual-engine strategy configuration for 7z / LZMA2 workloads.
public struct SevenZipLZMA2HybridStrategy: Sendable {
    public let level: Int
    public let dictionarySize: Int
    public let threadBudget: Int
    public let maxMemoryBytes: Int
    public let routeMode: LZMA2RouteMode

    public init(
        level: Int,
        dictionarySize: Int,
        threadBudget: Int,
        maxMemoryBytes: Int = 536870912,
        routeMode: LZMA2RouteMode
    ) {
        self.level = level
        self.dictionarySize = dictionarySize
        self.threadBudget = threadBudget
        self.maxMemoryBytes = maxMemoryBytes
        self.routeMode = routeMode
    }

    /// Resolves optimal LZMA2 execution route based on compression level and payload characteristics.
    public static func resolve(
        level: ArchiveCompressionLevel,
        isZeroBlock: Bool = false,
        threadBudget: Int = 0
    ) -> SevenZipLZMA2HybridStrategy {
        let rawLevel = level.rawValue
        let lvl = max(0, min(9, rawLevel))

        if isZeroBlock {
            return SevenZipLZMA2HybridStrategy(
                level: 1,
                dictionarySize: 4096,
                threadBudget: 1,
                routeMode: .zeroBlockBypass
            )
        }

        if lvl <= 1 {
            return SevenZipLZMA2HybridStrategy(
                level: 1,
                dictionarySize: 65536,
                threadBudget: threadBudget,
                routeMode: .neonFastPath
            )
        }

        // Level 3 - 9
        let dictSize: Int
        switch lvl {
        case 2, 3:
            dictSize = 4 * 1024 * 1024
        case 4, 5:
            dictSize = 16 * 1024 * 1024
        case 6, 7:
            dictSize = 32 * 1024 * 1024
        default:
            dictSize = 64 * 1024 * 1024
        }

        return SevenZipLZMA2HybridStrategy(
            level: lvl,
            dictionarySize: dictSize,
            threadBudget: threadBudget,
            maxMemoryBytes: 536870912,
            routeMode: .fastLZMA2Parallel
        )
    }
}
