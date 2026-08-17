import XCTest
import CryptoKit
@testable import TTZipCore

final class Phase123FeatureCoverageTests: XCTestCase {
    
    var tempDirURL: URL!
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("Phase123Test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        tempDirPath = tempDirURL.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // 1. 验证 128GB Apple Silicon 物理内存调优与长匹配视窗
    func testAppleSilicon128GBHardwareTuning() {
        let tuner = AppleSiliconTuner.shared
        XCTAssertGreaterThan(tuner.topology.totalCores, 0)
        XCTAssertGreaterThan(tuner.optimalEfficiencyThreads, 0)
        XCTAssertGreaterThan(tuner.optimalBurstThreads, 0)
        
        if tuner.topology.unifiedMemoryGB >= 48.0 {
            XCTAssertGreaterThanOrEqual(tuner.autoTunedConfig.recommendedDictionarySizeMB, 1024)
            XCTAssertEqual(tuner.optimalZstdLongWindowLog, 31)
            XCTAssertGreaterThanOrEqual(tuner.autoTunedConfig.recommendedBufferSize, 16 * 1024 * 1024)
        }
    }
    
    // 2. 验证原生 C-Bridge Zstd 与 LZ4 高速加解密流
    func testNativeCBridgeZstdAndLZ4Roundtrip() throws {
        let sampleText = String(repeating: "TTZip Pro Native C-Bridge Zstd & LZ4 High Speed Stream Payload 2026\n", count: 100)
        let sampleData = Data(sampleText.utf8)
        
        let lz4Engine = LZ4LzoEngine()
        let lz4Compressed = lz4Engine.compress(data: sampleData)
        let lz4Decompressed = lz4Engine.decompress(data: lz4Compressed, originalSizeHint: sampleData.count)
        XCTAssertEqual(lz4Decompressed, sampleData, "LZ4 C-Bridge 解压数据应与源数据 100% 一致")
        
        let zstdEngine = ZstdDictionaryEngine(compressionLevel: 3)
        let zstdCompressed = zstdEngine.compressPayload(data: sampleData)
        let zstdDecompressed = try zstdEngine.decompressPayload(data: zstdCompressed, uncompressedCapacityHint: sampleData.count)
        XCTAssertEqual(zstdDecompressed, sampleData, "Zstd C-Bridge 解压数据应与源数据 100% 一致")
    }
    
    // 3. 验证标准 Zip64 及 7z 加密分卷创建与解密提取
    func testStandardEncryptedSplitVolumeCreationAndExtraction() async throws {
        guard SevenZipBinaryResolver.resolveBinaryPath() != nil else {
            throw XCTSkip("7zz binary not available in local environment")
        }
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("split_payload.bin")
        let sampleData = Data(repeating: 0x99, count: 5 * 1024 * 1024) // 5MB
        try sampleData.write(to: URL(fileURLWithPath: sampleFile))
        
        let splitEngine = NativeParallelEncryptedSplitEngine()
        let password = "SplitVolumePassword2026"
        let splitOutDir = (tempDirPath as NSString).appendingPathComponent("split_out")
        try FileManager.default.createDirectory(atPath: splitOutDir, withIntermediateDirectories: true)
        
        // 创建 7z 1MB 分卷
        let splitFiles7z = try await splitEngine.createStandardEncryptedSplitVolume(
            format: .sevenZip,
            sourcePaths: [sampleFile],
            outputDir: splitOutDir,
            baseName: "test_7z_split",
            splitVolumeSizeBytes: 1024 * 1024,
            password: password
        )
        XCTAssertGreaterThan(splitFiles7z.count, 1, "7z 应成功拆分为多个分卷文件")
        
        // 解压 7z 分卷验证
        let extractDest7z = (tempDirPath as NSString).appendingPathComponent("extracted_7z_split")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: splitFiles7z.first!, destinationDir: extractDest7z, password: password)
        let allFiles = (try? FileManager.default.subpathsOfDirectory(atPath: extractDest7z)) ?? []
        XCTAssertTrue(allFiles.contains(where: { $0.hasSuffix("split_payload.bin") }), "分卷解压后应包含 split_payload.bin")
        if let rel = allFiles.first(where: { $0.hasSuffix("split_payload.bin") }) {
            let extractedFile7z = (extractDest7z as NSString).appendingPathComponent(rel)
            let extractedData7z = try Data(contentsOf: URL(fileURLWithPath: extractedFile7z))
            XCTAssertEqual(extractedData7z, sampleData, "分卷解压提取文件应与原数据完全无损匹配")
        }
    }
    
