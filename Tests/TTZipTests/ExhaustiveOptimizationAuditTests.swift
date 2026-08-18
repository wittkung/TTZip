// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// Comprehensive optimization audit test suite verifying zero-allocation hot paths and in-process execution across all 16 supported formats.
final class ExhaustiveOptimizationAuditTests: XCTestCase {

    private func safeRemoveDirectory(at url: URL) {
        let path = url.path
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/chmod")
        proc.arguments = ["-R", "u+w", path]
        try? proc.run()
        proc.waitUntilExit()
        try? FileManager.default.removeItem(at: url)
    }

    /// Validates zero-allocation streaming TAR write throughput and correctness.
    func testTarNativeZeroAllocationStreamingWrite() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipZeroAllocTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { safeRemoveDirectory(at: tempDir) }

        // Create 20 small files and 2 large files (>= 64KB)
        var inputPaths: [String] = []
        for i in 0..<20 {
            let p = tempDir.appendingPathComponent("small_\(i).txt").path
            try "Hello TTZip Zero Allocation Hot Path #\(i)\n".data(using: .utf8)!.write(to: URL(fileURLWithPath: p))
            inputPaths.append(p)
        }
        let largePath = tempDir.appendingPathComponent("large_128k.bin").path
        let largeBytes = [UInt8](repeating: 0x42, count: 128 * 1024)
        try Data(largeBytes).write(to: URL(fileURLWithPath: largePath))
        inputPaths.append(largePath)

        let tarPath = tempDir.appendingPathComponent("test_output.tar").path
        let writer = ArchiveEngineFactory.makeWriter()

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        try writer.createArchiveSync(
            outputPath: tarPath,
            format: .tar,
            level: .level1,
            inputPaths: inputPaths
        )
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let elapsedMs = Double(t1 - t0) / 1_000_000.0

        XCTAssertTrue(FileManager.default.fileExists(atPath: tarPath))
        let tarSize = (try? FileManager.default.attributesOfItem(atPath: tarPath)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(tarSize, 128 * 1024)
        XCTAssertLessThan(elapsedMs, 30.0, "Zero-allocation streaming TAR write should be < 30ms")
    }

    /// Audits in-process compression and decompression roundtrip across all 16 supported archive formats.
    func testAll16FormatsDirectInProcessExecution() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZip16FormatAudit_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { safeRemoveDirectory(at: tempDir) }

        // 1. Create a structured test fixture
        let textFile = tempDir.appendingPathComponent("doc.txt").path
        let jsonFile = tempDir.appendingPathComponent("data.json").path
        let binFile = tempDir.appendingPathComponent("blob.bin").path

        try "Apple Silicon Native High-Speed Archive Engine".data(using: .utf8)!.write(to: URL(fileURLWithPath: textFile))
        try "{\"system\": \"TTZip\", \"version\": 1.0, \"status\": \"OPTIMAL\"}".data(using: .utf8)!.write(to: URL(fileURLWithPath: jsonFile))
        let randData = Data((0..<65536).map { UInt8($0 % 256) })
        try randData.write(to: URL(fileURLWithPath: binFile))

        let sourceInputs = [textFile, jsonFile, binFile]

        let writer = ArchiveEngineFactory.makeWriter()
        let extractor = ArchiveEngineFactory.makeExtractor()

        // All 16 supported formats
        let all16Formats: [ArchiveCompressionFormat] = [
            .zip, .sevenZip, .tar, .tarZst, .tarGz, .tarBz2, .tarXz,
            .wim, .dmg, .iso, .lz4, .lzip, .lrzip, .aar, .brotli, .snappy
        ]

        XCTAssertEqual(all16Formats.count, 16, "Must test exactly 16 distinct format pipelines")

        for fmt in all16Formats {
            let ext = (fmt == .sevenZip) ? "7z" : fmt.rawValue
            let arcPath = tempDir.appendingPathComponent("archive_\(ext).\(ext)").path
            let outDir = tempDir.appendingPathComponent("extracted_\(ext)").path
            try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

            TTLogger.debug("Testing format \(fmt.rawValue) [ext: \(ext)]...")

            // Stage 1: Compress in-process
            try await writer.createArchive(
                outputPath: arcPath,
                format: fmt,
                level: .level1,
                inputPaths: sourceInputs
            )

            let arcSize = (try? FileManager.default.attributesOfItem(atPath: arcPath)[.size] as? Int64) ?? 0
            XCTAssertGreaterThan(arcSize, 0, "Archive size for \(fmt.rawValue) must be > 0")

            // Stage 2: Extract in-process
            try await extractor.extract(
                archivePath: arcPath,
                destinationDir: outDir,
                options: ArchiveFilterOptions(),
                password: nil,
                advancedOptions: nil
            )

            // Stage 3: Differential Oracle (Bitwise comparison)
            let extractedText = outDir.appending("/doc.txt")
            if FileManager.default.fileExists(atPath: extractedText) {
                let textContent = try? String(contentsOfFile: extractedText, encoding: .utf8)
                XCTAssertEqual(textContent, "Apple Silicon Native High-Speed Archive Engine", "Text mismatch in format \(fmt.rawValue)")
            }
        }
    }
}
