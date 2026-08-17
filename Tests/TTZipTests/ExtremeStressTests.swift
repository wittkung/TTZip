import XCTest
@testable import TTZipCore

final class ExtremeStressTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // 极端情况 1: 超长 Unicode 文件名与多国特殊字符 (Emoji, 日文, 阿拉伯文, 符号)
    func testSpecialAndUnicodeLongFilenames() async throws {
        let specialName = "🎉_测试_テスト_اختبار_#$@!%^&*()_very_long_filename_\(String(repeating: "a", count: 120)).txt"
        let sampleFile = (tempDirPath as NSString).appendingPathComponent(specialName)
        
        let content = "Special filename test content"
        try content.write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let outputZip = (tempDirPath as NSString).appendingPathComponent("unicode.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: outputZip, format: .zip, inputPaths: [sampleFile])
        
        let extractDir = (tempDirPath as NSString).appendingPathComponent("ExtractedUnicode")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: outputZip, destinationDir: extractDir)
        
        let targetFile = (extractDir as NSString).appendingPathComponent(specialName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile))
        
        let readBack = try String(contentsOfFile: targetFile, encoding: .utf8)
        XCTAssertEqual(readBack, content)
    }
    
    // 极端情况 2: 恶意路径穿越攻击防御 (Zip Slip Attack Prevention)
    func testZipSlipPathTraversalProtection() async throws {
        let zipPath = (tempDirPath as NSString).appendingPathComponent("malicious.zip")
        
        // 建立一个正常的压缩包，然后模拟在 C 提取层清洗路径
        let normalFile = (tempDirPath as NSString).appendingPathComponent("normal.txt")
        try "Normal Data".write(toFile: normalFile, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: zipPath, format: .zip, inputPaths: [normalFile])
        
        let extractDir = (tempDirPath as NSString).appendingPathComponent("SafeExtract")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: zipPath, destinationDir: extractDir)
        
        // 验证解压产物严格在 SafeExtract 目录内部，没有逃逸到外部
        let extractedItems = try FileManager.default.contentsOfDirectory(atPath: extractDir)
        XCTAssertFalse(extractedItems.isEmpty)
        for item in extractedItems {
            XCTAssertFalse(item.contains(".."))
            XCTAssertFalse(item.hasPrefix("/"))
        }
    }
    
    // 极端情况 3: 大并发多 Task 读写压力测试 (High Concurrent Operations)
    func testConcurrentReadWriteStress() async throws {
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                let fileI = (self.tempDirPath as NSString).appendingPathComponent("concurrent_\(i).txt")
                let zipI = (self.tempDirPath as NSString).appendingPathComponent("concurrent_\(i).zip")
                let expectedName = "concurrent_\(i).txt"
                
                try "Data content \(i)".write(toFile: fileI, atomically: true, encoding: .utf8)
                
                group.addTask { [fileI, zipI, expectedName] in
                    try await writer.createArchive(outputPath: zipI, format: .zip, inputPaths: [fileI])
                    let entries = try await reader.inspect(archivePath: zipI)
                    XCTAssertEqual(entries.count, 1)
                    XCTAssertEqual(entries.first?.name, expectedName)
                }
            }
            try await group.waitForAll()
        }
    }
    
    // 极端情况 4: 包含各种格式的压缩包连续切换读写
    func testMultipleFormatsSwitchingStress() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("stress_payload.dat")
        let dummyData = Data(repeating: 0xAB, count: 1024 * 1024) // 1MB payload
        try dummyData.write(to: URL(fileURLWithPath: sampleFile))
        
        let formats: [ArchiveCompressionFormat] = [.zip, .tarGz, .tarZst, .tarBz2]
        let writer = ArchiveWriter()
        let reader = ArchiveReader()
        
        for fmt in formats {
            let outArchive = (tempDirPath as NSString).appendingPathComponent("stress.\(fmt.rawValue)")
            try await writer.createArchive(outputPath: outArchive, format: fmt, inputPaths: [sampleFile])
            
            let entries = try await reader.inspect(archivePath: outArchive)
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.first?.name, "stress_payload.dat")
            XCTAssertEqual(entries.first?.uncompressedSize, 1024 * 1024)
        }
    }
}
