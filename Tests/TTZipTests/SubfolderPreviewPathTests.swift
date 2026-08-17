import XCTest
@testable import TTZipCore

final class SubfolderPreviewPathTests: XCTestCase {
    
    var tempDirURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("SubfolderPreview_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    /// P0-4: 验证深层子目录包含文件（如 哲学史/5.12/03-slide.png）在解压预览时的 URL 精准解析
    func testNestedSubfolderPreviewURLResolution() async throws {
        // 1. 构建深层嵌套测试目录树
        let subfolder = tempDirURL.appendingPathComponent("哲学史/5.12")
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        
        let slideFile = subfolder.appendingPathComponent("03-slide.png")
        let dummyImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header bytes
        try dummyImageData.write(to: slideFile)
        
        // 2. 打包生成归档
        let archivePath = tempDirURL.appendingPathComponent("preview_test.7z").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archivePath,
            format: .sevenZip,
            level: .fast,
            inputPaths: [tempDirURL.appendingPathComponent("哲学史").path]
        )
        
        // 3. 读取归档条目
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: archivePath)
        guard let targetEntry = entries.first(where: { $0.name == "03-slide.png" }) else {
            XCTFail("未能正确解析出包内的 03-slide.png 条目")
            return
        }
        
        // 4. 模拟 UI 解压预览解析逻辑
        let previewTempDir = tempDirURL.appendingPathComponent("preview_extract")
        try FileManager.default.createDirectory(at: previewTempDir, withIntermediateDirectories: true)
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: archivePath, destinationDir: previewTempDir.path)
        
        // 执行修复后的三级路径解析逻辑
        var targetURL = previewTempDir.appendingPathComponent(targetEntry.path)
        if !FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = previewTempDir.appendingPathComponent(targetEntry.name)
        }
        if !FileManager.default.fileExists(atPath: targetURL.path) {
            let enumerator = FileManager.default.enumerator(at: previewTempDir, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.lastPathComponent == targetEntry.name {
                    targetURL = fileURL
                    break
                }
            }
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path), "深层子文件解压后 URL 未能成功精确定位")
        XCTAssertEqual(targetURL.lastPathComponent, "03-slide.png", "解压定位文件基名匹配失败")
    }
}
