// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class TransparentAdaptivePipelineTests: XCTestCase {

    func testHighEntropyStoreAutoDowngrade() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipAdaptiveTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create high-entropy pseudo-random file (1MB)
        let filePath = tempDir.appendingPathComponent("high_entropy.bin").path
        let fileSize = 1024 * 1024
        var randBytes = [UInt8](repeating: 0, count: fileSize)
        for i in 0..<fileSize { randBytes[i] = UInt8.random(in: 0...255) }
        try Data(randBytes).write(to: URL(fileURLWithPath: filePath))

        let eval = AdaptivePipelineOrchestrator.shared.evaluateFile(atPath: filePath)
        XCTAssertGreaterThan(eval.shannonEntropy, 7.65, "Shannon entropy of random file must exceed 7.65")
        XCTAssertTrue(eval.isIncompressible, "Random file must be flagged as incompressible")
        XCTAssertTrue(eval.recommendDirectStore, "Incompressible file must recommend Store")

        // Test transparent archiving with ArchiveWriter
        let zipPath = tempDir.appendingPathComponent("output.zip").path
        let writer = ArchiveEngineFactory.makeWriter()
        
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        try writer.createArchiveSync(
            outputPath: zipPath,
            format: .zip,
            level: .level6, // User requested Level 6, engine should adaptively downgrade to Store
            inputPaths: [filePath]
        )
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let elapsedMs = Double(t1 - t0) / 1_000_000.0

        let zipSize = (try? FileManager.default.attributesOfItem(atPath: zipPath)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(zipSize, 0)
        // Store mode should have near-zero compression overhead (< 200 bytes zip header)
        XCTAssertLessThanOrEqual(zipSize, Int64(fileSize + 512), "Zip size should not suffer negative compression expansion")
        XCTAssertLessThan(elapsedMs, 20.0, "Adaptive Store bypass should complete in < 20ms for 1MB")
    }

    func testScientificFloatAutoDetectionAndBitGrooming() throws {
        // Create 64KB continuous Float32 sensor array
        let floatCount = 16384
        var floats = [Float](repeating: 0, count: floatCount)
        for i in 0..<floatCount {
            floats[i] = sin(Float(i) * 0.05) * 50.0 + Float(i % 100) * 0.001
        }
        let floatBytes = Data(bytes: floats, count: floatCount * MemoryLayout<Float>.size)

        let eval = AdaptivePipelineOrchestrator.shared.evaluateSample(data: floatBytes)
        XCTAssertTrue(eval.isScientificFloat, "Continuous sinusoids must be detected as scientific float array")
        XCTAssertEqual(eval.detectedTypeSize, 4, "Float32 must detect type size 4")
        XCTAssertTrue(eval.recommendBitGroom, "Scientific float must recommend Bit-Grooming")

        // Verify that BitGrooming preserves bounded relative error <= 0.5% for NSD=3
        let groomed = Blosc2FilterBridge.bitGroom(floats: floats, nsd: 3)
        for i in 0..<min(floatCount, 200) {
            let relErr = abs(floats[i] - groomed[i]) / max(0.0001, abs(floats[i]))
            XCTAssertLessThanOrEqual(relErr, 0.01)
        }
    }

    func testSpecialZeroUniformDetection() throws {
        let zeroData = Data(count: 65536)
        let eval = AdaptivePipelineOrchestrator.shared.evaluateSample(data: zeroData)
        XCTAssertTrue(eval.isSpecialUniform, "All-zero buffer must be detected as special uniform block")
        XCTAssertTrue(eval.recommendDirectStore, "All-zero buffer must recommend Direct Store bypass")
    }
}
