// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class SevenZipHeaderParserTests: XCTestCase {
    
    // 验证 7Z 变长整数 (UInt64 Varint) 全尺寸与边界解码
    func testSevenZipVarint_AllByteLengthsAndBoundaries() {
        // 1. 单字节 (k = 0, 0x00 .. 0x7F)
        for v in [0x00, 0x01, 0x42, 0x7F] {
            let buf: [UInt8] = [UInt8(v)]
            var val: UInt64 = 0
            let consumed = buf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 1)
            XCTAssertEqual(val, UInt64(v))
        }
        
        // 2. 双字节 (k = 1, 0x80..0xBF + 1 byte)
        // 0x81, 0x23 -> (0x81 & 0x3F) << 8 | 0x23 = 0x0123 = 291
        do {
            let buf: [UInt8] = [0x81, 0x23]
            var val: UInt64 = 0
            let consumed = buf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 2)
            XCTAssertEqual(val, 0x0123)
        }
        
        // 3. 3字节 (k = 2)
        // 0xC2, 0x34, 0x12 -> (0xC2 & 0x1F) << 16 | (0x1234) = 0x021234
        do {
            let buf: [UInt8] = [0xC2, 0x34, 0x12]
            var val: UInt64 = 0
            let consumed = buf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 3)
            XCTAssertEqual(val, 0x021234)
        }
        
        // 4. 4字节 (k = 3)
        do {
            let buf: [UInt8] = [0xE5, 0x78, 0x56, 0x34]
            var val: UInt64 = 0
            let consumed = buf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 4)
            XCTAssertEqual(val, (UInt64(0xE5 & 0x0F) << 24) | 0x345678)
        }
        
        // 5. 9字节 (k = 8, 0xFF + 8 bytes payload, 全 64 位无未定义行为)
        do {
            let buf: [UInt8] = [0xFF, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
            var val: UInt64 = 0
            let consumed = buf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 9)
            XCTAssertEqual(val, 0x8877665544332211)
        }
        
        // 6. 最大 64 位整数 0xFFFFFFFFFFFFFFFF
        do {
            let buf: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
            var val: UInt64 = 0
            let consumed = buf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 9)
            XCTAssertEqual(val, UInt64.max)
        }
        
        // 7. 截断缓冲区错误处理
        do {
            let truncatedBuf: [UInt8] = [0xFF, 0x11, 0x22] // 需要 9 字节但只有 3 字节
            var val: UInt64 = 0
            let consumed = truncatedBuf.withUnsafeBufferPointer { ptr in
                ttzip_7z_read_varint(ptr.baseAddress, ptr.count, &val)
            }
            XCTAssertEqual(consumed, 0, "Truncated buffer should return 0 consumed bytes")
        }
    }
}
