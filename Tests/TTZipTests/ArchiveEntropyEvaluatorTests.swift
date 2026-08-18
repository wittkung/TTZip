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

    /// 1. Tests low-entropy structured text data is not bypassed.
    func testLowEntropyDataNotBypassed() throws {
        let textPayload = String(repeating: "TTZip High-Performance Engine 2026 Structured Log Entry with Redundancy\n", count: 20000)
        let data = textPayload.data(using: .utf8)!
        
        let entropy = ArchiveEntropyEvaluator.estimateEntropyDynamic(
            buffer: (data as NSData).bytes,
            count: data.count
        )
        
        XCTAssertLessThan(entropy, 6.0, "Text and structured data Shannon entropy should be < 6.0")
        XCTAssertFalse(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "Low-entropy compressible data must not bypass compression"
        )
    }

    /// 2. Tests high-entropy encrypted/random data is bypassed.
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
        
        XCTAssertGreaterThan(entropy, 7.90, "Random data and ciphertext Shannon entropy should be > 7.90")
        XCTAssertTrue(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "High-entropy incompressible data should trigger store bypass"
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

    /// Validates expected behavior and user toggle invariants.
    func testSmartStoreBypassUserToggle() throws {
        var randomBytes = [UInt8](repeating: 0, count: 2 * 1024 * 1024)
        for i in 0..<randomBytes.count { randomBytes[i] = UInt8.random(in: 0...255) }
        let data = Data(randomBytes)
        
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = false
        XCTAssertFalse(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "When user disables smart bypass, high-entropy data must still be compressed"
        )
        
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
        XCTAssertTrue(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "When user enables smart bypass, high-entropy data should automatically bypass"
        )
    }
}
