// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// ZIP 格式强类型透明物理压缩配置模型 (ZipCompressionProfile)
///
/// 遵循单一真理之源（Single Source of Truth）与策略模式（Strategy Pattern）：
/// 1. 彻底消除通用枚举层与底层 C 引擎之间的黑盒隐式 switch 转换；
/// 2. 每一个档位的物理参数（libdeflate 等级、Zopfli 轮次、动态块切分）100% 显式声明；
/// 3. 与底层 C 语言 `TTZipZopfliOptions` 保持 1:1 零成本结构体直通。
public struct ZipCompressionProfile: Sendable, Equatable, Identifiable {
    
    /// 档位唯一标识符 (例如 "zip_tier_1_fast")
    public let id: String
    
    /// 用户 / UI / CLI 展示名称 (例如 "Fast (1)")
    public let name: String
    
    /// 上层通用抽象压缩等级枚举 (.store, .level1 ... .level7)
    public let level: ArchiveCompressionLevel
    
    /// libdeflate C 原生底层压缩等级 (0..12)
    public let deflateLevel: Int32
    
    /// 图论 / Zopfli 迭代重平衡轮次 (0..15)
    public let zopfliIterations: Int32
    
    /// 是否启用局部香农熵动态最优块切分 (true/false)
    public let blockSplitting: Bool
    
    /// 最大切分块数量 (0..15)
    public let maxBlockSplits: Int32
    
    /// 自适应早退收敛阈值 (0.0001 即 0.01%)
    public let earlyExitThreshold: Double
    
    /// Release 模式下 Apple Silicon 18 核心物理性能门禁底线 (MB/s)
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

// MARK: - 8 大黄金标准档位预设 (The 8 Golden Presets)

extension ZipCompressionProfile {
    
    /// Tier 0: Direct Store (零压缩大页内存直写，吞吐 >= 6000 MB/s)
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
    
    /// Tier 1: Fast (极速轻量 LZ77 短匹配，libdeflate L2，吞吐 >= 4500 MB/s)
    public static let fast = ZipCompressionProfile(
        id: "zip_tier_1_fast",
        name: "Fast (1)",
        level: .level1,
        deflateLevel: 2,
        zopfliIterations: 1,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 4500.0
    )
    
    /// Tier 2: Fast+ (快速匹配增加哈希链深度，libdeflate L4，吞吐 >= 3800 MB/s)
    public static let fastPlus = ZipCompressionProfile(
        id: "zip_tier_2_fast_plus",
        name: "Fast+ (2)",
        level: .level2,
        deflateLevel: 4,
        zopfliIterations: 1,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 3800.0
    )
    
    /// Tier 3: Normal (标准帕累托平衡档位，libdeflate L6，吞吐 >= 3000 MB/s)
    public static let normal = ZipCompressionProfile(
        id: "zip_tier_3_normal",
        name: "Normal (3)",
        level: .level3,
        deflateLevel: 6,
        zopfliIterations: 1,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 3000.0
    )
    
    /// Tier 4: Maximum (深度字典模式匹配，libdeflate L8，吞吐 >= 1800 MB/s)
    public static let maximum = ZipCompressionProfile(
        id: "zip_tier_4_maximum",
        name: "Maximum (4)",
        level: .level4,
        deflateLevel: 8,
        zopfliIterations: 1,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 1800.0
    )
    
    /// Tier 5: Graph Fast (有限前瞻 DAG 最短路径图论剪枝，libdeflate L10，吞吐 >= 600 MB/s)
    public static let graphFast = ZipCompressionProfile(
        id: "zip_tier_5_graph_fast",
        name: "Graph Fast (5)",
        level: .level5,
        deflateLevel: 10,
        zopfliIterations: 4,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 600.0
    )
    
    /// Tier 6: Ultra Zopfli (100% 进程内全局 DAG 最短路径穷举，libdeflate L12 / 10 轮 Zopfli，吞吐 >= 2.5 MB/s)
    public static let ultraZopfli = ZipCompressionProfile(
        id: "zip_tier_6_ultra_zopfli",
        name: "Ultra Zopfli (6)",
        level: .level6,
        deflateLevel: 12,
        zopfliIterations: 10,
        blockSplitting: false,
        maxBlockSplits: 0,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 2.5
    )
    
    /// Tier 7: Extreme Peak (15 轮迭代重平衡与局部熵变最优块切分，超越 advzip -4，吞吐 >= 0.25 MB/s)
    public static let extremePeak = ZipCompressionProfile(
        id: "zip_tier_7_extreme_peak",
        name: "Extreme Peak (7)",
        level: .level7,
        deflateLevel: 12,
        zopfliIterations: 15,
        blockSplitting: true,
        maxBlockSplits: 15,
        earlyExitThreshold: 0.0001,
        targetThroughputFloorMBs: 0.25
    )
    
    /// 8 大黄金标准预设全集
    public static let allProfiles: [ZipCompressionProfile] = [
        .store,
        .fast,
        .fastPlus,
        .normal,
        .maximum,
        .graphFast,
        .ultraZopfli,
        .extremePeak
    ]
    
    /// 根据通用抽象压缩等级透明解析对应的强类型 Profile
    public static func profile(for level: ArchiveCompressionLevel) -> ZipCompressionProfile {
        switch level {
        case .store:
            return .store
        case .fast5, .fast4, .fast3, .fast2, .fast1, .level1:
            return .fast
        case .level2:
            return .fastPlus
        case .level3:
            return .normal
        case .level4:
            return .maximum
        case .level5:
            return .graphFast
        case .level6:
            return .ultraZopfli
        case .level7, .level8, .level9, .level10, .level11, .level12, .level13, .level14, .level15, .level16, .level17, .level18, .level19, .level20, .level21, .level22:
            return .extremePeak
        }
    }
}
