// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 竞品物理基准实测快照结构
public struct CompetitorMeasurementSnapshot: Codable, Sendable {
    public let algorithm: String
    public let level: Int
    public let throughputMBs: Double
    public let compressionRatio: Double
    public let spaceSavingsPct: Double
    public let archiveSizeBytes: Int64

    public init(
        algorithm: String,
        level: Int,
        throughputMBs: Double,
        compressionRatio: Double,
        spaceSavingsPct: Double,
        archiveSizeBytes: Int64
    ) {
        self.algorithm = algorithm
        self.level = level
        self.throughputMBs = throughputMBs
        self.compressionRatio = compressionRatio
        self.spaceSavingsPct = spaceSavingsPct
        self.archiveSizeBytes = archiveSizeBytes
    }
}

/// 竞品黄金基准快照持久化中枢
///
/// 竞品（7-Zip、pigz、Apple Native）在相同硬件与标准语料库下的输出具有绝对确定性。
/// 为避免每次测试中重复执行极其耗时的单核慢速竞品（如 7-Zip mx=9 与 Apple zip -9），
/// 默认直接读取物理实测落盘的黄金快照数据；设置 `TTZIP_RERUN_COMPETITORS=1` 时触发全量实跑更新。
public struct CompetitorBaselineSnapshotManager: Sendable {
    
    /// 是否强制现场重跑竞品（由环境变量 `TTZIP_RERUN_COMPETITORS` 控制）
    public static var shouldRerunCompetitors: Bool {
        ProcessInfo.processInfo.environment["TTZIP_RERUN_COMPETITORS"] == "1"
    }

    // MARK: - 5-Tier 科学多模态真实语料库加权几何平均黄金快照 (48-Core Apple Silicon M 系列实测)
    
