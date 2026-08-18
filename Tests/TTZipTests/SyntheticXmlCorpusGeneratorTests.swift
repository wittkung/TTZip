// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CryptoKit
@testable import TTZipCore

final class SyntheticXmlCorpusGeneratorTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SyntheticXmlTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testGenerationThroughputAndSizeAccuracy() throws {
        let targetURL = tempDir.appendingPathComponent("synth_10mb.xml")
        let targetSize: Int64 = 10 * 1024 * 1024 // 10 MB
        
        let config = SyntheticXmlCorpusConfig(
            totalByteCount: targetSize,
            repeatDistanceBytes: 1024 * 1024,
            repeatProbability: 0.7,
            seed: 0xCAFEBABE12345678
        )
        
        let start = CFAbsoluteTimeGetCurrent()
        try SyntheticXmlCorpusGenerator.generate(config: config, to: targetURL)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        let attrs = try PlatformFileSystem.statFile(path: targetURL.path)
        XCTAssertEqual(attrs.size, targetSize, "Generated file size must match target size exactly")
        
        let throughputMBs = Double(targetSize) / (1024 * 1024 * max(0.0001, elapsed))
        XCTAssertGreaterThan(throughputMBs, 500.0, "Generation throughput should exceed 500 MB/s")
    }
    
    func testDeterministicSha256Parity() throws {
        let fileA = tempDir.appendingPathComponent("synth_a.xml")
        let fileB = tempDir.appendingPathComponent("synth_b.xml")
        let size: Int64 = 2 * 1024 * 1024 // 2 MB
        
        let configA = SyntheticXmlCorpusConfig(totalByteCount: size, seed: 0x9988776655443322)
        let configB = SyntheticXmlCorpusConfig(totalByteCount: size, seed: 0x9988776655443322)
        
        try SyntheticXmlCorpusGenerator.generate(config: configA, to: fileA)
        try SyntheticXmlCorpusGenerator.generate(config: configB, to: fileB)
        
        let dataA = try Data(contentsOf: fileA)
        let dataB = try Data(contentsOf: fileB)
        
        let hashA = SHA256.hash(data: dataA).compactMap { String(format: "%02x", $0) }.joined()
        let hashB = SHA256.hash(data: dataB).compactMap { String(format: "%02x", $0) }.joined()
        
        XCTAssertEqual(hashA, hashB, "Identical configurations must produce identical SHA-256 fingerprints")
        XCTAssertTrue(dataA.starts(with: Array("<mediawiki".utf8)), "Must start with mediawiki root XML tag")
    }
}
