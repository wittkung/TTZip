// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class EntropyTieredChunkingEngineTests: XCTestCase {
    
    func testTieredChunkingDecisionFunction() {
        let fileSize: size_t = 100 * 1024 * 1024 // 100MB
        
        // Tier 1: Low entropy (H = 2.1) -> 2048 KB
        let b1 = ttzip_calculate_adaptive_block_size(2.1, fileSize)
        XCTAssertEqual(b1, 2 * 1024 * 1024, "低熵数据必须采用 2048 KB 大分块")
        
        // Tier 2: Medium entropy (H = 4.8) -> 512 KB
        let b2 = ttzip_calculate_adaptive_block_size(4.8, fileSize)
        XCTAssertEqual(b2, 512 * 1024, "中熵数据必须采用 512 KB L2 平衡分块")
        
        // Tier 3: Medium-High entropy (H = 6.8) -> 128 KB
        let b3 = ttzip_calculate_adaptive_block_size(6.8, fileSize)
        XCTAssertEqual(b3, 128 * 1024, "中高熵数据必须采用 128 KB L1 私有缓存分块")
        
        // Tier 4: High entropy (H = 7.8) -> 0 (Direct Store)
        let b4 = ttzip_calculate_adaptive_block_size(7.8, fileSize)
        XCTAssertEqual(b4, 0, "高熵不可压缩数据必须返回 0 (Direct Store Method 0)")
    }
    
    func testEndToEndTieredExtremeCompression() async throws {
        let tempDir = NSTemporaryDirectory() + "tiered_entropy_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        // 1. 低熵 XML 文件 (20MB)
        let xmlFile = (tempDir as NSString).appendingPathComponent("low_entropy.xml")
        let xmlLine = "<item id=\"12345\"><name>Apple Silicon Engine</name><value>100.0</value></item>\n"
        let xmlData = String(repeating: xmlLine, count: 300000).data(using: .utf8)!
        try xmlData.write(to: URL(fileURLWithPath: xmlFile))
        
        let xmlOutZip = (tempDir as NSString).appendingPathComponent("low_entropy.zip")
        let s1 = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: xmlOutZip,
            inputPath: xmlFile,
            level: .fastest
        )
        XCTAssertTrue(s1)
        
        // 2. 高熵随机文件 (10MB)
        let randFile = (tempDir as NSString).appendingPathComponent("high_entropy.bin")
        var randBytes = [UInt8](repeating: 0, count: 10 * 1024 * 1024)
        _ = SecRandomCopyBytes(kSecRandomDefault, randBytes.count, &randBytes)
        try Data(randBytes).write(to: URL(fileURLWithPath: randFile))
        
        let randOutZip = (tempDir as NSString).appendingPathComponent("high_entropy.zip")
        let s2 = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: randOutZip,
            inputPath: randFile,
            level: .fastest
        )
        XCTAssertTrue(s2)
        
        // 原生 unzip 校验
        for zipPath in [xmlOutZip, randOutZip] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            p.arguments = ["-t", zipPath]
            try p.run()
            p.waitUntilExit()
            XCTAssertEqual(p.terminationStatus, 0, "\(zipPath) 必须 100% 通过系统原生 unzip 检验")
        }
    }
}
