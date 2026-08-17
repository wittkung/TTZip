import XCTest
@testable import TTZipCore

final class AppServicesAndCLICoverageTests: XCTestCase {
    
    var tempDirURL: URL!
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("AppServicesTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        tempDirPath = tempDirURL.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // 1. 测试 DeepFileMetadataReader 读取 POSIX 属性与 Inode 属性
    func testDeepFileMetadataReader() async throws {
        let sampleFile = tempDirURL.appendingPathComponent("metadata_sample.txt")
        try "Metadata Reader Test Data 2026".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let metadata = await DeepFileMetadataReader.readMetadata(for: sampleFile)
        XCTAssertFalse(metadata.isEmpty)
        XCTAssertNotNil(metadata["POSIX 权限码"])
        XCTAssertNotNil(metadata["所有者 : 用户组"])
        XCTAssertNotNil(metadata["APFS Inode 编号"])
    }
    
    // 2. 测试 FolderStatsCalculator 统计尺寸与分类分布
    func testFolderStatsCalculator() async throws {
        let subDir = tempDirURL.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let docFile = subDir.appendingPathComponent("doc.txt")
        try "Text Document Content".write(to: docFile, atomically: true, encoding: .utf8)
        
        let mediaFile = subDir.appendingPathComponent("video.mp4")
        try Data([0x00, 0x00, 0x00, 0x18]).write(to: mediaFile)
        
        let stats = await FolderStatsCalculator.calculateStats(for: tempDirPath)
        XCTAssertGreaterThan(stats.size, 0)
        XCTAssertEqual(stats.subfolders, 1)
        XCTAssertEqual(stats.files, 2)
        XCTAssertFalse(stats.dist.isEmpty)
    }
    
    // 3. 测试 FileClipboardStore 复制 / 剪切 / 重名避让
    @MainActor
    func testFileClipboardStore() throws {
        let store = FileClipboardStore.shared
        let file1 = tempDirURL.appendingPathComponent("clip_1.txt")
        try "Clip 1".write(to: file1, atomically: true, encoding: .utf8)
        
        store.copy(urls: [file1])
        XCTAssertTrue(store.canPaste)
        XCTAssertFalse(store.isCutOperation)
        
        let pasteTargetDir = tempDirURL.appendingPathComponent("pasted_target")
        try FileManager.default.createDirectory(at: pasteTargetDir, withIntermediateDirectories: true)
        
        store.paste(to: pasteTargetDir)
        let pastedFile = pasteTargetDir.appendingPathComponent("clip_1.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pastedFile.path))
    }
    
    // 4. 测试 DateFormatterCache 与 ByteCountFormatterCache 高效格式化缓存
    func testFormattersCache() {
        let sizeString = ByteCountFormatterCache.string(fromByteCount: 1024 * 1024 * 50)
        XCTAssertFalse(sizeString.isEmpty)
        
        let dateString = DateFormatterCache.shared.string(fromShortDateTime: Date())
        XCTAssertFalse(dateString.isEmpty)
    }
}
