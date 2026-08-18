// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 5-Tier 科学多模态压缩评测场景分类
public enum BenchmarkTierCategory: String, Codable, Sendable, CaseIterable {
    /// Tier 1: 大文本与 Web 标记 (enwik8, webster, dickens, reymont) - 考验大窗口匹配与 Huffman
    case tier1Text = "Tier 1: Large Text & Web"
    
    /// Tier 2: 机器码与二进制 (mozilla, ooffice) - 考验指令相对跳转与离散短匹配
    case tier2Binary = "Tier 2: Binary Executable"
    
    /// Tier 3: 结构化与数据库 (nci, osdb, xml) - 考验固定 Schema 与高频标签极速去重
    case tier3Structured = "Tier 3: Structured Data & DB"
    
    /// Tier 4: 混合工程源码树与微文件集合 (samba, 500-files VFS tree) - 考验并发目录扫描与小文件调度
    case tier4SourceTree = "Tier 4: Mixed SourceTree & VFS"
    
    /// Tier 5: 科学计算与医学密集矩阵 (mr, x-ray, sao) - 考验 SIMD 字节重排与差分滤波
    case tier5DenseMatrix = "Tier 5: Dense Matrix & Sensors"
    
    /// 标准学术与工业界加权权重
    public var defaultWeight: Double {
        switch self {
        case .tier1Text: return 0.25
        case .tier2Binary: return 0.20
        case .tier3Structured: return 0.20
        case .tier4SourceTree: return 0.20
        case .tier5DenseMatrix: return 0.15
        }
    }
    
    /// 场景简要说明
    public var description: String {
        switch self {
        case .tier1Text:
            return "Natural Language, Dictionaries & Web markup testing 32MB+ sliding window match finders."
        case .tier2Binary:
            return "x86/ARM64 machine code executables testing BCJ branch filtering and short patterns."
        case .tier3Structured:
            return "Relational DB pages, XML trees and structured chemical ASCII schemas."
        case .tier4SourceTree:
            return "Multi-level directory trees with hundreds of small files testing VFS traversal and concurrency."
        case .tier5DenseMatrix:
            return "16/32-bit DICOM MRI, X-ray and astronomical float matrices testing Byte-Shuffle and Delta filters."
        }
    }
}
