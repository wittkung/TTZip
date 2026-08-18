// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// Test suite validating entropy-adaptive extreme routing between Deflate compression and Direct Store pipelines.
final class EntropyAdaptiveExtremeRoutingTests: XCTestCase {
    
    /// Validates that repetitive low-entropy text payloads are intelligently routed to Deflate (Method 8).
    func testEntropyProbeLowEntropy() throws {
        // Highly repetitive low-entropy text
        let text = String(repeating: "<xml><tag id=\"item_12345\">Hello World Dynamic Compress</tag></xml>\n", count: 100)
        let data = text.data(using: .utf8)!
        
        var entropy: Double = 0.0
        var ratio: Double = 1.0
        let method = data.withUnsafeBytes { ptr -> Int32 in
            ttzip_probe_entropy_and_compressibility(ptr.baseAddress!, data.count, 4096, &entropy, &ratio)
        }
        
        TTLogger.debug("📊 Low-entropy test: Entropy = \(String(format: "%.3f", entropy)) bits/byte, Method = \(method), Ratio = \(ratio)")
        XCTAssertEqual(method, 8, "Low-entropy data must route to Deflate (Method 8)")
        XCTAssertLessThan(entropy, 6.0, "Repetitive XML text entropy must be < 6.0 bits/byte")
    }
    
    /// Validates that random high-entropy noise payloads are intelligently routed to Direct Store (Method 0).
    func testEntropyProbeHighEntropy() throws {
        // High-entropy random noise / pseudo-incompressible data
        var randomBytes = [UInt8](repeating: 0, count: 65536)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let data = Data(randomBytes)
        
        var entropy: Double = 0.0
        var ratio: Double = 1.0
        let method = data.withUnsafeBytes { ptr -> Int32 in
            ttzip_probe_entropy_and_compressibility(ptr.baseAddress!, data.count, 4096, &entropy, &ratio)
        }
        
        TTLogger.debug("📊 High-entropy test: Entropy = \(String(format: "%.3f", entropy)) bits/byte, Method = \(method), Ratio = \(ratio)")
        XCTAssertEqual(method, 0, "High-entropy random data must route to Direct Store (Method 0)")
        XCTAssertGreaterThanOrEqual(entropy, 7.5, "Random noise entropy must be >= 7.5 bits/byte")
    }
    
    /// Validates end-to-end archive creation and system unzip verification for low-entropy payloads.
    func testExtremeBlockWriterLowEntropyPipeline() async throws {
        let tempDir = NSTemporaryDirectory() + "entropy_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let textFile = (tempDir as NSString).appendingPathComponent("large_text.xml")
        let text = String(repeating: "<article id=\"wiki_001\"><title>Swift 6.0 Concurrency</title><content>High performance native engine</content></article>\n", count: 30000)
        try text.data(using: .utf8)!.write(to: URL(fileURLWithPath: textFile))
        
        let outZip = (tempDir as NSString).appendingPathComponent("low_entropy_out.zip")
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZip,
            inputPath: textFile,
            level: .fastest,
            blockSize: 512 * 1024
        )
        XCTAssertTrue(success)
        
        // Verify file size and system native unzip decompression
        let originalSize = try FileManager.default.attributesOfItem(atPath: textFile)[.size] as! Int64
        let zipSize = try FileManager.default.attributesOfItem(atPath: outZip)[.size] as! Int64
        XCTAssertLessThan(zipSize, originalSize / 5, "Low-entropy data under fastest mode must achieve >5x compression ratio")
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-t", outZip]
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "System unzip must verify archive integrity with status 0")
    }
    
    /// Validates end-to-end archive creation and system unzip verification for high-entropy payloads in Direct Store mode.
    func testExtremeBlockWriterHighEntropyStorePipeline() async throws {
        let tempDir = NSTemporaryDirectory() + "entropy_test_high_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let randomFile = (tempDir as NSString).appendingPathComponent("random_payload.bin")
        var randomBytes = [UInt8](repeating: 0, count: 5 * 1024 * 1024) // 5MB
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        try Data(randomBytes).write(to: URL(fileURLWithPath: randomFile))
        
        let outZip = (tempDir as NSString).appendingPathComponent("high_entropy_out.zip")
        
        let start = mach_absolute_time()
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZip,
            inputPath: randomFile,
            level: .fastest,
            blockSize: 512 * 1024
        )
        let elapsed = Double(mach_absolute_time() - start) * 1e-9
        XCTAssertTrue(success)
        
        let speedMBs = 5.0 / max(0.0001, elapsed)
        TTLogger.debug("⚡️ High-entropy Direct Store throughput: \(String(format: "%.1f", speedMBs)) MB/s")
        
        // Verify system native decompression
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-t", outZip]
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "High-entropy Store mode must pass system unzip integrity check with status 0")
    }
}
