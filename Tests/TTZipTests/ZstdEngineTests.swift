// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ZstdEngineTests: XCTestCase {
    var tempDir: URL!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zstd_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testNativeZstdEngineCompressAndDecompress() throws {
        let sampleFile = tempDir.appendingPathComponent("sample.txt")
        let zstdFile = tempDir.appendingPathComponent("sample.txt.zst")
        let extractedFile = tempDir.appendingPathComponent("sample_extracted.txt")
        
        let sampleContent = String(repeating: "Apple Silicon M5 Max Native Zstandard Compression Test Line 2026\n", count: 5000)
        try sampleContent.write(to: sampleFile, atomically: true, encoding: .utf8)
        
        // 1.
        let compressSuccess = try NativeZstdEngine.shared.compressFile(
            srcPath: sampleFile.path,
            dstPath: zstdFile.path,
            level: .normal,
            enableLDM: true
        )
        XCTAssertTrue(compressSuccess, "Zstd 物理压缩应当成功")
        XCTAssertTrue(FileManager.default.fileExists(atPath: zstdFile.path))
        
        // 2. RFC 8878
        let isValidFrame = NativeZstdEngine.shared.isValidZstdFrame(atPath: zstdFile.path)
        XCTAssertTrue(isValidFrame, "应当正确识别 RFC 8878 帧魔数")
        
        let descriptor = NativeZstdEngine.shared.inspectFrame(atPath: zstdFile.path)
        XCTAssertNotNil(descriptor)
        XCTAssertEqual(descriptor?.magicNumber, NativeZstdEngine.zstdMagicNumber)
        
        // 3.
        let decompressSuccess = try NativeZstdEngine.shared.decompressFile(
            srcPath: zstdFile.path,
            dstPath: extractedFile.path
        )
        XCTAssertTrue(decompressSuccess, "Zstd 物理解压应当成功")
        
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, sampleContent, "解压后的字节数据必须与原始数据 100% 一致")
    }
}
