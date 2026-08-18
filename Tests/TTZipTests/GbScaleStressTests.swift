// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// Test suite validating gigabyte-scale streaming compression and decompression stress benchmarks.
final class GbScaleStressTests: XCTestCase {
    
    /// Benchmarks 1.0 GB large-scale streaming compression and decompression when TTZIP_BENCH_TIER=STRESS is set.
    func testOneGigabyteStreamingCompressionAndDecompression() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_BENCH_TIER"] == "STRESS" else {
            throw XCTSkip("Large-scale 1GB stress test requires TTZIP_BENCH_TIER=STRESS environment variable; skipped during normal swift test runs.")
        }
        
        let sandbox = try IsolatedTempSandbox(prefix: "gb_benchmark")
        defer { sandbox.cleanup() }
        
        let oneGbFilePath = sandbox.fileURL(named: "payload_1GB.bin").path
        let fileManager = FileManager.default
        
        fileManager.createFile(atPath: oneGbFilePath, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: oneGbFilePath))
        defer { try? fileHandle.close() }
        
        let chunkMB = 50
        let chunkBytes = chunkMB * 1024 * 1024
        
        let patternString = "{\"id\": 1024, \"title\": \"TTZipEnterpriseTestPayload2026\", \"code\": \"func process() { print(\\\"TTZip\\\") }\"}\n"
        let patternBytes = Array(patternString.utf8)
        var chunkData = Data(count: chunkBytes)
        chunkData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var seed: UInt64 = 0x123456789ABCDEF0
            for i in 0..<chunkBytes {
                if i % 2 == 0 {
                    base[i] = patternBytes[i % patternBytes.count]
                } else {
                    seed ^= (seed << 13)
                    seed ^= (seed >> 7)
                    seed ^= (seed << 17)
                    base[i] = UInt8(truncatingIfNeeded: seed & 0xFF)
                }
            }
        }
        
        for _ in 0..<20 { // 20 * 50MB = 1000MB ≈ 1GB
            fileHandle.write(chunkData)
        }
        
        let attr = try fileManager.attributesOfItem(atPath: oneGbFilePath)
        let actualFileSizeBytes = attr[.size] as? Int64 ?? 0
        let actualGB = Double(actualFileSizeBytes) / (1024 * 1024 * 1024)
        let actualMB = Double(actualFileSizeBytes) / (1024 * 1024)
        
        let outArchive = sandbox.fileURL(named: "archive_1GB.tar.zst").path
        let writer = ArchiveWriter()
        
        let compressStart = Date()
        try await writer.createArchive(outputPath: outArchive, format: .tarZst, level: .normal, inputPaths: [oneGbFilePath])
        let compressDuration = max(0.001, Date().timeIntervalSince(compressStart))
        let compressSpeedMBps = actualMB / compressDuration
        
        let archiveAttr = try fileManager.attributesOfItem(atPath: outArchive)
        let compressedSizeBytes = Double(archiveAttr[.size] as? Int64 ?? 0)
        let ratioPercent = (1.0 - (compressedSizeBytes / Double(actualFileSizeBytes))) * 100.0
        
        let extractDest = sandbox.fileURL(named: "extracted_1GB").path
        let extractor = ArchiveExtractor()
        
        let decompressStart = Date()
        try await extractor.extract(archivePath: outArchive, destinationDir: extractDest)
        let decompressDuration = max(0.001, Date().timeIntervalSince(decompressStart))
        let decompressSpeedMBps = actualMB / decompressDuration
        
        TTLogger.info("\n==================================================")
        TTLogger.info("📊 TTZip 1.0 GB Large-Scale Performance Benchmark:")
        TTLogger.info("--------------------------------------------------")
        TTLogger.info(String(format: "Original File Size   : %.2f GB (%.2f MB)", actualGB, actualMB))
        TTLogger.info(String(format: "Archive File Size    : %.2f MB", compressedSizeBytes / (1024 * 1024)))
        TTLogger.info(String(format: "Compression Ratio    : %.2f%%", ratioPercent))
        TTLogger.info(String(format: "1GB Compress Speed   : %.2f MB/s (Duration: %.3f s)", compressSpeedMBps, compressDuration))
        TTLogger.info(String(format: "1GB Decompress Speed : %.2f MB/s (Duration: %.3f s)", decompressSpeedMBps, decompressDuration))
        TTLogger.info("==================================================\n")
        
        XCTAssertGreaterThan(compressSpeedMBps, 50.0, "1GB Compression Throughput must exceed 50 MB/s")
        XCTAssertGreaterThan(decompressSpeedMBps, 100.0, "1GB Decompression Throughput must exceed 100 MB/s")
        XCTAssertTrue(fileManager.fileExists(atPath: outArchive))
    }
}
