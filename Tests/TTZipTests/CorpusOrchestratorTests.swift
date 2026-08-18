// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CorpusOrchestratorTests: XCTestCase {
    
    // MARK: - 1. 5-Tier 自动发现测试
    
    func testFiveTierCorpusDiscovery() {
        let orchestrator = CorpusOrchestrator.shared
        let allTiers = BenchmarkTierCategory.allCases
        
        XCTAssertEqual(allTiers.count, 5, "必须严格包含 5 大评测分级")
        
        for tier in allTiers {
            let items = orchestrator.items(for: tier)
            XCTAssertFalse(items.isEmpty, "Tier \(tier.rawValue) 必须能够发现至少 1 项真实语料")
            
            for item in items {
                XCTAssertTrue(FileManager.default.fileExists(atPath: item.path), "语料物理文件必须真实存在: \(item.path)")
                XCTAssertGreaterThan(item.sizeBytes, 0, "语料文件大小必须大于 0 字节")
            }
        }
    }
    
    // MARK: - 2. POSIX mmap 零拷贝映射与生命周期测试
    
    func testZeroCopyMmapBufferAccess() throws {
        let orchestrator = CorpusOrchestrator.shared
        let textItems = orchestrator.items(for: .tier1Text)
        guard let first = textItems.first else {
            XCTFail("未发现 Tier 1 语料")
            return
        }
        
        var bytesRead = 0
        try orchestrator.withMappedBuffer(for: first) { buffer in
            XCTAssertGreaterThan(buffer.count, 0)
            XCTAssertEqual(Int64(buffer.count), first.sizeBytes)
            bytesRead = buffer.count
            
            // 验证首尾字节可读
            let firstByte = buffer[0]
            let lastByte = buffer[buffer.count - 1]
            _ = firstByte
            _ = lastByte
        }
        
        XCTAssertEqual(Int64(bytesRead), first.sizeBytes)
    }
    
    // MARK: - 3. 加权几何平均数与 SPECScore 数学公理验证
    
    func testGeometricMeanMathAxioms() {
        let measurements: [TierBenchmarkMeasurement] = [
            TierBenchmarkMeasurement(tier: .tier1Text, payloadBytes: 100_000_000, compressedBytes: 3_500_000, compressionSpeedMBs: 1400.0, decompressionSpeedMBs: 8000.0, compressionRatio: 28.57, spaceSavingsPct: 96.5),
            TierBenchmarkMeasurement(tier: .tier2Binary, payloadBytes: 50_000_000, compressedBytes: 20_000_000, compressionSpeedMBs: 1200.0, decompressionSpeedMBs: 7500.0, compressionRatio: 2.50, spaceSavingsPct: 60.0),
            TierBenchmarkMeasurement(tier: .tier3Structured, payloadBytes: 30_000_000, compressedBytes: 10_000_000, compressionSpeedMBs: 1500.0, decompressionSpeedMBs: 8500.0, compressionRatio: 3.00, spaceSavingsPct: 66.7),
            TierBenchmarkMeasurement(tier: .tier4SourceTree, payloadBytes: 20_000_000, compressedBytes: 6_000_000, compressionSpeedMBs: 900.0, decompressionSpeedMBs: 6000.0, compressionRatio: 3.33, spaceSavingsPct: 70.0),
            TierBenchmarkMeasurement(tier: .tier5DenseMatrix, payloadBytes: 10_000_000, compressedBytes: 5_000_000, compressionSpeedMBs: 1800.0, decompressionSpeedMBs: 9000.0, compressionRatio: 2.00, spaceSavingsPct: 50.0)
        ]
        
        let score = CompositeEfficiencyCalculator.computeScore(
            algorithm: "TTZip-ZIP-L1",
            level: 1,
            measurements: measurements,
            profile: .balanced
        )
        
        // 验证几何平均值在合理区间内
        XCTAssertGreaterThan(score.geomCompSpeedMBs, 900.0)
        XCTAssertLessThan(score.geomCompSpeedMBs, 1800.0)
        XCTAssertGreaterThan(score.geomDecompSpeedMBs, 6000.0)
        XCTAssertLessThan(score.geomDecompSpeedMBs, 9000.0)
        XCTAssertGreaterThan(score.geomCompressionRatio, 2.0)
        XCTAssertGreaterThan(score.compositeEfficiencyIndex, 0.0)
        XCTAssertGreaterThan(score.normalizedSpecScore, 0.0)
        
        // 验证帕累托前沿计算
        let scores = CompositeEfficiencyCalculator.computeParetoFrontier(scores: [score])
        XCTAssertEqual(scores.count, 1)
        XCTAssertTrue(scores[0].isParetoOptimal)
    }
}
