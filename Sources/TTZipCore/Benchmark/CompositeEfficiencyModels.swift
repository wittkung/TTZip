// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 评测场景权重 Profile
public enum BenchmarkScenarioProfile: String, Codable, Sendable, CaseIterable {
    case balanced = "balanced"   // α=0.35, β=0.35, γ=0.30 (默认平衡)
    case storage  = "storage"    // α=0.20, β=0.20, γ=0.60 (高压缩归档)
    case transfer = "transfer"   // α=0.45, β=0.45, γ=0.10 (高速传输与实时缓存)
    
    public var weights: (alpha: Double, beta: Double, gamma: Double) {
        switch self {
        case .balanced: return (0.35, 0.35, 0.30)
        case .storage:  return (0.20, 0.20, 0.60)
        case .transfer: return (0.45, 0.45, 0.10)
        }
    }
}

/// 单个 Tier 场景下的实测数据点
public struct TierBenchmarkMeasurement: Codable, Sendable {
    public let tier: BenchmarkTierCategory
    public let payloadBytes: Int64
    public let compressedBytes: Int64
    public let compressionSpeedMBs: Double
    public let decompressionSpeedMBs: Double
    public let compressionRatio: Double
    public let spaceSavingsPct: Double
    public let filesCount: Int
    
    public init(
        tier: BenchmarkTierCategory,
        payloadBytes: Int64,
        compressedBytes: Int64,
        compressionSpeedMBs: Double,
        decompressionSpeedMBs: Double,
        compressionRatio: Double,
        spaceSavingsPct: Double,
        filesCount: Int = 1
    ) {
        self.tier = tier
        self.payloadBytes = payloadBytes
        self.compressedBytes = compressedBytes
        self.compressionSpeedMBs = max(0.001, compressionSpeedMBs)
        self.decompressionSpeedMBs = max(0.001, decompressionSpeedMBs)
        self.compressionRatio = max(1.0, compressionRatio)
        self.spaceSavingsPct = spaceSavingsPct
        self.filesCount = filesCount
    }
}

/// 跨 5 大 Tier 加权几何平均聚合后的算法综合效能结果
public struct AlgorithmCompositeScore: Codable, Sendable, Identifiable {
    public var id: String { "\(algorithm.lowercased())_l\(level)" }
    public let algorithm: String
    public let level: Int
    
    // 跨语料加权几何平均指标
    public let geomCompSpeedMBs: Double
    public let geomDecompSpeedMBs: Double
    public let geomCompressionRatio: Double
    public let geomSpaceSavingsPct: Double
    
    // 综合效能指数与标准化得分 (Cobb-Douglas & SPECScore)
    public let compositeEfficiencyIndex: Double
    public let normalizedSpecScore: Double
    public let profile: BenchmarkScenarioProfile
    
    // 帕累托属性
    public var isParetoOptimal: Bool
    public var paretoRank: Int
    public var tierMeasurements: [TierBenchmarkMeasurement]
    
    public init(
        algorithm: String,
        level: Int,
        geomCompSpeedMBs: Double,
        geomDecompSpeedMBs: Double,
        geomCompressionRatio: Double,
        geomSpaceSavingsPct: Double,
        compositeEfficiencyIndex: Double,
        normalizedSpecScore: Double,
        profile: BenchmarkScenarioProfile = .balanced,
        isParetoOptimal: Bool = false,
        paretoRank: Int = 1,
        tierMeasurements: [TierBenchmarkMeasurement] = []
    ) {
        self.algorithm = algorithm
        self.level = level
        self.geomCompSpeedMBs = geomCompSpeedMBs
        self.geomDecompSpeedMBs = geomDecompSpeedMBs
        self.geomCompressionRatio = geomCompressionRatio
        self.geomSpaceSavingsPct = geomSpaceSavingsPct
        self.compositeEfficiencyIndex = compositeEfficiencyIndex
        self.normalizedSpecScore = normalizedSpecScore
        self.profile = profile
        self.isParetoOptimal = isParetoOptimal
        self.paretoRank = paretoRank
        self.tierMeasurements = tierMeasurements
    }
}

/// 5-Tier 多语料综合效能基准测试完整报告
public struct CompositeBenchmarkSuiteReport: Codable, Sendable {
    public let reportId: String
    public let timestamp: String
    public let systemInfo: String
    public let activeProfile: BenchmarkScenarioProfile
    public let referenceBaseline: String
    public let scores: [AlgorithmCompositeScore]
    public let paretoFrontier: [AlgorithmCompositeScore]
    
    public init(
        reportId: String,
        timestamp: String,
        systemInfo: String,
        activeProfile: BenchmarkScenarioProfile = .balanced,
        referenceBaseline: String = "ZIP-Deflate-L6",
        scores: [AlgorithmCompositeScore],
        paretoFrontier: [AlgorithmCompositeScore]
    ) {
        self.reportId = reportId
        self.timestamp = timestamp
        self.systemInfo = systemInfo
        self.activeProfile = activeProfile
        self.referenceBaseline = referenceBaseline
        self.scores = scores
        self.paretoFrontier = paretoFrontier
    }
}
