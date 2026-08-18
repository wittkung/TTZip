// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class TarNativeEngineTests: XCTestCase {
    
    private var tempDirURL: URL!
    
    override func setUp() {
        super.setUp()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let tempDirURL = tempDirURL {
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        super.tearDown()
    }
    
    func testTarNativeCreateAndExtract() throws {
        let sampleDir = tempDirURL.appendingPathComponent("SampleDir")
        try FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        
        let file1URL = sampleDir.appendingPathComponent("file1.txt")
        let file2URL = sampleDir.appendingPathComponent("file2.log")
        let subDir = sampleDir.appendingPathComponent("SubFolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let file3URL = subDir.appendingPathComponent("file3.json")
        
        try "Hello Native TAR 1".write(to: file1URL, atomically: true, encoding: .utf8)
        try "Hello Native TAR 2 Log Data".write(to: file2URL, atomically: true, encoding: .utf8)
        try "{\"key\": \"value\"}".write(to: file3URL, atomically: true, encoding: .utf8)
        
        let tarOutputPath = tempDirURL.appendingPathComponent("archive.tar").path
        let inputPaths = [sampleDir.path]
        
        let createStatus = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { buf in
            ttzip_create_tar_native_c(tarOutputPath, "tar", buf, inputPaths.count, true, 1)
        }
        XCTAssertEqual(createStatus, 0, "ttzip_create_tar_native_c should return 0 for tar format")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tarOutputPath))
        
        let destExtractDir = tempDirURL.appendingPathComponent("ExtractTar")
        let extractStatus = ttzip_extract_tar_native_c(tarOutputPath, destExtractDir.path, true)
        XCTAssertEqual(extractStatus, 0, "ttzip_extract_tar_native_c should return 0")
        
        let extFile1 = destExtractDir.appendingPathComponent("SampleDir/file1.txt")
        let extFile2 = destExtractDir.appendingPathComponent("SampleDir/file2.log")
        let extFile3 = destExtractDir.appendingPathComponent("SampleDir/SubFolder/file3.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile3.path))
        
        XCTAssertEqual(try String(contentsOf: extFile1, encoding: .utf8), "Hello Native TAR 1")
        XCTAssertEqual(try String(contentsOf: extFile3, encoding: .utf8), "{\"key\": \"value\"}")
    }
    
    func testTarGzNativeCreateAndExtract() throws {
        let sampleDir = tempDirURL.appendingPathComponent("SampleGzDir")
        try FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        let file1URL = sampleDir.appendingPathComponent("data.txt")
        try "Compressed GZ Content Stream".write(to: file1URL, atomically: true, encoding: .utf8)
        
        let tgzOutputPath = tempDirURL.appendingPathComponent("archive.tar.gz").path
        let inputPaths = [sampleDir.path]
        
        let createStatus = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { buf in
            ttzip_create_tar_native_c(tgzOutputPath, "tar.gz", buf, inputPaths.count, true, 1)
        }
        XCTAssertEqual(createStatus, 0, "ttzip_create_tar_native_c should return 0 for tar.gz format")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tgzOutputPath))
        
        let destExtractDir = tempDirURL.appendingPathComponent("ExtractTgz")
        let extractStatus = ttzip_extract_tar_native_c(tgzOutputPath, destExtractDir.path, true)
        XCTAssertEqual(extractStatus, 0, "ttzip_extract_tar_native_c should return 0 for tar.gz")
        
        let extFile1 = destExtractDir.appendingPathComponent("SampleGzDir/data.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extFile1.path))
        XCTAssertEqual(try String(contentsOf: extFile1, encoding: .utf8), "Compressed GZ Content Stream")
    }
    
    func testTarSWAROctalAndChecksumVerification() throws {
        // 1. 测试 64-bit SWAR 8 字节八进制解析 (8 个连续 ASCII 字符 '0'..'7')
        let octalStr = "00000755"
        let w_be = octalStr.utf8.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let parsedSwar = ttzip_octal_parse8_swar(w_be)
        XCTAssertEqual(parsedSwar, 0o755, "SWAR octal parse should correctly decode 00000755 to 0o755")
        
        // 2. 测试 12 字节标准八进制尺寸解析 (包含尾部空格和 NUL)
        let sizeStr = "00000001750 \0"
        let sizeVal = sizeStr.withCString { ptr in
            ttzip_tar_parse_octal(ptr, 12)
        }
        XCTAssertEqual(sizeVal, 0o1750, "Octal parser should decode 01750")
        
        // 3. 测试 GNU base-256 二进制大文件尺寸 (> 8 GiB)
        var base256Buf = [UInt8](repeating: 0, count: 12)
        base256Buf[0] = 0x80 // GNU binary indicator
        // 10 GiB = 10 * 1024 * 1024 * 1024 = 10737418240 (0x280000000)
        base256Buf[7] = 0x02
        base256Buf[8] = 0x80
        base256Buf[9] = 0x00
        base256Buf[10] = 0x00
        base256Buf[11] = 0x00
        let gnuSize = base256Buf.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: CChar.self, capacity: 12) { cptr in
                ttzip_tar_parse_octal(cptr, 12)
            }
        }
        XCTAssertEqual(gnuSize, 10737418240, "GNU base-256 binary format must decode 10 GiB accurately")
        
        // 4. 测试 512 字节全零块快速检测
        var zeroBlock = [UInt8](repeating: 0, count: 512)
        XCTAssertTrue(zeroBlock.withUnsafeBufferPointer { ttzip_tar_is_zero_block_512($0.baseAddress) })
        zeroBlock[255] = 1
        XCTAssertFalse(zeroBlock.withUnsafeBufferPointer { ttzip_tar_is_zero_block_512($0.baseAddress) })
        
        // 5. 测试真实 TAR 头部的快速解析与双向校验和验证
        var headerBlock = [UInt8](repeating: 0, count: 512)
        let fileName = "test_dir/sample_file.txt"
        for (i, b) in fileName.utf8.enumerated() { headerBlock[i] = b }
        
        // Mode 0644
        let modeStr = "0000644\0"
        for (i, b) in modeStr.utf8.enumerated() { headerBlock[100 + i] = b }
        
        // Size 1024 (0o2000)
        let fileSizeStr = "00000002000\0"
        for (i, b) in fileSizeStr.utf8.enumerated() { headerBlock[124 + i] = b }
        
        // Type '0' (regular)
        headerBlock[156] = UInt8(ascii: "0")
        
        // Magic "ustar\0"
        headerBlock[257] = UInt8(ascii: "u")
        headerBlock[258] = UInt8(ascii: "s")
        headerBlock[259] = UInt8(ascii: "t")
        headerBlock[260] = UInt8(ascii: "a")
        headerBlock[261] = UInt8(ascii: "r")
        headerBlock[262] = 0
        
        // Checksum 计算：标准中 offset 148..155 预填 8 个空格 (0x20)
        for i in 148..<156 { headerBlock[i] = 0x20 }
        var unsignedSum: UInt32 = 0
        var signedSum: Int32 = 0
        headerBlock.withUnsafeBufferPointer { ptr in
            ttzip_tar_checksum_512(ptr.baseAddress, &unsignedSum, &signedSum)
        }
        
        let chkStr = String(format: "%06o\0 ", unsignedSum)
        for (i, b) in chkStr.utf8.enumerated() where i < 8 { headerBlock[148 + i] = b }
        
        var entryInfo = ttzip_tar_entry_info_t()
        let parseOk = headerBlock.withUnsafeBufferPointer { ptr in
            ttzip_tar_header_parse_fast(ptr.baseAddress, &entryInfo)
        }
        
        XCTAssertTrue(parseOk, "Header parse fast should return true")
        XCTAssertTrue(entryInfo.checksum_valid, "Header checksum must validate successfully")
        XCTAssertTrue(entryInfo.is_ustar, "Ustar magic must be recognized")
        XCTAssertEqual(entryInfo.size, 1024, "Decoded size must be 1024")
        XCTAssertEqual(entryInfo.mode, 0o644, "Decoded mode must be 0644")
    }
}
