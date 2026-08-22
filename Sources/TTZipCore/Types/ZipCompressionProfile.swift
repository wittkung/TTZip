// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Strongly-typed compression profile model for ZIP Deflate operations.
public struct ZipCompressionProfile: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let level: ArchiveCompressionLevel
    public let deflateLevel: Int32
    public let zopfliIterations: Int32
    public let blockSplitting: Bool
    public let maxBlockSplits: Int32
    public let earlyExitThreshold: Double
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

// MARK: - Standard Presets

extension ZipCompressionProfile {
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

    public static let normal = maximum
    public static let fastPlus = fast

    public static let allProfiles: [ZipCompressionProfile] = [
        .store,
        .fast,
        .maximum,
        .high,
        .graphFast,
        .ultraZopfli,
        .extremePeak
    ]

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
