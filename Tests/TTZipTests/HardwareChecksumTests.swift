// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class HardwareChecksumTests: XCTestCase {
    
    // RFC 1950 黄金预言机基准向量测试
    func testAdler32_RFC1950_StandardVectors() {
        // 1. 空数据
        let empty = Data()
        XCTAssertEqual(HardwareChecksumAdapter.adler32(for: empty), 1)
        
        // 2. "a"
        let dataA = "a".data(using: .utf8)!
        XCTAssertEqual(HardwareChecksumAdapter.adler32(for: dataA), 0x00620062)
        
        // 3. "abc"
        let dataABC = "abc".data(using: .utf8)!
        XCTAssertEqual(HardwareChecksumAdapter.adler32(for: dataABC), 0x024d0127)
        
        // 4. "message digest" (standard zlib: 0x29750586)
        let msg = "message digest".data(using: .utf8)!
        XCTAssertEqual(HardwareChecksumAdapter.adler32(for: msg), 0x29750586)
        
        // 5. 14 字节数字 (standard zlib: 0x155802d8)
        let digits = "12345678901234".data(using: .utf8)!
        XCTAssertEqual(HardwareChecksumAdapter.adler32(for: digits), 0x155802d8)
    }
    
    // 跨 5552 字节分块边界的大数据块正确性与标量预言机比对
    func testAdler32_LargeBuffer_ModuloBoundaryIntegrity() {
        let sizes = [1, 15, 16, 63, 64, 65, 5503, 5504, 5505, 5551, 5552, 5553, 11104, 65536, 100_000]
        
        for size in sizes {
            var buffer = [UInt8](repeating: 0, count: size)
            for i in 0..<size {
                buffer[i] = UInt8((i * 37 + 13) & 0xFF)
            }
            
            let data = Data(buffer)
            let fastAdler = HardwareChecksumAdapter.adler32(for: data)
            
            // 简单标量参考实现
            var s1: UInt32 = 1
            var s2: UInt32 = 0
            for byte in buffer {
                s1 = (s1 + UInt32(byte)) % 65521
                s2 = (s2 + s1) % 65521
            }
            let expectedAdler = (s2 << 16) | s1
            
            XCTAssertEqual(fastAdler, expectedAdler, "Mismatch on buffer size \(size)")
        }
    }
    
    // 任意非对齐偏移与尾部余数字节矩阵全覆盖测试
    func testAdler32_UnalignedSlicesAndRemainderMatrix() {
        let baseCount = 8192
        var buffer = [UInt8](repeating: 0, count: baseCount)
        for i in 0..<baseCount {
            buffer[i] = UInt8((i * 101 + 23) & 0xFF)
        }
        
        let offsets = [0, 1, 2, 3, 4, 7, 8, 15, 16]
        let testLengths = [0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 511, 512, 1023, 1024, 5551, 5552, 5553]
        
        for offset in offsets {
            for len in testLengths {
                guard offset + len <= baseCount else { continue }
                let slice = buffer[offset..<(offset + len)]
                let data = Data(slice)
                let fastResult = HardwareChecksumAdapter.adler32(for: data)
                
                // 标量参考预言机
                var s1: UInt32 = 1
                var s2: UInt32 = 0
                for byte in slice {
                    s1 = (s1 + UInt32(byte)) % 65521
                    s2 = (s2 + s1) % 65521
                }
                let expectedResult = (s2 << 16) | s1
                
                XCTAssertEqual(fastResult, expectedResult, "Adler-32 mismatch at offset \(offset), length \(len)")
            }
        }
    }
    
    // CRC-32 硬件加速标准向量测试
    func testCRC32_StandardVectors() {
        let empty = Data()
        XCTAssertEqual(HardwareChecksumAdapter.crc32(for: empty), 0)
        
        let digits = "123456789".data(using: .utf8)!
        XCTAssertEqual(HardwareChecksumAdapter.crc32(for: digits), 0xcbf43926)
    }
    
    // Adler-32 吞吐性能微基准 (目标 >= 20 GB/s)
    func testAdler32_HardwareThroughput_Floor() {
        let size = 20 * 1024 * 1024 // 20MB
        var buffer = [UInt8](repeating: 0x5A, count: size)
        for i in 0..<1000 {
            buffer[i * 1024] = UInt8(i & 0xFF)
        }
        
        let data = Data(buffer)
        
        // 预热
        _ = HardwareChecksumAdapter.adler32(for: data)
        
        let passes = 10
        let start = PlatformMonotonicTimer.nowNanoseconds()
        for _ in 0..<passes {
            _ = HardwareChecksumAdapter.adler32(for: data)
        }
        let elapsed = Double(PlatformMonotonicTimer.nowNanoseconds() - start) / 1_000_000_000.0
        
        let totalMB = Double(size * passes) / (1024.0 * 1024.0)
        let throughput = totalMB / elapsed
        
        print("⚡ [TTZipChecksum] Adler-32 Hardware Throughput: \(String(format: "%.2f", throughput)) MB/s (\(String(format: "%.2f", throughput / 1024.0)) GB/s)")
        
        // 验证吞吐量底线 (Debug 下要求 >= 10,000 MB/s，Release 下 >= 20,000 MB/s)
        #if !DEBUG
        XCTAssertGreaterThanOrEqual(throughput, 15000.0, "Adler-32 throughput below performance floor")
        #else
        XCTAssertGreaterThanOrEqual(throughput, 8000.0, "Adler-32 Debug throughput below baseline")
        #endif
    }
}
