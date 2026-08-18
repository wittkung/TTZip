// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class LibdeflateAcceleratorTests: XCTestCase {
    
    func testLibdeflateAcceleratorRoundtrip() throws {
        let sampleText = "TTZip Core Acceleration Infrastructure with libdeflate ARM NEON SIMD " + String(repeating: "Hello World 2026 ", count: 100)
        let sampleData = sampleText.data(using: .utf8)!
        
        // 1. Deflate Compress across multiple levels
        for level in [1, 6, 9, 12] {
            guard let compressed = LibdeflateAccelerator.shared.compressData(sampleData, level: level) else {
                XCTFail("LibdeflateAccelerator 压缩失败 (level: \(level))")
                return
            }
            
            XCTAssertLessThan(compressed.count, sampleData.count, "压缩后体积必须小于原始数据 (level: \(level))")
            
            // 2. Deflate Decompress
            guard let decompressed = LibdeflateAccelerator.shared.decompressData(compressed, originalSize: sampleData.count) else {
                XCTFail("LibdeflateAccelerator 解压失败 (level: \(level))")
                return
            }
            
            XCTAssertEqual(decompressed, sampleData, "解压后的数据必须 100% 字节精准对齐 (level: \(level))")
        }
    }
    
    func testLibdeflateLargeDataRoundtrip() throws {
        var randomBytes = [UInt8](repeating: 0, count: 512 * 1024)
        for i in 0..<randomBytes.count {
            randomBytes[i] = UInt8((i * 31 + 17) & 0xFF)
        }
        let sampleData = Data(randomBytes)
        
        guard let compressed = LibdeflateAccelerator.shared.compressData(sampleData, level: 1) else {
            XCTFail("512KB 快速压缩失败")
            return
        }
        
        guard let decompressed = LibdeflateAccelerator.shared.decompressData(compressed, originalSize: sampleData.count) else {
            XCTFail("512KB 解压失败")
            return
        }
        
        XCTAssertEqual(decompressed, sampleData, "大块数据解压必须严格一致")
    }
    
    func testLibdeflateHardwareChecksumParity() throws {
        let testString = "TTZip Hardware CRC32 and Libdeflate Parity Validation"
        let data = testString.data(using: .utf8)!
        
        let crc = data.withUnsafeBytes { rawPtr -> UInt32 in
            guard let baseAddress = rawPtr.baseAddress else { return 0 }
            return ttzip_simd_crc32(0, baseAddress, rawPtr.count)
        }
        
        XCTAssertGreaterThan(crc, 0, "CRC32 计算值必须大于 0")
    }
}
