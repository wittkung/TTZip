// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipBench

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
    
    // MARK: - 1. ExhaustiveBenchmarkRunner ZIP Matrix
    func testExhaustiveZipBenchmarkRunnerScenarios() async throws {
        let zipLevels: [ArchiveCompressionLevel] = TestBenchmarkTier.isBenchmarkMode
            ? [.store, .level1, .level6, .level9]
            : [.store, .level6]
        
        TTLogger.info("\n================================================================================")
        TTLogger.info("    📊 [TTZip Core Bench] Full ZIP scenarios (Store/Levels x Encrypted/Plain) empirical benchmark")
        TTLogger.info("================================================================================")
        TTLogger.info(" Dataset                    | Format | Compression Level   | Encrypted | Compression Throughput   | Decompression Throughput   | Elapsed Time (Enc/Dec)     | Compression Ratio | Physical Integrity")
        TTLogger.info("--------------------------------------------------------------------------------")
        
        let rows = try await ExhaustiveBenchmarkRunner.runExhaustiveMatrix(
            selectedFormats: [.zip],
            selectedLevels: zipLevels,
            isQuickTest: !TestBenchmarkTier.isBenchmarkMode,
            progressHandler: { msg in
                if msg.hasPrefix("ROW:") {
                    TTLogger.info(" " + String(msg.dropFirst(4)))
                } else {
                    TTLogger.debug("  \(msg)")
                }
            }
        )
        TTLogger.info("================================================================================\n")
        
        XCTAssertGreaterThan(rows.count, 0, "Physical benchmark results must not be empty")
        for r in rows {
            XCTAssertTrue(r.sha256Matched, "场景 [\(r.dimensionName) | L\(r.level.rawValue) | 加密:\(r.isEncrypted)] SHA256 lossless integrity verification must match 100%")
        }
    }
    
    // MARK: - 2. 7z
    func testSevenZipAllAlgorithmsAndOptions() async throws {
        let algorithms = ["LZMA2", "LZMA", "PPMd", "BZip2", "Deflate", "Copy"]
        let dictSizes = TestBenchmarkTier.isBenchmarkMode ? [16, 32, 64] : [16]
        let baseFiles = sampleFiles
        let baseTemp = tempDirPath!
        
        try await withThrowingTaskGroup(of: String.self) { group in
            for algo in algorithms {
                for dictMB in dictSizes {
                    group.addTask {
                        let archiveName = "test_7z_\(algo)_\(dictMB)MB.7z"
                        let outputPath = (baseTemp as NSString).appendingPathComponent(archiveName)
                        
                        let writer = ArchiveWriter()
                        let advanced = ArchiveAdvancedOptions(
                            algorithm: algo,
                            dictionarySizeMB: dictMB,
                            cpuThreads: 2,
                            enableSolidArchive: (algo != "Copy"),
                            encryptFileNames: false
                        )
                        
                        try await writer.createArchive(
                            outputPath: outputPath,
                            format: .sevenZip,
                            level: (algo == "Copy") ? .store : .normal,
                            inputPaths: baseFiles,
                            advancedOptions: advanced
                        )
                        return outputPath
                    }
                }
            }
            
            for try await path in group {
                XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            }
        }
    }
    
    // MARK: - 3. ZIP
    func testZipAllEncryptionsAndAlgorithms() async throws {
        let zipAlgos = ["Deflate", "Deflate64", "BZip2", "Store"]
        let encMethods = ["AES-256", "ZipCrypto"]
        let baseFiles = sampleFiles
        let baseTemp = tempDirPath!
        
        try await withThrowingTaskGroup(of: String.self) { group in
            for algo in zipAlgos {
                for enc in encMethods {
                    group.addTask {
                        let archiveName = "test_zip_\(algo)_\(enc).zip"
                        let outputPath = (baseTemp as NSString).appendingPathComponent(archiveName)
                        
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
                            inputPaths: baseFiles,
                            password: "ZipPassWD!#$",
                            advancedOptions: advanced
                        )
                        return outputPath
                    }
                }
            }
            
            for try await path in group {
                XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            }
        }
    }
}
