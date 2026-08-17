import XCTest
@testable import TTZipCore

final class ExhaustiveCompressionCombinationsTests: XCTestCase {
    
    var tempDirPath: String!
    var sampleFiles: [String] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipComboTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
        
        let txtFile = (tempDirPath as NSString).appendingPathComponent("sample_text.txt")
        let jsonFile = (tempDirPath as NSString).appendingPathComponent("sample_data.json")
        let binFile = (tempDirPath as NSString).appendingPathComponent("sample_payload.bin")
        
        let textContent = String(repeating: "TTZip high-performance archiving engine test stream.\n", count: 200)
        let jsonContent = String(repeating: "{\"id\": 1024, \"status\": \"ACTIVE\", \"meta\": \"AppleSiliconTuner\"},", count: 100)
        let binContent = Data(repeating: 0x7E, count: 128 * 1024) // 128KB
        
        try textContent.write(toFile: txtFile, atomically: true, encoding: .utf8)
        try jsonContent.write(toFile: jsonFile, atomically: true, encoding: .utf8)
        try binContent.write(to: URL(fileURLWithPath: binFile))
        
        sampleFiles = [txtFile, jsonFile, binFile]
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - 1. 调用 ExhaustiveBenchmarkRunner 物理压测全场景 (ZIP 格式 x 各级压缩 x 加密/未加密 x 零拷贝)
    func testExhaustiveZipBenchmarkRunnerScenarios() async throws {
        let zipLevels: [ArchiveCompressionLevel] = [.store, .level1, .level6, .level9]
        
        TTLogger.info("\n================================================================================")
        TTLogger.info("    📊 [TTZip Core Bench] 全场景 ZIP (不压缩/各等级 x 加密/未加密) 实时物理测算")
        TTLogger.info("================================================================================")
        TTLogger.info(" 数据集                    | 格式   | 压缩等级   | 加密   | 压缩吞吐速率   | 解压吞吐速率   | 耗时(编/解码)     | 压缩体积比 | 物理完整性")
        TTLogger.info("--------------------------------------------------------------------------------")
        
        let rows = try await ExhaustiveBenchmarkRunner.runExhaustiveMatrix(
            selectedFormats: [.zip],
            selectedLevels: zipLevels,
            progressHandler: { msg in
                if msg.hasPrefix("ROW:") {
                    TTLogger.info(" " + String(msg.dropFirst(4)))
                } else {
                    TTLogger.debug("  \(msg)")
                }
            }
        )
        TTLogger.info("================================================================================\n")
        
        XCTAssertGreaterThan(rows.count, 0, "物理压测结果不应为空")
        for r in rows {
            XCTAssertTrue(r.sha256Matched, "场景 [\(r.dimensionName) | L\(r.level.rawValue) | 加密:\(r.isEncrypted)] SHA256 无损校验必须 100% 匹配")
        }
    }
    
    // MARK: - 2. 7z 格式全算法组合测试
    func testSevenZipAllAlgorithmsAndOptions() async throws {
        let algorithms = ["LZMA2", "LZMA", "PPMd", "BZip2", "Deflate", "Copy"]
        let dictSizes = [16, 32, 64]
        
        for algo in algorithms {
            for dictMB in dictSizes {
                let archiveName = "test_7z_\(algo)_\(dictMB)MB.7z"
                let outputPath = (tempDirPath as NSString).appendingPathComponent(archiveName)
                
                let writer = ArchiveWriter()
                let advanced = ArchiveAdvancedOptions(
                    algorithm: algo,
                    dictionarySizeMB: dictMB,
                    cpuThreads: 4,
                    enableSolidArchive: (algo != "Copy"),
                    encryptFileNames: false
                )
                
                try await writer.createArchive(
                    outputPath: outputPath,
                    format: .sevenZip,
                    level: (algo == "Copy") ? .store : .normal,
                    inputPaths: sampleFiles,
                    advancedOptions: advanced
                )
                
                XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
            }
        }
    }
    
    // MARK: - 3. ZIP 格式全加密与算法组合
    func testZipAllEncryptionsAndAlgorithms() async throws {
        let zipAlgos = ["Deflate", "Deflate64", "BZip2", "Store"]
        let encMethods = ["AES-256", "ZipCrypto"]
        
        for algo in zipAlgos {
            for enc in encMethods {
                let archiveName = "test_zip_\(algo)_\(enc).zip"
                let outputPath = (tempDirPath as NSString).appendingPathComponent(archiveName)
                
                let writer = ArchiveWriter()
                let advanced = ArchiveAdvancedOptions(
                    algorithm: algo,
                    cpuThreads: 0,
                    zipEncryptionMethod: enc,
                    zipEncodingUTF8: true
                )
                
                try await writer.createArchive(
                    outputPath: outputPath,
                    format: .zip,
                    level: (algo == "Store") ? .store : .normal,
                    inputPaths: sampleFiles,
                    password: "ZipPassWD!#$",
                    advancedOptions: advanced
                )
                
                XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
            }
        }
    }
}
