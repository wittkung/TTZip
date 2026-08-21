// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CharsetDetectorTests: XCTestCase {
    
    func testASCIICharsetDetection() {
        let asciiData = "hello_world.txt".data(using: .utf8)!
        let charset = CharsetDetector.detectCharset(data: asciiData)
        XCTAssertEqual(charset, "ASCII", "ASCII strings should be detected as ASCII")
    }
    
    func testUTF8ChineseCharsetDetection() {
        let utf8Data = "中文测试文档.docx".data(using: .utf8)!
        let sanitized = CharsetDetector.sanitizeFilename(bytes: utf8Data)
        XCTAssertEqual(sanitized, "中文测试文档.docx")
    }
    
    func testGBKChineseCharsetDetection() {
        // "你好测试文件.txt" in GBK / GB18030 (16 bytes)
        let gbkBytes: [UInt8] = [
            0xC4, 0xE3, // 你
            0xBA, 0xC3, // 好
            0xB2, 0xE2, // 测
            0xCA, 0xD4, // 试
            0xCE, 0xC4, // 文
            0xBC, 0xFE, // 件
            0x2E, 0x74, 0x78, 0x74 // .txt
        ]
        let data = Data(gbkBytes)
        
        let sanitized = CharsetDetector.sanitizeFilename(bytes: data)
        XCTAssertEqual(sanitized, "你好测试文件.txt", "GBK encoded bytes should be sanitized to proper Chinese string")
    }
    
    func testShiftJISJapaneseCharsetDetection() {
        // "日本語.zip" in Shift-JIS
        let sjisBytes: [UInt8] = [
            0x93, 0xFA, // 日
            0x96, 0x7B, // 本
            0x8C, 0xEA, // 語
            0x2E, 0x7A, 0x69, 0x70 // .zip
        ]
        let data = Data(sjisBytes)
        let sanitized = CharsetDetector.sanitizeFilename(bytes: data)
        XCTAssertEqual(sanitized, "日本語.zip")
    }

    func testBig5TraditionalChineseCharsetDetection() {
        // "測試檔件.txt" in Big5
        let big5Bytes: [UInt8] = [
            0xB4, 0xFA, // 測
            0xB8, 0xD5, // 試
            0xC0, 0xC9, // 檔
            0xA5, 0xF3, // 件
            0x2E, 0x74, 0x78, 0x74 // .txt
        ]
        let data = Data(big5Bytes)
        let sanitized = CharsetDetector.sanitizeFilename(bytes: data)
        XCTAssertEqual(sanitized, "測試檔件.txt")
    }
    
    func testEmptyDataDetection() {
        let charset = CharsetDetector.detectCharset(data: Data())
        XCTAssertEqual(charset, "ASCII")
    }
}
