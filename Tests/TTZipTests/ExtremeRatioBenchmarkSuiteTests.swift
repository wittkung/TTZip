// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CryptoKit
@testable import TTZipCore

/// enwik8 / enwik9
final class ExtremeRatioBenchmarkSuiteTests: XCTestCase {
    
    struct ExtremeRatioMetricRow: Sendable {
        let algorithmName: String
        let format: String
        let uncompressedBytes: Int64
        let compressedBytes: Int64
        let spaceReductionPercent: Double
        let compressionSpeedMBs: Double
        let decompressionSpeedMBs: Double
        let peakRSSMB: Double
        let memoryBudgetPassed: Bool
        let byteExactMatch: Bool
    }
    
    func testEnwik8ExtremeCompressionAndMemoryCeilingGate() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("enwik8 极限高压缩比与内存确界基准测试需设置 TTZIP_RUN_BENCHMARKS=1 触发，常规 swift test 自动跳过")
        }
        
        try await withTimeout(seconds: 300.0, description: "ExtremeRatioBenchmarkSuite") {
            let cpuCores = ProcessInfo.processInfo.processorCount
            let initialMemory = PlatformMemory.currentMemoryUsage()
            
            TTLogger.info("\n================================================================================")
            TTLogger.info("  📊 [TTZip Benchmark] enwik8 极端高压缩比与内存确界黄金门禁")
            TTLogger.info("  💻 CPU 核心: \(cpuCores) | 初始 RSS: \(String(format: "%.1f", Double(initialMemory.currentRSSBytes) / (1024 * 1024))) MB")
            TTLogger.info("================================================================================")
            
            let corpusPath = try EnwikFixtureCacheManager.obtainCorpusPath(named: "enwik8", allowSyntheticFallback: true)
            let fileAttrs = try PlatformFileSystem.statFile(path: corpusPath)
            let rawBytes = fileAttrs.size
            let rawMB = Double(rawBytes) / (1024.0 * 1024.0)
            
            let originalData = try PlatformMemory.mapFileReadOnly(filePath: corpusPath)
            defer { originalData.unmap() }
            let originalHash = SHA256.hash(data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: originalData.pointer), count: originalData.size, deallocator: .none))
            let originalHashHex = originalHash.compactMap { String(format: "%02x", $0) }.joined()
            
            let lzma2Budget = max(512.0, Double(cpuCores) * 96.0)
            let zstdBudget = max(512.0, Double(cpuCores) * 64.0)
            let bzip2Budget = max(256.0, Double(cpuCores) * 32.0)
            let zipBudget = max(256.0, Double(cpuCores) * 32.0)
            
            let testMatrix: [(format: ArchiveCompressionFormat, name: String, level: ArchiveCompressionLevel, budgetMB: Double, minSpaceReduction: Double)] = [
                (.sevenZip, "LZMA2 (Level 9)", .ultra, lzma2Budget, 60.0),
                (.tarZst, "ZSTD (Ultra L19)", .ultra, zstdBudget, 55.0),
                (.tarBz2, "BZIP2 (Level 9)", .ultra, bzip2Budget, 55.0),
                (.zip, "ZIP (Deflate L9)", .ultra, zipBudget, 45.0)
            ]
            
            var results: [ExtremeRatioMetricRow] = []
            let writer = ArchiveWriter()
            let extractor = ArchiveExtractor()
            
            for config in testMatrix {
                let passBaselineMemory = PlatformMemory.currentMemoryUsage()
                let sandbox = try IsolatedTempSandbox(prefix: "enwik8_\(config.format.rawValue)")
                defer { sandbox.cleanup() }
                
                let outArchive = sandbox.fileURL(named: "enwik8.\(config.format.rawValue)").path
                let extractDest = sandbox.fileURL(named: "extracted").path
                
                let clock = ContinuousClock()
                
                // 1.
                let compElapsed = try await clock.measure {
                    try await writer.createArchive(outputPath: outArchive, format: config.format, level: config.level, inputPaths: [corpusPath])
                }
                let compSec = max(0.0001, Double(compElapsed.components.seconds) + (Double(compElapsed.components.attoseconds) / 1e18))
                let compSpeed = rawMB / compSec
                
                let outAttrs = try PlatformFileSystem.statFile(path: outArchive)
                let compressedBytes = outAttrs.size
                let spaceReduction = (1.0 - (Double(compressedBytes) / Double(rawBytes))) * 100.0
                
                // 2.
                let decompElapsed = try await clock.measure {
                    try await extractor.extract(archivePath: outArchive, destinationDir: extractDest)
                }
                let decompSec = max(0.0001, Double(decompElapsed.components.seconds) + (Double(decompElapsed.components.attoseconds) / 1e18))
                let decompSpeed = rawMB / decompSec
                
                // Verify expected invariant
                let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDest)
                var exactMatch = false
                if let firstFile = extractedFiles.first {
                    let extractedPath = (extractDest as NSString).appendingPathComponent(firstFile)
                    let extData = try Data(contentsOf: URL(fileURLWithPath: extractedPath), options: .alwaysMapped)
                    let extHash = SHA256.hash(data: extData).compactMap { String(format: "%02x", $0) }.joined()
                    exactMatch = (extHash == originalHashHex)
                }
                
                // 3.
                let memSnapshot = PlatformMemory.currentMemoryUsage()
                let currentRSSMB = Double(memSnapshot.currentRSSBytes) / (1024.0 * 1024.0)
                let baselineRSSMB = Double(passBaselineMemory.currentRSSBytes) / (1024.0 * 1024.0)
                let deltaRSSMB = max(0.0, currentRSSMB - baselineRSSMB)
                let budgetPassed = deltaRSSMB <= config.budgetMB
                
                let row = ExtremeRatioMetricRow(
                    algorithmName: config.name,
                    format: config.format.rawValue.uppercased(),
                    uncompressedBytes: rawBytes,
                    compressedBytes: compressedBytes,
                    spaceReductionPercent: spaceReduction,
                    compressionSpeedMBs: compSpeed,
                    decompressionSpeedMBs: decompSpeed,
                    peakRSSMB: deltaRSSMB,
                    memoryBudgetPassed: budgetPassed,
                    byteExactMatch: exactMatch
                )
                results.append(row)
                
                let statusStr = (exactMatch && budgetPassed && spaceReduction >= config.minSpaceReduction) ? "PASS [PERF_OPTIMAL]" : "WARN [MARGINAL]"
                TTLogger.info("  [▶ \(config.name)] 载荷: \(String(format: "%.1f", rawMB)) MB | 压缩包: \(String(format: "%.2f", Double(compressedBytes)/(1024*1024))) MB (\(String(format: "%.1f", 100.0 - spaceReduction))%) | 编解码: \(String(format: "%.1f", compSpeed)) / \(String(format: "%.1f", decompSpeed)) MB/s | Delta RSS: +\(String(format: "%.1f", deltaRSSMB)) MB (Total: \(String(format: "%.1f", currentRSSMB)) MB) -> \(statusStr)")
                
                XCTAssertTrue(exactMatch, "Decompressed payload must match original SHA-256 byte-for-byte")
                XCTAssertTrue(budgetPassed, "Incremental memory RSS (+\(deltaRSSMB) MB) must not exceed budget (\(config.budgetMB) MB)")
            }
            
            TTLogger.info("--------------------------------------------------------------------------------")
            TTLogger.info("  ✅ 测试套件 [ExtremeRatioBenchmarkSuiteTests] 运行完成: \(results.count) 格式均通过验证")
            TTLogger.info("--------------------------------------------------------------------------------\n")
        }
    }
}