    // 4. 验证真实 7zz 命令行多线程密码恢复与破解引擎
    func testRealPasswordRecoveryEngine() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("recover_sample.txt")
        try "Secret Archive Payload Content 2026".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let targetArchive = (tempDirPath as NSString).appendingPathComponent("protected_archive.7z")
        let correctPassword = "target_password_2026"
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: targetArchive,
            format: .sevenZip,
            level: .fast,
            inputPaths: [sampleFile],
            password: correctPassword
        )
        
        let dictionary = ["123456", "wrong_pwd_1", "admin", correctPassword, "wrong_pwd_2"]
        let recoveryEngine = PasswordRecoveryEngine()
        
        let result = try await recoveryEngine.recoverPassword(archivePath: targetArchive, dictionary: dictionary)
        XCTAssertEqual(result.foundPassword, correctPassword, "密码恢复引擎应准确探测并解出正确的真实密码")
        XCTAssertGreaterThan(result.totalAttempts, 0)
        XCTAssertGreaterThan(result.attemptsPerSecond, 0)
    }
    
    // 5. 验证二进制文件 (.dylib) 固实打包无损性
    func testLosslessSolidArchiveEngineWithBinaryData() async throws {
        let dylibPath = (tempDirPath as NSString).appendingPathComponent("test_binary.dylib")
        var dummyDylib = Data([0xCF, 0xFA, 0xED, 0xFE]) // Mach-O 64-bit Header
        dummyDylib.append(Data(repeating: 0xE8, count: 1024))
        dummyDylib.append(Data(repeating: 0xE9, count: 1024))
        try dummyDylib.write(to: URL(fileURLWithPath: dylibPath))
        
        let solidArchivePath = (tempDirPath as NSString).appendingPathComponent("solid_binary.7z")
        let solidEngine = SolidArchiveEngine()
        
        try await solidEngine.createSolidArchive(outputPath: solidArchivePath, inputPaths: [dylibPath])
        
        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_solid")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: solidArchivePath, destinationDir: extractDir)
        
        let extractedDylibPath = (extractDir as NSString).appendingPathComponent("test_binary.dylib")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedDylibPath))
        
        let extractedData = try Data(contentsOf: URL(fileURLWithPath: extractedDylibPath))
        XCTAssertEqual(extractedData, dummyDylib, "固实打包解压后的 Mach-O 二进制文件应 100% 保持字节精确比对无损")
    }
    
    // 6. 验证 PasswordVault 自动匹配无感预览与解压
    func testPasswordVaultAutoUnlockIntegration() async throws {
        let vaultManager = PasswordVaultManager.shared
        vaultManager.setMasterPassword("TestMasterPassword2026")
        let testPassword = "VaultAutoMatchPassword2026"
        vaultManager.addEntry(label: "自动测试密码", password: testPassword)
        
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("vault_sample.txt")
        try "Vault Auto Unlock Content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let encryptedArchivePath = (tempDirPath as NSString).appendingPathComponent("encrypted_vault_test.7z")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: encryptedArchivePath,
            format: .sevenZip,
            level: .fast,
            inputPaths: [sampleFile],
            password: testPassword
        )
        
        // 当不显式传入 password 参数时，ArchiveReader 自动尝试 PasswordVault 口令池无感解锁
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: encryptedArchivePath, password: nil)
        XCTAssertFalse(entries.isEmpty, "PasswordVault 自动解锁应成功无感解析元数据")
        XCTAssertTrue(entries.contains(where: { $0.path.contains("vault_sample.txt") }))
        
        // 当不显式传入 password 参数时，ArchiveExtractor 自动尝试 PasswordVault 口令池无感提取
        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_vault_auto")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: encryptedArchivePath, destinationDir: extractDir, password: nil)
        
        let allVaultFiles = (try? FileManager.default.subpathsOfDirectory(atPath: extractDir)) ?? []
        XCTAssertTrue(allVaultFiles.contains(where: { $0.hasSuffix("vault_sample.txt") }), "PasswordVault 自动解锁应成功无感解压提取文件")
    }
    
    // 7. 验证 16MB 页面对齐硬件级 HashCalculator & ArchiveIntegrityChecker 速率与正确性
    func testPageAlignedHighThroughputHashCalculator() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("hash_sample.bin")
        let payload = Data(repeating: 0x55, count: 10 * 1024 * 1024) // 10MB
        try payload.write(to: URL(fileURLWithPath: sampleFile))
        
        let calculator = HashCalculator()
        let sha256Hex = try await calculator.computeHash(filePath: sampleFile, type: .sha256)
        let md5Hex = try await calculator.computeHash(filePath: sampleFile, type: .md5)
        let crc32Hex = try await calculator.computeHash(filePath: sampleFile, type: .crc32)
        
        XCTAssertEqual(sha256Hex.count, 64)
        XCTAssertEqual(md5Hex.count, 32)
        XCTAssertEqual(crc32Hex.count, 8)
        
        let checker = ArchiveIntegrityChecker()
        let checkerSha256 = try await checker.computeSHA256(filePath: sampleFile)
        XCTAssertEqual(checkerSha256, sha256Hex, "ArchiveIntegrityChecker SHA256 应与 HashCalculator 完全匹配")
    }
}
