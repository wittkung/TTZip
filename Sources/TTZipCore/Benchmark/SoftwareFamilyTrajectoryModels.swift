// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
    case minizipNg     = "minizip-ng"
    case libdeflate    = "libdeflate"
    case zopfli        = "zopfli"
    case advzip        = "advzip"
    case appleNative   = "Apple Native"
    case keka          = "Keka"
    case ouch          = "ouch"
    case bandizip      = "Bandizip"
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
        case .minizipNg:     return "#84CC16" // Lime Green / Chartreuse
        case .libdeflate:    return "#7C3AED" // Deep Purple
        case .zopfli:        return "#EA4335" // Google Red / Coral
        case .advzip:        return "#B45309" // Dark Amber
        case .appleNative:   return "#DC2626" // Crimson Red
        case .keka:          return "#0D9488" // Teal / Jade
        case .ouch:          return "#E11D48" // Rose Red (Rust ouch)
        case .bandizip:      return "#0284C7" // Sky Blue
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
        } else if lower.contains("minizip") {
            return .minizipNg
        } else if lower.contains("7-zip") || lower.contains("7zip") || lower.contains("7zz") || lower.contains("p7zip") {
            return .sevenZip
        } else if lower.contains("apple") || lower.contains("ditto") || lower.contains("bom") || lower.contains("archive utility") {
            return .appleNative
        } else if lower.contains("keka") {
            return .keka
        } else if lower.contains("ouch") {
            return .ouch
        } else if lower.contains("bandizip") || lower.contains("bc") {
            return .bandizip
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
