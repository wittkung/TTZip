// Sources/TTZipCore/SevenZip/SevenZipLZMA2HybridStrategy.swift
// TTZip 7Z/XZ LZMA2 混合双引擎路由策略 (Hybrid Dual-Engine Strategy)

import Foundation
import CTTZipBridge

/// LZMA2 编码路由模式
public enum LZMA2RouteMode: String, Sendable, Codable {
    /// Level 1 极速模式：直通自研 ARM64 NEON 向量化匹配查找器与无分支 Range Coder
    case neonFastPath
    /// Level 3~9 高压缩等级：直通 Fast-LZMA2 并行 Radix 匹配查找器与多线程流水线
    case fastLZMA2Parallel
    /// 稀疏零块快速封装旁路
    case zeroBlockBypass
}

/// 7Z / LZMA2 混合压缩策略配置实体
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

    /// 根据压缩等级与零块提示自动判定最优路由策略
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

        // Level 3 ~ 9
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
