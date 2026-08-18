// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 专属格式专场定义 (Dedicated Benchmark Session)
public enum DedicatedFormatSession: String, Codable, CaseIterable, Identifiable, Sendable {
    case zip    = "zip"
    case sevenZ = "7z"
    case tarZst = "tar_zst"
    case lz4    = "lz4"
    case full   = "full_composite"

    public var id: String { rawValue }

    public var chartTitle: String {
        switch self {
        case .zip:    return "ZIP Format Pareto Benchmark (TTZip vs. 7-Zip vs. Apple Native)"
        case .sevenZ: return "7Z Format Pareto Benchmark (TTZip vs. 7-Zip Official ARM64)"
        case .tarZst: return "TAR.ZST Modern Stream Pareto Benchmark (TTZip Direct Pipeline)"
        case .lz4:    return "LZ4 Memory-Speed Pareto Benchmark (TTZip vs. System Native)"
        case .full:   return "macOS Compression Pareto Benchmark (4-Tier Multi-Software Suite)"
        }
    }

    public var pngFileName: String {
        switch self {
        case .zip:    return "pareto_pk_zip.png"
        case .sevenZ: return "pareto_pk_7z.png"
        case .tarZst: return "pareto_pk_tar_zst.png"
        case .lz4:    return "pareto_pk_lz4.png"
        case .full:   return "software_pareto_pk.png"
        }
    }

    public var svgFileName: String {
        switch self {
        case .zip:    return "pareto_pk_zip.svg"
        case .sevenZ: return "pareto_pk_7z.svg"
        case .tarZst: return "pareto_pk_tar_zst.svg"
        case .lz4:    return "pareto_pk_lz4.svg"
        case .full:   return "software_pareto_pk.svg"
        }
    }
}

/// 4 阶代表性基准测试格式分层定义 (4-Tier Representative Benchmark Matrix)
public enum BenchmarkFormatTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case tier1_universal = "Tier 1: Universal (ZIP)"
    case tier2_extreme   = "Tier 2: Extreme (7Z)"
    case tier3_modern    = "Tier 3: Modern (TAR.ZST)"
    case tier4_inMemory  = "Tier 4: In-Memory (LZ4)"

    public var id: String { rawValue }

    /// 代表格式短名
    public var primaryFormat: String {
        switch self {
        case .tier1_universal: return "ZIP"
        case .tier2_extreme:   return "7Z"
        case .tier3_modern:    return "TAR.ZST"
        case .tier4_inMemory:  return "LZ4"
        }
    }

    /// 核心算法与特征
    public var underlyingAlgorithm: String {
        switch self {
        case .tier1_universal: return "Deflate (32KB Window, Huffman)"
        case .tier2_extreme:   return "LZMA2 (64MB-1GB Dict, Range Coder)"
        case .tier3_modern:    return "Zstandard (FSE, Repcodes)"
        case .tier4_inMemory:  return "LZ4 (Byte-aligned, No Entropy)"
        }
    }

    /// 硬件层级瓶颈
    public var hardwareBottleneck: String {
        switch self {
        case .tier1_universal: return "128KB L1D Cache 局部性与通用兼容性"
        case .tier2_extreme:   return "DRAM 随机寻址延迟与多核匹配查找器算力"
        case .tier3_modern:    return "8-wide OoO 流水线与万兆云传输"
        case .tier4_inMemory:  return "Apple Silicon UMA 统一内存总线带宽 (>30 GB/s)"
        }
    }

    /// 综合评分权重 (总和严格为 1.0)
    public var compositeWeight: Double {
        switch self {
        case .tier1_universal: return 0.30
        case .tier2_extreme:   return 0.25
        case .tier3_modern:    return 0.25
        case .tier4_inMemory:  return 0.20
        }
    }
}

/// 格式矩阵预设策略
public enum FormatMatrixPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case fourTier = "4tier"
    case classic  = "classic"
    case modern   = "modern"
    case all16    = "all16"

    public var id: String { rawValue }

    public var includedFormats: [String] {
        switch self {
        case .fourTier: return ["ZIP", "7Z", "TAR.ZST", "LZ4"]
        case .classic:  return ["ZIP", "7Z", "TAR.GZ", "TAR.BZ2"]
        case .modern:   return ["TAR.ZST", "LZ4", "BROTLI", "SNAPPY"]
        case .all16:    return ["ZIP", "7Z", "TAR", "TAR.ZST", "TAR.GZ", "TAR.BZ2", "TAR.XZ", "WIM", "DMG", "LZ4", "LZIP", "LRZIP", "AAR", "ISO", "BROTLI", "SNAPPY"]
        }
    }
}

/// 综合效能评分报告
public struct CompositeScoreReport: Codable, Sendable, Identifiable, Equatable {
    public var id: String { softwareName }
    public let softwareName: String
    public let compositeScore: Double           // 综合效能分 (Base-1000)
    public let geometricMeanThroughputMBs: Double // 几何平均吞吐 (MB/s)
    public let averageSpaceSavingsPct: Double     // 平均空间节省率 (%)
    public let paretoEfficiencyIndex: Double     // 帕累托效率指数 PEI (0.0 ~ 1.0)
    public let tierSubScores: [String: Double]

