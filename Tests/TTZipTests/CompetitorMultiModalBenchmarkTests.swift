// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class CompetitorMultiModalBenchmarkTests: XCTestCase {

    func testMultiModalDatasetBenchmarkIntegration() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipMultiModalBench_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. Generate multi-modal test files
        let floatPath = tempDir.appendingPathComponent("float32_sensor.bin").path
        let highEntropyPath = tempDir.appendingPathComponent("high_entropy.bin").path
        let sparsePath = tempDir.appendingPathComponent("sparse_image.img").path
        let jsonPath = tempDir.appendingPathComponent("structured_log.json").path

        let sensorBytes = TestBenchmarkTier.isBenchmarkMode ? (5 * 1024 * 1024) : (512 * 1024)
        let entropyBytes = TestBenchmarkTier.isBenchmarkMode ? (5 * 1024 * 1024) : (512 * 1024)
        let sparseBytes = TestBenchmarkTier.isBenchmarkMode ? (50 * 1024 * 1024) : (5 * 1024 * 1024)
        let jsonCount = TestBenchmarkTier.isBenchmarkMode ? 15000 : 1000

        try MultiModalDatasetGenerator.generateFloat32SensorDataset(destinationPath: floatPath, sizeBytes: sensorBytes)
        try MultiModalDatasetGenerator.generateHighEntropyBinaryDataset(destinationPath: highEntropyPath, sizeBytes: entropyBytes)
        try MultiModalDatasetGenerator.generateSparseExtentDataset(destinationPath: sparsePath, virtualSizeBytes: Int64(sparseBytes))
        try MultiModalDatasetGenerator.generateStructuredJsonDataset(destinationPath: jsonPath, recordCount: jsonCount)

        XCTAssertTrue(FileManager.default.fileExists(atPath: floatPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: highEntropyPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sparsePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonPath))

        // 2. Test round-trip compression and verification with ArchiveWriter
        let writer = ArchiveEngineFactory.makeWriter()
        let extractor = ArchiveEngineFactory.makeExtractor()

        let formats: [ArchiveCompressionFormat] = [.zip, .sevenZip, .zst, .tar]

        for fmt in formats {
            let arcPath = tempDir.appendingPathComponent("bench_archive.\(fmt.rawValue)").path
            let outDir = tempDir.appendingPathComponent("out_\(fmt.rawValue)").path
            try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

            // Compress
            try await writer.createArchive(
                outputPath: arcPath,
                format: fmt,
                level: .level1,
                inputPaths: [floatPath, highEntropyPath, jsonPath]
            )

            let arcSize = (try? FileManager.default.attributesOfItem(atPath: arcPath)[.size] as? Int64) ?? 0
            XCTAssertGreaterThan(arcSize, 0, "\(fmt.rawValue) archive size must be greater than 0")

            // Extract
            try await extractor.extract(
                archivePath: arcPath,
                destinationDir: outDir,
                options: ArchiveFilterOptions(),
                password: nil,
                advancedOptions: nil
            )

            // Verify extracted file existence
            let extractedFloat = outDir.appending("/float32_sensor.bin")
            let extractedEntropy = outDir.appending("/high_entropy.bin")
            let extractedJson = outDir.appending("/structured_log.json")

            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFloat), "Extracted float32 file must exist for \(fmt.rawValue)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedEntropy), "Extracted high entropy file must exist for \(fmt.rawValue)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedJson), "Extracted JSON file must exist for \(fmt.rawValue)")
        }
    }
}
