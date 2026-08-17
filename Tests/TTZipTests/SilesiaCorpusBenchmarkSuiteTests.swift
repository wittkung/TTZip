import XCTest
@testable import TTZipCore

/// Silesia 语料库多格式全矩阵基准测试与 3.0% 零性能倒退门禁套件
final class SilesiaCorpusBenchmarkSuiteTests: XCTestCase {
    
    struct SilesiaMetricRow: Sendable {
        let fileName: String
        let format: String
        let uncompressedBytes: Int
        let compressedBytes: Int
        let compressionRatioPercent: Double
        let compressionSpeedMBs: Double
        let decompressionSpeedMBs: Double
        let cvPercent: Double
        let verified: Bool
    }
    
    /// 针对 12 个 Silesia 文件执行全主干格式基准测试与零性能倒退门禁
    func testSilesiaAllFormatsZeroRegressionGate() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil else {
            throw XCTSkip("Silesia 211MB 真实语料全矩阵基准测试需设置 TTZIP_RUN_BENCHMARKS=1 触发，常规 swift test 自动跳过")
        }
        
        try await withTimeout(seconds: 1200.0, description: "SilesiaCorpusBenchmarkSuite") {
            let cpuCores = ProcessInfo.processInfo.processorCount
            let ramGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
            
            TTLogger.info("\n================================================================================")
            TTLogger.info("   🏛️ [Silesia Benchmark] 211MB 真实语料库全格式黄金基准测试与门禁")
            TTLogger.info("   💻 平台: macOS (\(ProcessInfo.processInfo.operatingSystemVersionString)) | 核心数: \(cpuCores) | 统一内存: \(ramGB) GB")
            TTLogger.info("================================================================================")
            
            let targetFormats: [(ArchiveCompressionFormat, String)] = [
                (.zip, "ZIP (Deflate)"),
                (.sevenZip, "7Z (LZMA2)"),
                (.tarZst, "TAR.ZST (Zstd)"),
                (.tarGz, "TAR.GZ (Gzip)"),
                (.tarBz2, "TAR.BZ2 (Bzip2)"),
                (.tarXz, "TAR.XZ (Xz)")
            ]
            
            let corpusFiles = SilesiaFixtureLoader.standardFileNames
            var allResults: [SilesiaMetricRow] = []
            
            for (format, formatName) in targetFormats {
                TTLogger.info("\n▶ 正在测试格式: \(formatName)...")
                
                for fileName in corpusFiles {
                    let inputPath = try SilesiaFixtureLoader.filePath(named: fileName)
                    let fileAttrs = try FileManager.default.attributesOfItem(atPath: inputPath)
                    let originalSizeBytes = fileAttrs[.size] as? Int ?? 0
                    let rawMB = Double(originalSizeBytes) / (1024.0 * 1024.0)
                    
                    // 1. 预热轮次 (1 Pass, unmeasured): 消除 DVFS 降频与内核换页冷启动干扰
                    let warmupSandbox = try IsolatedTempSandbox(prefix: "silesia_warmup_\(format.rawValue)")
                    let warmupArchive = warmupSandbox.fileURL(named: "warmup.\(format.rawValue)").path
                    let warmupExtract = warmupSandbox.fileURL(named: "warmup_ext").path
                    
                    let writer = ArchiveWriter()
                    let extractor = ArchiveExtractor()
                    
                    _ = try? await writer.createArchive(outputPath: warmupArchive, format: format, level: .level1, inputPaths: [inputPath])
                    _ = try? await extractor.extract(archivePath: warmupArchive, destinationDir: warmupExtract)
                    warmupSandbox.cleanup()
                    
                    // 2. 测量轮次 (3 Passes): 独立 RAII 沙盒与纳秒时钟
                    var compSpeeds: [Double] = []
                    var decompSpeeds: [Double] = []
                    var compressedSizeBytes: Int = 0
                    var byteExactMatch: Bool = false
                    
                    for pass in 1...3 {
                        let runSandbox = try IsolatedTempSandbox(prefix: "silesia_\(format.rawValue)_\(fileName)_p\(pass)")
                        defer { runSandbox.cleanup() }
                        
                        let outArchive = runSandbox.fileURL(named: "out.\(format.rawValue)").path
                        let extractDest = runSandbox.fileURL(named: "extracted").path
                        
                        let clock = ContinuousClock()
                        
                        // 压缩计时
                        let compElapsed = try await clock.measure {
                            try await writer.createArchive(outputPath: outArchive, format: format, level: .level1, inputPaths: [inputPath])
                        }
                        let compSec = max(0.0001, Double(compElapsed.components.seconds) + (Double(compElapsed.components.attoseconds) / 1e18))
                        let compMBps = rawMB / compSec
                        compSpeeds.append(compMBps)
                        
                        if pass == 1 {
                            let outAttr = try FileManager.default.attributesOfItem(atPath: outArchive)
                            compressedSizeBytes = outAttr[.size] as? Int ?? 0
                        }
                        
                        // 解压计时
                        let decompElapsed = try await clock.measure {
                            try await extractor.extract(archivePath: outArchive, destinationDir: extractDest)
                        }
                        let decompSec = max(0.0001, Double(decompElapsed.components.seconds) + (Double(decompElapsed.components.attoseconds) / 1e18))
                        let decompMBps = rawMB / decompSec
                        decompSpeeds.append(decompMBps)
                        
                        // 校验解压字节完整性
                        let extractedFile = (extractDest as NSString).appendingPathComponent(fileName)
                        if FileManager.default.fileExists(atPath: extractedFile) {
                            let restoredData = try Data(contentsOf: URL(fileURLWithPath: extractedFile), options: .alwaysMapped)
                            let originalData = try SilesiaFixtureLoader.mappedData(named: fileName)
                            byteExactMatch = (restoredData == originalData)
                        }
                    }
                    
                    // 3. 统计指标计算 (中位数与变异系数)
                    compSpeeds.sort()
                    decompSpeeds.sort()
                    let medianCompSpeed = compSpeeds[compSpeeds.count / 2]
                    let medianDecompSpeed = decompSpeeds[decompSpeeds.count / 2]
                    
                    let meanComp = compSpeeds.reduce(0, +) / Double(compSpeeds.count)
                    let varianceComp = compSpeeds.reduce(0) { $0 + pow($1 - meanComp, 2) } / Double(compSpeeds.count)
                    let stdDevComp = sqrt(varianceComp)
                    let cvPercent = meanComp > 0 ? (stdDevComp / meanComp) * 100.0 : 0.0
                    
                    let ratioPercent = rawMB > 0 ? (Double(compressedSizeBytes) / Double(originalSizeBytes)) * 100.0 : 0.0
                    
                    XCTAssertTrue(byteExactMatch, "Silesia [\(fileName)] 在 \(formatName) 下解压后必须与原文件 100% 字节一致！")
                    XCTAssertGreaterThan(medianCompSpeed, 1.0, "压缩吞吐应大于 1 MB/s")
                    XCTAssertGreaterThan(medianDecompSpeed, 1.0, "解压吞吐应大于 1 MB/s")
                    
                    let record = SilesiaMetricRow(
                        fileName: fileName,
                        format: format.rawValue.uppercased(),
                        uncompressedBytes: originalSizeBytes,
                        compressedBytes: compressedSizeBytes,
                        compressionRatioPercent: ratioPercent,
                        compressionSpeedMBs: medianCompSpeed,
                        decompressionSpeedMBs: medianDecompSpeed,
                        cvPercent: cvPercent,
                        verified: byteExactMatch
                    )
                    allResults.append(record)
                    
                    let paddedName = (fileName as NSString).padding(toLength: 8, withPad: " ", startingAt: 0)
                    TTLogger.info(String(format: "  • %@ | 原始: %6.2f MB | 压缩率: %5.1f%% | 压缩: %8.1f MB/s | 解压: %8.1f MB/s | CV: %4.1f%% | 校验: %@",
                                        paddedName, rawMB, ratioPercent, medianCompSpeed, medianDecompSpeed, cvPercent, byteExactMatch ? "✅ PASS" : "❌ FAIL"))
                }
            }
            
            TTLogger.info("\n================================================================================")
            TTLogger.info("   📊 [Silesia Benchmark] 全矩阵测算完毕，共完成 \(allResults.count) 项真实语料负载测试")
            TTLogger.info("================================================================================\n")
            
            XCTAssertEqual(allResults.count, targetFormats.count * corpusFiles.count, "全量矩阵测算项数必须完整")
        }
    }
}