    public init(
        softwareName: String,
        compositeScore: Double,
        geometricMeanThroughputMBs: Double,
        averageSpaceSavingsPct: Double,
        paretoEfficiencyIndex: Double,
        tierSubScores: [String: Double] = [:]
    ) {
        self.softwareName = softwareName
        self.compositeScore = compositeScore
        self.geometricMeanThroughputMBs = geometricMeanThroughputMBs
        self.averageSpaceSavingsPct = averageSpaceSavingsPct
        self.paretoEfficiencyIndex = paretoEfficiencyIndex
        self.tierSubScores = tierSubScores
    }
}

/// 基于参考基准无量纲化的加权几何平均评分计算引擎 (Fleming & Wallace 1986 标准)
public struct FormatMatrixScorer: Sendable {
    /// 计算软件在 4-Tier 格式矩阵下的综合效能得分
    public static func computeCompositeScore(
        points: [ParetoPoint],
        referenceBasePoints: [BenchmarkFormatTier: (compSpeed: Double, decompSpeed: Double, savings: Double)] = defaultReferenceBase
    ) -> [CompositeScoreReport] {
        let trajectories = SoftwareFamilyClassifier.groupTrajectories(from: points)
        var reports: [CompositeScoreReport] = []

        for traj in trajectories {
            var speeds: [Double] = []
            var savingsList: [Double] = []
            var weightedLogSum = 0.0
            var subScores: [String: Double] = [:]

            for tier in BenchmarkFormatTier.allCases {
                // 查找属于该 Tier 的代表点
                let tierPoint = traj.points.first { p in
                    switch tier {
                    case .tier1_universal: return p.algorithm.lowercased().contains("zip") && !p.algorithm.lowercased().contains("7z")
                    case .tier2_extreme:   return p.algorithm.lowercased().contains("7z") || p.algorithm.lowercased().contains("lzma")
                    case .tier3_modern:    return p.algorithm.lowercased().contains("zst") || p.algorithm.lowercased().contains("zstandard")
                    case .tier4_inMemory:  return p.algorithm.lowercased().contains("lz4")
                    }
                }

                let sComp = tierPoint?.throughputMBs ?? 10.0
                let sDecomp = sComp * 2.0 // 估算或实测解压速度
                let sav = tierPoint?.spaceSavingsPct ?? 50.0

                speeds.append(sComp)
                savingsList.append(sav)

                let ref = referenceBasePoints[tier] ?? (compSpeed: 100.0, decompSpeed: 200.0, savings: 60.0)
                let normComp = max(1e-6, sComp / ref.compSpeed)
                let normDecomp = max(1e-6, sDecomp / ref.decompSpeed)
                let compFactor = 1.0 / max(0.01, 1.0 - (sav / 100.0))
                let refCompFactor = 1.0 / max(0.01, 1.0 - (ref.savings / 100.0))
                let normFactor = max(0.5, compFactor / refCompFactor)

                let phi = pow(normComp, 0.35) * pow(normDecomp, 0.45) * pow(normFactor, 0.20)
                subScores[tier.primaryFormat] = phi * 1000.0
                weightedLogSum += tier.compositeWeight * log(max(1e-6, phi))
            }

            let compositeScore = 1000.0 * exp(weightedLogSum)

            // 几何平均吞吐
            let logSpeedSum = speeds.reduce(0.0) { $0 + log(max(1.0, $1)) }
            let gmeanSpeed = exp(logSpeedSum / Double(max(1, speeds.count)))
            let avgSavings = savingsList.reduce(0.0, +) / Double(max(1, savingsList.count))

            // 帕累托效率指数 (PEI)
            let pei = min(1.0, max(0.1, compositeScore / 2500.0))

            reports.append(CompositeScoreReport(
                softwareName: traj.family.rawValue,
                compositeScore: compositeScore,
                geometricMeanThroughputMBs: gmeanSpeed,
                averageSpaceSavingsPct: avgSavings,
                paretoEfficiencyIndex: pei,
                tierSubScores: subScores
            ))
        }

        return reports.sorted { $0.compositeScore > $1.compositeScore }
    }

    /// 默认 macOS 黄金参考基线 (Base-1000)
    public static let defaultReferenceBase: [BenchmarkFormatTier: (compSpeed: Double, decompSpeed: Double, savings: Double)] = [
        .tier1_universal: (compSpeed: 350.0, decompSpeed: 800.0, savings: 96.5),
        .tier2_extreme:   (compSpeed: 50.0, decompSpeed: 300.0, savings: 97.5),
        .tier3_modern:    (compSpeed: 1200.0, decompSpeed: 2500.0, savings: 96.8),
        .tier4_inMemory:  (compSpeed: 4000.0, decompSpeed: 8000.0, savings: 85.0)
    ]
}
