// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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

// MARK: - 软件家族聚类与学术级轨迹建模 (DeepSWE / Gemini 3.7 Flash Architecture)

/// 软件家族品牌定义
public enum SoftwareFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case ttzip         = "TTZip"
    case zstd          = "Zstandard (Meta)"
    case lz4           = "LZ4 (Yann Collet)"
    case xz            = "XZ (LZMA2)"
    case brotli        = "Brotli (Google)"
    case sevenZip      = "7-Zip"
    case pigz          = "pigz"
    case libdeflate    = "libdeflate"
    case zopfli        = "zopfli"
    case advzip        = "advzip"
    case appleNative   = "Apple Native"
    case keka          = "Keka"
    case other         = "Other"

    public var id: String { rawValue }

    /// 品牌主视觉色 (HEX)
    public var brandColorHex: String {
        switch self {
        case .ttzip:         return "#2563EB" // Royal Blue (Hero)
        case .zstd:          return "#6366F1" // Electric Indigo
        case .lz4:           return "#06B6D4" // Cyan
        case .xz:            return "#8B5CF6" // Violet
        case .brotli:        return "#EC4899" // Hot Pink
        case .sevenZip:      return "#D97706" // Amber / Warm Bronze
        case .pigz:          return "#059669" // Emerald Green
        case .libdeflate:    return "#7C3AED" // Deep Purple
        case .zopfli:        return "#EA4335" // Google Red / Coral
        case .advzip:        return "#B45309" // Dark Amber
        case .appleNative:   return "#DC2626" // Crimson Red
        case .keka:          return "#0D9488" // Teal / Jade
        case .other:         return "#64748B" // Slate
        }
    }

    /// 是否作为 Hero 软件渲染演进光晕带与突出药丸徽章
    public var isHero: Bool { self == .ttzip }

    /// 主轨迹线条宽度
    public var lineWidth: Double { isHero ? 2.8 : 2.2 }

    /// 轨迹光晕带宽度 (仅 Hero 具备)
    public var haloRibbonWidth: Double { isHero ? 22.0 : 0.0 }
}

/// 软件家族轨迹线模型
public struct SoftwareFamilyTrajectory: Sendable, Identifiable {
    public var id: String { family.rawValue }
    public let family: SoftwareFamily
    public let points: [ParetoPoint]
    public let heroPillPoint: ParetoPoint?

    public init(family: SoftwareFamily, points: [ParetoPoint], heroPillPoint: ParetoPoint? = nil) {
        self.family = family
        self.points = points
        self.heroPillPoint = heroPillPoint
    }
}

/// 软件家族自动分类器
public struct SoftwareFamilyClassifier: Sendable {
    public static func classify(algorithm: String) -> SoftwareFamily {
        let lower = algorithm.lowercased()
        if lower.contains("ttzip") || lower.contains("ttz") {
            return .ttzip
        } else if lower.contains("zstd") {
            return .zstd
        } else if lower.contains("lz4") {
            return .lz4
        } else if lower.contains("brotli") {
            return .brotli
        } else if lower.contains("xz") || lower.contains("pixz") {
            return .xz
        } else if lower.contains("zopfli") {
            return .zopfli
        } else if lower.contains("advzip") || lower.contains("advancecomp") {
            return .advzip
        } else if lower.contains("libdeflate") {
            return .libdeflate
        } else if lower.contains("pigz") {
            return .pigz
        } else if lower.contains("7-zip") || lower.contains("7zip") || lower.contains("7zz") || lower.contains("p7zip") {
            return .sevenZip
        } else if lower.contains("apple") || lower.contains("ditto") || lower.contains("bom") || lower.contains("archive utility") {
            return .appleNative
        } else if lower.contains("keka") {
            return .keka
        } else {
            return .other
        }
    }

    public static func groupTrajectories(from points: [ParetoPoint]) -> [SoftwareFamilyTrajectory] {
        var groups: [SoftwareFamily: [ParetoPoint]] = [:]
        for p in points {
            let fam = classify(algorithm: p.algorithm)
            groups[fam, default: []].append(p)
        }

        var trajectories: [SoftwareFamilyTrajectory] = []
        for fam in SoftwareFamily.allCases {
            if var famPoints = groups[fam], !famPoints.isEmpty {
                famPoints.sort { (a, b) -> Bool in
                    if a.spaceSavingsPct != b.spaceSavingsPct {
                        return a.spaceSavingsPct < b.spaceSavingsPct
                    }
                    return a.throughputMBs < b.throughputMBs
                }
                let heroPill = fam.isHero ? (famPoints.last(where: { $0.isParetoOptimal }) ?? famPoints.last) : nil
                trajectories.append(SoftwareFamilyTrajectory(family: fam, points: famPoints, heroPillPoint: heroPill))
            }
        }
        return trajectories
    }
}

/// 2D 三次贝塞尔曲线控制段
public struct CubicBezierSegment: Sendable {
    public let startPoint: (x: Double, y: Double)
    public let controlPoint1: (x: Double, y: Double)
    public let controlPoint2: (x: Double, y: Double)
    public let endPoint: (x: Double, y: Double)
}

/// Fritsch-Carlson (1980) 单调保形三次 Hermite 样条插值转换器 (用于 DeepSWE 无过冲平滑曲线)
public struct FritschCarlsonSplineCalculator: Sendable {
    public static func calculateBezierSegments(points: [(x: Double, y: Double)]) -> [CubicBezierSegment] {
        let n = points.count
        guard n >= 2 else { return [] }
        if n == 2 {
            let p0 = points[0]
            let p1 = points[1]
            let cp1 = (x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y + (p1.y - p0.y) / 3.0)
            let cp2 = (x: p1.x - (p1.x - p0.x) / 3.0, y: p1.y - (p1.y - p0.y) / 3.0)
            return [CubicBezierSegment(startPoint: p0, controlPoint1: cp1, controlPoint2: cp2, endPoint: p1)]
        }

        var h = [Double](repeating: 0, count: n - 1)
        var delta = [Double](repeating: 0, count: n - 1)

        for i in 0..<(n - 1) {
            let dx = points[i + 1].x - points[i].x
            h[i] = max(1.0, dx) // 保证像素间隔下界为 1px，杜绝除零导致斜率爆炸
            delta[i] = (points[i + 1].y - points[i].y) / h[i]
        }

        var d = [Double](repeating: 0, count: n)
        d[0] = delta[0]
        d[n - 1] = delta[n - 2]

        // 使用 Steffen / Brodlie 单调调和平均斜率计算 (Monotone Harmonic Limiter)
        for i in 1..<(n - 1) {
            if delta[i - 1] * delta[i] <= 0.0 {
                d[i] = 0.0 // 极值拐点处导数设为 0，防止过冲
            } else {
                let p = 2.0 * delta[i - 1] * delta[i] / (delta[i - 1] + delta[i])
                d[i] = p
            }
        }

        var segments: [CubicBezierSegment] = []
        for i in 0..<(n - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let segH = points[i + 1].x - points[i].x
            let cp1Y = p0.y + (d[i] * segH) / 3.0
            let cp2Y = p1.y - (d[i + 1] * segH) / 3.0
            let cp1 = (x: p0.x + segH / 3.0, y: cp1Y)
            let cp2 = (x: p1.x - segH / 3.0, y: cp2Y)
            segments.append(CubicBezierSegment(startPoint: p0, controlPoint1: cp1, controlPoint2: cp2, endPoint: p1))
        }
        return segments
    }
}