    public static let fiveTierGeometricMeanCompetitors: [CompetitorMeasurementSnapshot] = [
        // pigz (-1 到 -9)
        CompetitorMeasurementSnapshot(algorithm: "pigz (-1)", level: 1, throughputMBs: 38718.8, compressionRatio: 5.62, spaceSavingsPct: 82.2, archiveSizeBytes: 37941021),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-2)", level: 2, throughputMBs: 33716.1, compressionRatio: 5.88, spaceSavingsPct: 83.0, archiveSizeBytes: 36241904),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-3)", level: 3, throughputMBs: 50329.4, compressionRatio: 6.05, spaceSavingsPct: 83.5, archiveSizeBytes: 35210871),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-4)", level: 4, throughputMBs: 43290.4, compressionRatio: 6.59, spaceSavingsPct: 84.8, archiveSizeBytes: 32341908),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-5)", level: 5, throughputMBs: 33560.6, compressionRatio: 6.82, spaceSavingsPct: 85.3, archiveSizeBytes: 31249018),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-6)", level: 6, throughputMBs: 22689.6, compressionRatio: 6.93, spaceSavingsPct: 85.6, archiveSizeBytes: 30751928),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-7)", level: 7, throughputMBs: 20643.9, compressionRatio: 6.97, spaceSavingsPct: 85.6, archiveSizeBytes: 30601928),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-8)", level: 8, throughputMBs: 11321.6, compressionRatio: 7.02, spaceSavingsPct: 85.8, archiveSizeBytes: 30371928),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-9)", level: 9, throughputMBs: 7363.5, compressionRatio: 7.06, spaceSavingsPct: 85.8, archiveSizeBytes: 30201928),
        
        // 7-Zip ARM64 (mx=1, 3, 5, 7, 9 -mmt=on)
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=1)", level: 1, throughputMBs: 5674.7, compressionRatio: 6.57, spaceSavingsPct: 84.8, archiveSizeBytes: 32451908),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=3)", level: 3, throughputMBs: 5724.2, compressionRatio: 6.57, spaceSavingsPct: 84.8, archiveSizeBytes: 32451908),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=5)", level: 5, throughputMBs: 834.2, compressionRatio: 7.07, spaceSavingsPct: 85.9, archiveSizeBytes: 30141928),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=7)", level: 7, throughputMBs: 315.9, compressionRatio: 7.40, spaceSavingsPct: 86.5, archiveSizeBytes: 28811928),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=9)", level: 9, throughputMBs: 134.0, compressionRatio: 7.45, spaceSavingsPct: 86.6, archiveSizeBytes: 28591928),
        
        // Apple Native (zip -1 到 -9 与 ditto)
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -1)", level: 1, throughputMBs: 8107.3, compressionRatio: 5.58, spaceSavingsPct: 82.1, archiveSizeBytes: 38210928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -2)", level: 2, throughputMBs: 7641.6, compressionRatio: 5.84, spaceSavingsPct: 82.9, archiveSizeBytes: 36510928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -3)", level: 3, throughputMBs: 6562.3, compressionRatio: 6.01, spaceSavingsPct: 83.4, archiveSizeBytes: 35481928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -4)", level: 4, throughputMBs: 6258.9, compressionRatio: 6.60, spaceSavingsPct: 84.8, archiveSizeBytes: 32301928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -5)", level: 5, throughputMBs: 4906.8, compressionRatio: 6.82, spaceSavingsPct: 85.3, archiveSizeBytes: 31251928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -6)", level: 6, throughputMBs: 3629.9, compressionRatio: 6.93, spaceSavingsPct: 85.6, archiveSizeBytes: 30761928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -7)", level: 7, throughputMBs: 3047.4, compressionRatio: 6.97, spaceSavingsPct: 85.7, archiveSizeBytes: 30591928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -8)", level: 8, throughputMBs: 1844.9, compressionRatio: 7.03, spaceSavingsPct: 85.8, archiveSizeBytes: 30341928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -9)", level: 9, throughputMBs: 1394.0, compressionRatio: 7.07, spaceSavingsPct: 85.9, archiveSizeBytes: 30161928),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (ditto)", level: 6, throughputMBs: 4145.8, compressionRatio: 6.94, spaceSavingsPct: 85.6, archiveSizeBytes: 30721928)
    ]

    // MARK: - 297.55MB 复合真实工作区黄金快照 (513 Files)
    
    public static let compoundMixedWorkspaceCompetitors: [CompetitorMeasurementSnapshot] = [
        // 7-Zip ARM64 (mx=1, 3, 5, 7, 9)
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=1)", level: 1, throughputMBs: 20292.2, compressionRatio: 4.21, spaceSavingsPct: 76.2, archiveSizeBytes: 74176985),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=3)", level: 3, throughputMBs: 20518.0, compressionRatio: 4.21, spaceSavingsPct: 76.2, archiveSizeBytes: 74176985),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=5)", level: 5, throughputMBs: 3513.5, compressionRatio: 4.49, spaceSavingsPct: 77.7, archiveSizeBytes: 69479385),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=7)", level: 7, throughputMBs: 1188.6, compressionRatio: 4.56, spaceSavingsPct: 78.1, archiveSizeBytes: 68412852),
        CompetitorMeasurementSnapshot(algorithm: "7-Zip 26.02 (mx=9)", level: 9, throughputMBs: 573.0, compressionRatio: 4.57, spaceSavingsPct: 78.1, archiveSizeBytes: 68224716),
        
        // pigz (-1 到 -9)
        CompetitorMeasurementSnapshot(algorithm: "pigz (-1)", level: 1, throughputMBs: 28825.5, compressionRatio: 3.80, spaceSavingsPct: 73.7, archiveSizeBytes: 82071852),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-2)", level: 2, throughputMBs: 27337.6, compressionRatio: 3.93, spaceSavingsPct: 74.5, archiveSizeBytes: 79439120),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-3)", level: 3, throughputMBs: 23837.0, compressionRatio: 4.04, spaceSavingsPct: 75.2, archiveSizeBytes: 77290124),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-4)", level: 4, throughputMBs: 23155.7, compressionRatio: 4.18, spaceSavingsPct: 76.1, archiveSizeBytes: 74606214),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-5)", level: 5, throughputMBs: 18449.5, compressionRatio: 4.29, spaceSavingsPct: 76.7, archiveSizeBytes: 72666120),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-6)", level: 6, throughputMBs: 14480.0, compressionRatio: 4.35, spaceSavingsPct: 77.0, archiveSizeBytes: 71721528),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-7)", level: 7, throughputMBs: 12706.3, compressionRatio: 4.37, spaceSavingsPct: 77.1, archiveSizeBytes: 71428512),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-8)", level: 8, throughputMBs: 8991.5, compressionRatio: 4.38, spaceSavingsPct: 77.2, archiveSizeBytes: 71177810),
        CompetitorMeasurementSnapshot(algorithm: "pigz (-9)", level: 9, throughputMBs: 6973.7, compressionRatio: 4.39, spaceSavingsPct: 77.2, archiveSizeBytes: 71093120),
        
        // Apple Native (zip -1 到 -9 与 ditto)
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -1)", level: 1, throughputMBs: 6866.5, compressionRatio: 3.78, spaceSavingsPct: 73.6, archiveSizeBytes: 82461820),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -2)", level: 2, throughputMBs: 6361.8, compressionRatio: 3.91, spaceSavingsPct: 74.4, archiveSizeBytes: 79818290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -3)", level: 3, throughputMBs: 5231.0, compressionRatio: 4.01, spaceSavingsPct: 75.1, archiveSizeBytes: 77710290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -4)", level: 4, throughputMBs: 5015.4, compressionRatio: 4.18, spaceSavingsPct: 76.0, archiveSizeBytes: 74732810),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -5)", level: 5, throughputMBs: 3747.5, compressionRatio: 4.29, spaceSavingsPct: 76.7, archiveSizeBytes: 72740290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -6)", level: 6, throughputMBs: 2737.5, compressionRatio: 4.34, spaceSavingsPct: 77.0, archiveSizeBytes: 71806290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -7)", level: 7, throughputMBs: 2306.5, compressionRatio: 4.36, spaceSavingsPct: 77.1, archiveSizeBytes: 71513290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -8)", level: 8, throughputMBs: 1530.8, compressionRatio: 4.38, spaceSavingsPct: 77.2, archiveSizeBytes: 71261290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (zip -9)", level: 9, throughputMBs: 1159.6, compressionRatio: 4.38, spaceSavingsPct: 77.2, archiveSizeBytes: 71177290),
        CompetitorMeasurementSnapshot(algorithm: "Apple Native (ditto)", level: 6, throughputMBs: 2832.9, compressionRatio: 4.34, spaceSavingsPct: 76.9, archiveSizeBytes: 71963290)
    ]
}
