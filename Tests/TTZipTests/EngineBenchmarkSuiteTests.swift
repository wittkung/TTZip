// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// TTZip BenchmarkEngine ，
final class EngineBenchmarkSuiteTests: XCTestCase {
    
    func testBenchmarkEngineWithCompetitors() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("全量引擎压测与竞品物理测算需设置 TTZIP_RUN_BENCHMARKS=1 触发，常规 swift test 自动跳过以杜绝卡主")
        }
        
        try await withTimeout(seconds: 180.0, description: "BenchmarkEngineWithCompetitors") {
            TTLogger.info("\n================================================================================")
            TTLogger.info("     🚀 [BenchmarkEngine Direct Invocation] 核心压测引擎竞品全参数物理测算")
            TTLogger.info("================================================================================")
            
            let engine = BenchmarkEngine()
            
            // ( , , , , )
            let parameterSets: [(size: BenchmarkDataSize, profile: BenchmarkDatasetProfile, format: ArchiveCompressionFormat, level: ArchiveCompressionLevel, name: String)] = [
                (.small, .codeText, .zip, .level1, "⚡ 100MB ZIP 极速模式 (Level 1 Fast)"),
                (.small, .mixedOffice, .zip, .level6, "⚖️ 100MB ZIP 标准平衡 (Level 6 Normal)"),
                (.small, .mediaBinary, .zip, .store, "💾 100MB ZIP 存储直通 (Level 0 Store)"),
                (.small, .codeText, .sevenZip, .level6, "📦 100MB 7-Zip LZMA2 标准 (Level 6 Normal)"),
                (.small, .codeText, .tarZst, .level1, "🚀 100MB TAR.ZST Zstandard 极速 (Level 1 Fast)")
            ]
            
            for (idx, p) in parameterSets.enumerated() {
                TTLogger.info("\n--------------------------------------------------------------------------------")
                TTLogger.info("🔥 [场景 \(idx + 1)/\(parameterSets.count)] \(p.name)")
                TTLogger.info("--------------------------------------------------------------------------------")
                
                let result = try await engine.runBenchmark(
                    size: p.size,
                    profile: p.profile,
                    format: p.format,
                    level: p.level,
                    recommendation: p.name,
                    progressHandler: { prog in
                        if prog.bytesProcessed % (20 * 1024 * 1024) == 0 || prog.progressPercent >= 1.0 {
                            TTLogger.info("  [Progress] \(String(format: "%.1f%%", prog.progressPercent * 100)) (\(prog.bytesProcessed / (1024*1024))MB / \(prog.totalBytes / (1024*1024))MB)")
                        }
                    }
                )
                
                XCTAssertGreaterThan(result.throughputMBs, 0, "TTZip 压缩速率不应为 0")
                XCTAssertGreaterThan(result.decompressionThroughputMBs, 0, "TTZip 解压速率不应为 0")
            }
        }
    }
}
