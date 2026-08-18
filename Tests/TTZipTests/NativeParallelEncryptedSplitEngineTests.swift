// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CryptoKit
@testable import TTZipCore

final class NativeParallelEncryptedSplitEngineTests: XCTestCase {
    
    func testNativeParallelEncryptedSplitEnginePerformance() async throws {
        let tempDir = NSTemporaryDirectory()
        let payloadPath = (tempDir as NSString).appendingPathComponent("parallel_test_500mb.bin")
        let outputDir = (tempDir as NSString).appendingPathComponent("parallel_out_\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(atPath: payloadPath)
            try? FileManager.default.removeItem(atPath: outputDir)
        }
        
        // 500MB
        let chunkSize = 50 * 1024 * 1024
        let dummyChunk = Data(repeating: 0xAB, count: chunkSize)
        FileManager.default.createFile(atPath: payloadPath, contents: nil)
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: payloadPath))
        for _ in 0..<10 { // 500MB
            try handle.write(contentsOf: dummyChunk)
        }
        try handle.close()
        
        let engine = NativeParallelEncryptedSplitEngine()
        let password = "TTZipStandardParallelEncryptedPassword2026"
        
        let start = Date()
        let files = try await engine.createStandardEncryptedSplitVolume(
            format: .sevenZip,
            sourcePaths: [payloadPath],
            outputDir: outputDir,
            baseName: "archive_500m",
            splitVolumeSizeBytes: 100 * 1024 * 1024,
            password: password
        )
        let elapsed = Date().timeIntervalSince(start)
        
        let speedMBs = 500.0 / elapsed
        TTLogger.info(String(format: "🚀 [Native Parallel Standard 7z Split] 500MB 分卷加密吞吐量: %.2f MB/s (耗时: %.4f 秒, 生成分卷: %d 个)", speedMBs, elapsed, files.count))
        
        XCTAssertGreaterThan(files.count, 0, "应生成标准加密分卷文件")
        XCTAssertGreaterThan(speedMBs, 100.0, "原生 18 核并行硬件 AES 加密分卷吞吐量应满足极速标准")
    }
}
