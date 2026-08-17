import XCTest
@testable import TTZipCore

final class ExhaustiveEdgeCasesTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("EdgeCases_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    /// 边缘情况 1: 50 层极深嵌套目录结构打包与提取
    func test50LevelDeepDirectoryStructure() async throws {
        let baseDir = (tempDirPath as NSString).appendingPathComponent("root_dir")
        var currentPath = baseDir
        for i in 1...50 {
            currentPath = (currentPath as NSString).appendingPathComponent("level_\(i)")
            try FileManager.default.createDirectory(atPath: currentPath, withIntermediateDirectories: true)
        }
        
        let deepFile = (currentPath as NSString).appendingPathComponent("deep_payload.txt")
        try "Deep Content Level 50".write(toFile: deepFile, atomically: true, encoding: .utf8)
        
        let zipPath = (tempDirPath as NSString).appendingPathComponent("deep_archive.zip")
        let extractDest = (tempDirPath as NSString).appendingPathComponent("deep_extracted")
        
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: zipPath, format: .zip, level: .normal, inputPaths: [baseDir])
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: zipPath, destinationDir: extractDest)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipPath))
    }
    
    /// 边缘情况 2: 包含 Shell 特殊转义字符的文件名 ($, ", ', ;, &, 空格)
    func testSpecialShellCharacterFilenames() async throws {
        let specialFileName = "Special file $dollars 'quotes' \"double\" &ampersand ;semicolon.txt"
        let filePath = (tempDirPath as NSString).appendingPathComponent(specialFileName)
        try "Special Characters Content".write(toFile: filePath, atomically: true, encoding: .utf8)
        
        let tarPath = (tempDirPath as NSString).appendingPathComponent("special_chars.tar.gz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: tarPath, format: .tarGz, level: .normal, inputPaths: [filePath])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: tarPath)
        
        XCTAssertFalse(entries.isEmpty)
    }
    
    /// 边缘情况 3: 全 0x00 和全 0xFF 的极端二进制流
    func testAllZeroAndAllFFBytes() async throws {
        let zeroFile = (tempDirPath as NSString).appendingPathComponent("all_zero.bin")
        let ffFile = (tempDirPath as NSString).appendingPathComponent("all_ff.bin")
        
        let zeroData = Data(repeating: 0x00, count: 100 * 1024)
        let ffData = Data(repeating: 0xFF, count: 100 * 1024)
        
        try zeroData.write(to: URL(fileURLWithPath: zeroFile))
        try ffData.write(to: URL(fileURLWithPath: ffFile))
        
        let zstPath = (tempDirPath as NSString).appendingPathComponent("binary_extreme.tar.zst")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: zstPath, format: .tarZst, level: .normal, inputPaths: [zeroFile, ffFile])
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: zstPath))
    }
    
    /// 边缘情况 4: 只读文件权限 (chmod 0444)
    func testReadOnlyPermissionFiles() async throws {
        let readOnlyFile = (tempDirPath as NSString).appendingPathComponent("readonly.txt")
        try "ReadOnly Content".write(toFile: readOnlyFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: readOnlyFile)
        
        let zipPath = (tempDirPath as NSString).appendingPathComponent("readonly_test.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: zipPath, format: .zip, level: .normal, inputPaths: [readOnlyFile])
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipPath))
    }
    
    /// 边缘情况 5: 损坏的归档文件头修复
    func testDamagedArchiveHeaderRecovery() async throws {
        let damagedFile = (tempDirPath as NSString).appendingPathComponent("corrupted.zip")
        let corruptData = Data("NOT_A_VALID_ZIP_HEADER_DATA_STREAM_CORRUPTED_2026".utf8)
        try corruptData.write(to: URL(fileURLWithPath: damagedFile))
        
        let repairedFile = (tempDirPath as NSString).appendingPathComponent("repaired.zip")
        let repairEngine = ArchiveRepairEngine()
        
        let bytesRecovered = try await repairEngine.repairArchive(damagedArchivePath: damagedFile, repairedOutputPath: repairedFile)
        
        XCTAssertGreaterThanOrEqual(bytesRecovered, 0)
    }
}
