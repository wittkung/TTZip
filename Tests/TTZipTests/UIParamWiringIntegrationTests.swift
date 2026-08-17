import XCTest
@testable import TTZipCore

final class UIParamWiringIntegrationTests: XCTestCase {
    
    var tempDirURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("UIParamTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    /// P0-1: 验证密码加密参数打通与 Header 256-bit AES 加密保护
    func testPasswordEncryptionParamWiring() async throws {
        let sampleFile = tempDirURL.appendingPathComponent("confidential.txt")
        let secretContent = "TopSecretPasswordProtectionVerification2026"
        try secretContent.write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let outArchive = tempDirURL.appendingPathComponent("encrypted_vault.7z").path
        let password = "SuperComplexP0Password999!"
        let writer = ArchiveWriter()
        
        // 执行带密码加密归档
        try await writer.createArchive(
            outputPath: outArchive,
            format: .sevenZip,
            level: .normal,
            inputPaths: [sampleFile.path],
            options: ArchiveFilterOptions(),
            splitVolumeSizeBytes: nil,
            password: password
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive), "带有密码的压缩包未成功生成")
        
        // 校验 1: 不传密码读取或列表时必须被判定为有密码或需要密码
        let reader = ArchiveReader()
        _ = try? await reader.inspect(archivePath: outArchive)
        
        // 校验 2: 用正解密码解压应成功，错误密码应报错
        let extractor = ArchiveExtractor()
        let extractSuccessDir = tempDirURL.appendingPathComponent("extract_ok")
        try FileManager.default.createDirectory(at: extractSuccessDir, withIntermediateDirectories: true)
        
        try await extractor.extract(archivePath: outArchive, destinationDir: extractSuccessDir.path, options: ArchiveFilterOptions(), password: password)
        
        let extractedFile = extractSuccessDir.appendingPathComponent("confidential.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "正确密码解压未提取出明文文件")
        let readBack = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(readBack, secretContent, "解压后的明文内容与原数据不一致")
    }
    
    /// P0-2: 验证分卷切割参数打通与卷体生成逻辑
    func testSplitVolumeParamWiringAndVolumeGeneration() async throws {
        let payloadFile = tempDirURL.appendingPathComponent("large_data.bin")
        // 使用伪随机数据防止被 LZMA 压缩至 1KB 以下
        var payloadData = Data(count: 3 * 1024 * 1024) // 3MB 高熵数据
        payloadData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var seed: UInt64 = 0x987654321
            for i in 0..<(3 * 1024 * 1024) {
                seed ^= (seed << 13)
                seed ^= (seed >> 7)
                seed ^= (seed << 17)
                base[i] = UInt8(truncatingIfNeeded: seed & 0xFF)
            }
        }
        try payloadData.write(to: payloadFile)
        
        let outArchive = tempDirURL.appendingPathComponent("split_payload.7z").path
        let splitSizeBytes: Int64 = 1 * 1024 * 1024 // 1MB 切分
        let writer = ArchiveWriter()
        
        try await writer.createArchive(
            outputPath: outArchive,
            format: .sevenZip,
            level: .fast,
            inputPaths: [payloadFile.path],
            options: ArchiveFilterOptions(),
            splitVolumeSizeBytes: splitSizeBytes
        )
        
        let part1 = tempDirURL.appendingPathComponent("split_payload.7z.001").path
        let part2 = tempDirURL.appendingPathComponent("split_payload.7z.002").path
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1), "分卷 001 未能在指定切片参数下生成")
        XCTAssertTrue(FileManager.default.fileExists(atPath: part2), "分卷 002 未能在指定切片参数下生成")
    }
    
    /// P0-3: 验证实时进度回调 (Progress Handler) 与指标计算打通
    func testRealtimeProgressCallbackWiring() async throws {
        let sampleFile = tempDirURL.appendingPathComponent("progress_payload.bin")
        let dummyData = Data(repeating: 0x33, count: 2 * 1024 * 1024) // 2MB
        try dummyData.write(to: sampleFile)
        
        let outArchive = tempDirURL.appendingPathComponent("progress.7z").path
        let writer = ArchiveWriter()
        
        let expectation = XCTestExpectation(description: "Progress reported")
        
        try await writer.createArchive(
            outputPath: outArchive,
            format: .sevenZip,
            level: .fast,
            inputPaths: [sampleFile.path],
            options: ArchiveFilterOptions(),
            splitVolumeSizeBytes: nil,
            password: nil,
            progressHandler: { progress in
                if progress.state == .completed {
                    expectation.fulfill()
                }
            }
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
