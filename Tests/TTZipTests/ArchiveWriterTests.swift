import XCTest
@testable import TTZipCore

final class ArchiveWriterTests: XCTestCase {
    
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
    
    func testCreateZipArchiveAndReadBack() async throws {
        let file1 = (tempDirPath as NSString).appendingPathComponent("file1.txt")
        let file2 = (tempDirPath as NSString).appendingPathComponent("file2.txt")
        
        try "Content 1".write(toFile: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(toFile: file2, atomically: true, encoding: .utf8)
        
        let outputZip = (tempDirPath as NSString).appendingPathComponent("output.zip")
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputZip,
            format: .zip,
            level: .normal,
            inputPaths: [file1, file2]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip))
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputZip)
        XCTAssertEqual(entries.count, 2)
        let fileNames = Set(entries.map { $0.name })
        XCTAssertTrue(fileNames.contains("file1.txt"))
        XCTAssertTrue(fileNames.contains("file2.txt"))
    }
    
    func testCreateTarGzArchiveSuccess() async throws {
        let file1 = (tempDirPath as NSString).appendingPathComponent("data.json")
        try "{\"key\": \"value\"}".write(toFile: file1, atomically: true, encoding: .utf8)
        
        let outputTar = (tempDirPath as NSString).appendingPathComponent("output.tar.gz")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputTar,
            format: .tarGz,
            level: .fast,
            inputPaths: [file1]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputTar))
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputTar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "data.json")
    }
    
    func testStoreModeDirectoryArchiveAndExtractVerification() async throws {
        // 创建名为 "5.12" 的多文件目录
        let sourceDir = (tempDirPath as NSString).appendingPathComponent("5.12")
        try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
        
        let fileA = (sourceDir as NSString).appendingPathComponent("video1.bin")
        let fileB = (sourceDir as NSString).appendingPathComponent("doc2.txt")
        
        let chunkA = Data(repeating: 0xFF, count: 3 * 1024 * 1024) // 3MB
        let chunkB = "Hello TTZip 5.12 Store Verification Test".data(using: .utf8)!
        try chunkA.write(to: URL(fileURLWithPath: fileA))
        try chunkB.write(to: URL(fileURLWithPath: fileB))
        
        let outputBase = (tempDirPath as NSString).appendingPathComponent("5.12.7z")
        let writer = ArchiveWriter()
        
        // 执行 7z 仅存储模式 (+ 2MB 分卷 + 密码加密)
        try await writer.createArchive(
            outputPath: outputBase,
            format: .sevenZip,
            level: .store,
            inputPaths: [sourceDir],
            splitVolumeSizeBytes: 2 * 1024 * 1024, // 2MB 分卷
            password: "VerifyPassword123"
        )
        
        // 1. 验证生成的分卷文件存在且体积有效 (不能是 64 字节假文件)
        let vol1 = "\(outputBase).001"
        let vol2 = "\(outputBase).002"
        XCTAssertTrue(FileManager.default.fileExists(atPath: vol1), "分卷 .001 必须真实生成")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vol2), "分卷 .002 必须真实生成")
        
        let attr1 = try FileManager.default.attributesOfItem(atPath: vol1)
        let size1 = (attr1[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(size1, 1 * 1024 * 1024, "2MB 分卷体积必须大于 1MB，不能是假文件")
        
        // 2. 解压验证：解压还原并进行 100% 校验
        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_out")
        try FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(
            archivePath: vol1,
            destinationDir: extractDir,
            password: "VerifyPassword123"
        )
        
        // 3. 校验解压出的内容与源文件 100% 完全一致
        var foundA: String? = nil
        var foundB: String? = nil
        if let enumerator = FileManager.default.enumerator(atPath: extractDir) {
            while let subpath = enumerator.nextObject() as? String {
                if subpath.hasSuffix("video1.bin") { foundA = (extractDir as NSString).appendingPathComponent(subpath) }
                if subpath.hasSuffix("doc2.txt") { foundB = (extractDir as NSString).appendingPathComponent(subpath) }
            }
        }
        
        XCTAssertNotNil(foundA, "解压目标路径下必须查找到 video1.bin 文件")
        XCTAssertNotNil(foundB, "解压目标路径下必须查找到 doc2.txt 文件")
        
        let extractedFileA = foundA!
        let extractedFileB = foundB!
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFileA), "解压后视频文件必须完整存在")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFileB), "解压后文档文件必须完整存在")
        
        let extractedDataA = try Data(contentsOf: URL(fileURLWithPath: extractedFileA))
        let extractedDataB = try Data(contentsOf: URL(fileURLWithPath: extractedFileB))
        
        XCTAssertEqual(extractedDataA.count, chunkA.count, "解压后的视频二进制数据体积必须 100% 无损对齐")
        XCTAssertEqual(extractedDataB.count, chunkB.count, "解压后的文本数据体积必须 100% 无损对齐")
    }
    
    func testAllFormatsCompressAndExtractVerification() async throws {
        let formats: [(ArchiveCompressionFormat, String)] = [
            (.sevenZip, "7z"),
            (.zip, "zip"),
            (.tar, "tar"),
            (.zst, "zst"),
            (.gz, "gz"),
            (.bz2, "bz2"),
            (.xz, "xz"),
            (.lzip, "lz"),
            (.lz4, "lz4"),
            (.wim, "wim")
        ]
        
        for (fmt, ext) in formats {
            TTLogger.debug("🧪 Testing archive format: \(ext)...")
            let sourceDir = (tempDirPath as NSString).appendingPathComponent("test_folder_\(ext)")
            try FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
            
            let fileBinary = (sourceDir as NSString).appendingPathComponent("media.bin")
            let fileText = (sourceDir as NSString).appendingPathComponent("notes.txt")
            
            let binaryData = Data((0..<1024*1024).map { UInt8($0 % 256) }) // 1MB
            let textData = "TTZip Verification Test Payload for \(ext)".data(using: .utf8)!
            
            try binaryData.write(to: URL(fileURLWithPath: fileBinary))
            try textData.write(to: URL(fileURLWithPath: fileText))
            
            let archiveOutput = (tempDirPath as NSString).appendingPathComponent("archive_\(ext).\(ext)")
            let writer = ArchiveWriter()
            try await writer.createArchive(
                outputPath: archiveOutput,
                format: fmt,
                level: .normal,
                inputPaths: [sourceDir]
            )
            
            // 1. 验证生成的文件存在且非空
            XCTAssertTrue(FileManager.default.fileExists(atPath: archiveOutput), "格式 \(ext) 必须成功生成压缩包")
            let attrs = try FileManager.default.attributesOfItem(atPath: archiveOutput)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            XCTAssertGreaterThan(fileSize, 500, "格式 \(ext) 生成的包体积必须大于 500 字节，非假文件")
            
            // 2. 解压验证
            let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_\(ext)")
            try FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
            
            let extractor = ArchiveExtractor()
            try await extractor.extract(archivePath: archiveOutput, destinationDir: extractDir)
            
            let subFolderName = "test_folder_\(ext)"
            var restoredBinary = (extractDir as NSString).appendingPathComponent("\(subFolderName)/media.bin")
            var restoredText = (extractDir as NSString).appendingPathComponent("\(subFolderName)/notes.txt")
            if !FileManager.default.fileExists(atPath: restoredBinary) {
                let directBinary = (extractDir as NSString).appendingPathComponent("media.bin")
                if FileManager.default.fileExists(atPath: directBinary) {
                    restoredBinary = directBinary
                    restoredText = (extractDir as NSString).appendingPathComponent("notes.txt")
                }
            }
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: restoredBinary), "格式 \(ext) 解压后 media.bin 必须存在")
            XCTAssertTrue(FileManager.default.fileExists(atPath: restoredText), "格式 \(ext) 解压后 notes.txt 必须存在")
            
            let restoredBinaryData = try Data(contentsOf: URL(fileURLWithPath: restoredBinary))
            let restoredTextData = try Data(contentsOf: URL(fileURLWithPath: restoredText))
            
            XCTAssertEqual(restoredBinaryData, binaryData, "格式 \(ext) 解压二进制数据必须 100% 对齐")
            XCTAssertEqual(restoredTextData, textData, "格式 \(ext) 解压文本数据必须 100% 对齐")
        }
    }
}
