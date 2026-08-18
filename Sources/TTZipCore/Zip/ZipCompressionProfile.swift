// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/**
 * @struct ZipCompressionProfile
 * @brief Strongly-typed physical compression profile model for ZIP Deflate operations.
 *
 * Implements a Single Source of Truth and Strategy Pattern:
 * 1. Eliminates implicit/opaque switch-case heuristics between abstract levels and C backends.
 * 2. Explicitly specifies physical parameters (native Deflate level, Zopfli iterations, block splitting).
 * 3. Transparently maps 1:1 with low-level C `TTZipZopfliOptions` structures.
 */
public struct ZipCompressionProfile: Sendable, Equatable, Identifiable {
    
    /// Unique profile identifier (e.g., "zip_tier_1_fast").
    public let id: String
    
    /// User, UI, and CLI display title (e.g., "Fast (1)").
    public let name: String
    
    /// Generic abstract compression level enum (.store, .level1 ... .level7).
    public let level: ArchiveCompressionLevel
    
    /// Low-level native C Deflate engine compression level (0..12).
    public let deflateLevel: Int32
    
    /// Graph-theoretic / Zopfli shortest path iteration count (0..15).
    public let zopfliIterations: Int32
    
    /// Whether dynamic entropy-guided optimal block splitting is active.
    public let blockSplitting: Bool
    
    /// Maximum number of split blocks permitted (0..15).
    public let maxBlockSplits: Int32
    
    /// Adaptive asymptotic cost convergence threshold (e.g., 0.0001 for 0.01%).
    public let earlyExitThreshold: Double
    
    /// Apple Silicon multi-core physical throughput floor in Release mode (MB/s).
    public let targetThroughputFloorMBs: Double
    
    public init(
        id: String,
        name: String,
        level: ArchiveCompressionLevel,
        deflateLevel: Int32,
        zopfliIterations: Int32,
        blockSplitting: Bool,
        maxBlockSplits: Int32,
        earlyExitThreshold: Double = 0.0001,
        targetThroughputFloorMBs: Double
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.deflateLevel = deflateLevel
        self.zopfliIterations = zopfliIterations
        self.blockSplitting = blockSplitting
        self.maxBlockSplits = maxBlockSplits
        self.earlyExitThreshold = earlyExitThreshold
        self.targetThroughputFloorMBs = targetThroughputFloorMBs
    }
}

// MARK: - The 7 Golden Standard Presets

extension ZipCompressionProfile {
    
    /// Tier 0: Direct Store (Zero-compression page aligned I/O direct write, throughput >= 6000 MB/s).
    public static let store = ZipCompressionProfile(
        id: "zip_tier_0_store",
        name: "Store (0)",
        level: .store,
        deflateLevel: 0,
        zopfliIterations: 0,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0,
        targetThroughputFloorMBs: 6000.0
    )
    
    /// Tier 1: Fast (Ultra-fast lightweight LZ77 greedy match finder, throughput >= 5000 MB/s).
    public static let fast = ZipCompressionProfile(
        id: "zip_tier_1_fast",
        name: "Fast (1)",
        level: .level1,
        deflateLevel: 1,
        zopfliIterations: 0,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 5000.0
    )
    
    /// Tier 2: Maximum (Deep pattern matching Deflate Level 2 with Sync-Flush, throughput >= 2500 MB/s).
    public static let maximum = ZipCompressionProfile(
        id: "zip_tier_2_maximum",
        name: "Maximum (2)",
        level: .level2,
        deflateLevel: 2,
        zopfliIterations: 0,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 2500.0
    )

    
    /// Tier 3: High Compression (Near-Optimal DP Deflate Level 12, bridging the 210x speed cliff, throughput >= 150 MB/s).
    public static let high = ZipCompressionProfile(
        id: "zip_tier_3_high",
        name: "High (3)",
        level: .level3,
        deflateLevel: 12,
        zopfliIterations: 0,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 150.0
    )
    
    /// Tier 4: Graph Fast (Lightweight 2-pass shortest-path DAG match parser, throughput >= 20 MB/s).
    public static let graphFast = ZipCompressionProfile(
        id: "zip_tier_4_graph_fast",
        name: "Graph Fast (4)",
        level: .level4,
        deflateLevel: 12,
        zopfliIterations: 2,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 20.0
    )
    
    /// Tier 5: Ultra Zopfli (In-process global shortest-path DAG parser, 5 iterations, throughput >= 4.0 MB/s).
    public static let ultraZopfli = ZipCompressionProfile(
        id: "zip_tier_5_ultra_zopfli",
        name: "Ultra Zopfli (5)",
        level: .level5,
        deflateLevel: 12,
        zopfliIterations: 5,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.00005,
        targetThroughputFloorMBs: 4.0
    )
    
    /// Tier 6: Extreme Peak (15 iterations iterative re-balancing & optimal dynamic block splitting, throughput >= 0.25 MB/s).
    public static let extremePeak = ZipCompressionProfile(
        id: "zip_tier_6_extreme_peak",
        name: "Extreme Peak (6)",
        level: .level6,
        deflateLevel: 12,
        zopfliIterations: 15,
        blockSplitting: true,
        maxBlockSplits: 15,
        earlyExitThreshold: 0.00005,
        targetThroughputFloorMBs: 0.25
    )
    
    /// Backward compatibility aliases for legacy code references.
    public static let normal = maximum
    public static let fastPlus = fast
    
    /// Complete set of all 7 golden standard compression profiles.
    public static let allProfiles: [ZipCompressionProfile] = [
        .store,
        .fast,
        .maximum,
        .high,
        .graphFast,
        .ultraZopfli,
        .extremePeak
    ]
    
    /**
     * Resolves the corresponding strongly-typed profile from an abstract compression level.
     *
     * @param level Abstract level enum.
     * @return Concrete matching ZipCompressionProfile.
     */
    public static func profile(for level: ArchiveCompressionLevel) -> ZipCompressionProfile {
        switch level {
        case .store:
            return .store
        case .fast5, .fast4, .fast3, .fast2, .fast1, .level1:
            return .fast
        case .level2:
            return .maximum
        case .level3:
            return .high
        case .level4:
            return .graphFast
        case .level5:
            return .ultraZopfli
        case .level6, .level7, .level8, .level9, .level10, .level11, .level12, .level13, .level14, .level15, .level16, .level17, .level18, .level19, .level20, .level21, .level22:
            return .extremePeak
        }
    }
}
