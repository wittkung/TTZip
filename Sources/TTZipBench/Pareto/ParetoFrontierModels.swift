// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import Foundation

/// 帕累托 2D 散点数据模型 (吞吐 MB/s vs 空间节省率 %)
public struct ParetoPoint: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let algorithm: String
    public let level: Int
    public let throughputMBs: Double
    public let spaceSavingsPct: Double
    public let compressedBytes: Int64
    public let uncompressedBytes: Int64
    public var paretoRank: Int
    public var isParetoOptimal: Bool
    public var isOnConvexEnvelope: Bool

    public init(
        id: String,
        algorithm: String,
        level: Int,
        throughputMBs: Double,
        spaceSavingsPct: Double,
        compressedBytes: Int64,
        uncompressedBytes: Int64,
        paretoRank: Int = 1,
        isParetoOptimal: Bool = false,
        isOnConvexEnvelope: Bool = false
    ) {
        self.id = id
        self.algorithm = algorithm
        self.level = level
        self.throughputMBs = throughputMBs
        self.spaceSavingsPct = spaceSavingsPct
        self.compressedBytes = compressedBytes
        self.uncompressedBytes = uncompressedBytes
        self.paretoRank = paretoRank
        self.isParetoOptimal = isParetoOptimal
        self.isOnConvexEnvelope = isOnConvexEnvelope
    }

    public init(
        algorithm: String,
        level: Int,
        throughputMBs: Double,
        spaceSavingsPct: Double,
        compressionRatio: Double = 1.0,
        id: String? = nil,
        compressedBytes: Int64 = 0,
        uncompressedBytes: Int64 = 0
    ) {
        self.id = id ?? "\(algorithm.lowercased().replacingOccurrences(of: " ", with: "_"))_l\(level)"
        self.algorithm = algorithm
        self.level = level
        self.throughputMBs = throughputMBs
        self.spaceSavingsPct = spaceSavingsPct
        self.compressedBytes = compressedBytes
        self.uncompressedBytes = uncompressedBytes
        self.paretoRank = 1
        self.isParetoOptimal = false
        self.isOnConvexEnvelope = false
    }
}

/// 帕累托前沿分析完整结果集
public struct ParetoFrontierResult: Codable, Sendable, Equatable {
    public let totalPointsEvaluated: Int
    public let frontierPoints: [ParetoPoint]
    public let convexEnvelopePoints: [ParetoPoint]
    public let allPoints: [ParetoPoint]
    public let generatedAt: String

    public init(
        totalPointsEvaluated: Int,
        frontierPoints: [ParetoPoint],
        convexEnvelopePoints: [ParetoPoint],
        allPoints: [ParetoPoint],
        generatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.totalPointsEvaluated = totalPointsEvaluated
        self.frontierPoints = frontierPoints
        self.convexEnvelopePoints = convexEnvelopePoints
        self.allPoints = allPoints
        self.generatedAt = generatedAt
    }
}

/// 物理传输介质端到端耗时阶梯
public struct TransferSpeedTier: Codable, Sendable, Equatable {
    public let tierName: String
    public let bandwidthMBs: Double
    public let rawTransferSeconds: Double
    public let compressionSeconds: Double
    public let compressedTransferSeconds: Double
    public let decompressionSeconds: Double
    public let totalTurnaroundSeconds: Double
    public let speedupRatio: Double
    public var isParetoWinner: Bool

    public init(
        tierName: String,
        bandwidthMBs: Double,
        rawTransferSeconds: Double,
        compressionSeconds: Double,
        compressedTransferSeconds: Double,
        decompressionSeconds: Double,
        totalTurnaroundSeconds: Double,
        speedupRatio: Double,
        isParetoWinner: Bool = false
    ) {
        self.tierName = tierName
        self.bandwidthMBs = bandwidthMBs
        self.rawTransferSeconds = rawTransferSeconds
        self.compressionSeconds = compressionSeconds
        self.compressedTransferSeconds = compressedTransferSeconds
        self.decompressionSeconds = decompressionSeconds
        self.totalTurnaroundSeconds = totalTurnaroundSeconds
        self.speedupRatio = speedupRatio
        self.isParetoWinner = isParetoWinner
    }
}

/// 物理介质端到端耗时投影矩阵报告
public struct TransferSpeedReport: Codable, Sendable, Equatable {
    public let sourceSizeBytes: Int64
    public let algorithm: String
    public let level: Int
    public let tiers: [TransferSpeedTier]
    public let overallBestTierCount: Int

    public init(
        sourceSizeBytes: Int64,
        algorithm: String,
        level: Int,
        tiers: [TransferSpeedTier],
        overallBestTierCount: Int = 0
    ) {
        self.sourceSizeBytes = sourceSizeBytes
        self.algorithm = algorithm
        self.level = level
        self.tiers = tiers
        self.overallBestTierCount = overallBestTierCount
    }
}

/// 智能场景推荐方案
public struct ScenarioRecommendation: Codable, Sendable, Equatable {
    public let scenario: String
    public let measuredEntropy: Double
    public let trialCompressibilityRatio: Double
    public let recommendedAlgorithm: String
    public let recommendedLevel: Int
    public let rationale: String
    public let projectedThroughputMBs: Double
    public let projectedSpaceSavingsPct: Double
    public let probeDurationMs: Double

    public init(
        scenario: String,
        measuredEntropy: Double,
        trialCompressibilityRatio: Double,
        recommendedAlgorithm: String,
        recommendedLevel: Int,
        rationale: String,
        projectedThroughputMBs: Double,
        projectedSpaceSavingsPct: Double,
        probeDurationMs: Double
    ) {
        self.scenario = scenario
        self.measuredEntropy = measuredEntropy
        self.trialCompressibilityRatio = trialCompressibilityRatio
        self.recommendedAlgorithm = recommendedAlgorithm
        self.recommendedLevel = recommendedLevel
        self.rationale = rationale
        self.projectedThroughputMBs = projectedThroughputMBs
        self.projectedSpaceSavingsPct = projectedSpaceSavingsPct
        self.probeDurationMs = probeDurationMs
    }
}
