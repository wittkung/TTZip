// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class ArchiveEntropyEvaluatorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_entropy_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
        try super.tearDownWithError()
    }

    /// 1. ( / / )
    func testLowEntropyDataNotBypassed() throws {
        let textPayload = String(repeating: "TTZip High-Performance Engine 2026 Structured Log Entry with Redundancy\n", count: 20000)
        let data = textPayload.data(using: .utf8)!
        
        let entropy = ArchiveEntropyEvaluator.estimateEntropyDynamic(
            buffer: (data as NSData).bytes,
            count: data.count
        )
        
        XCTAssertLessThan(entropy, 6.0, "文本与结构化数据 Shannon 熵应 < 6.0")
        XCTAssertFalse(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "低熵可压缩数据绝对不应跳过压缩"
        )
    }

    /// 2. ( / )
    func testHighEntropyDataBypassed() throws {
        var randomBytes = [UInt8](repeating: 0, count: 2 * 1024 * 1024)
        for i in 0..<randomBytes.count {
            randomBytes[i] = UInt8.random(in: 0...255)
        }
        let data = Data(randomBytes)
        
        let entropy = ArchiveEntropyEvaluator.estimateEntropyDynamic(
            buffer: (data as NSData).bytes,
            count: data.count
        )
        
        XCTAssertGreaterThan(entropy, 7.90, "真随机数与密文 Shannon 熵应 > 7.90")
        XCTAssertTrue(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "高熵不可压缩数据应触发 Store 直通旁路"
        )
    }

    /// 3. Tests strided entropy sampling across file regions
    func testFileEntropyStridedSampling() throws {
        let testFile = tempDir.appendingPathComponent("strided_sample.bin")
        
        // 2MB test payload: 16KB low entropy header + 1.98MB high entropy body
        let totalSize = 2 * 1024 * 1024
        let headerZeroSize = 16 * 1024
        var buffer = [UInt8](repeating: 0, count: totalSize)
        var prng = DeterministicPRNG(seed: 0x1337_DEAD_BEEF)
        for i in headerZeroSize..<totalSize {
            buffer[i] = UInt8(truncatingIfNeeded: prng.next())
        }
        
        try Data(buffer).write(to: testFile)
        
        let dynamicEntropy = ArchiveEntropyEvaluator.estimateFileEntropyDynamic(filePath: testFile.path)
        XCTAssertGreaterThan(
            dynamicEntropy,
            7.0,
            "Multi-point strided sampling must cross low entropy header and detect subsequent high entropy payload"
        )
    }

    /// Validates expected behavior and invariants.
    func testSmartStoreBypassUserToggle() throws {
        var randomBytes = [UInt8](repeating: 0, count: 2 * 1024 * 1024)
        for i in 0..<randomBytes.count { randomBytes[i] = UInt8.random(in: 0...255) }
        let data = Data(randomBytes)
        
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = false
        XCTAssertFalse(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "当用户关闭智能直通时，即使极高熵数据也应强制压缩"
        )
        
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
        XCTAssertTrue(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "当用户开启智能直通时，极高熵数据应自动直通"
        )
    }
}
