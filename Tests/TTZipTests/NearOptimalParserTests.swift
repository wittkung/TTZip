// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Compression
@testable import TTZipCore

final class NearOptimalParserTests: XCTestCase {

    func testNearOptimal_SilesiaCorpus_CompressionGain() {
        // Generate realistic structured text corpus (64KB)
        var sourceText = ""
        for i in 0..<1500 {
            sourceText += "2026-08-18 23:55:00.123 [INFO] [Worker-\(i % 16)] Request processing completed for user_\(i * 37 % 1000) with status: 200 OK, latency: \(i % 45)ms, thread_pool_active: true\n"
        }
        let originalData = Data(sourceText.utf8)
        XCTAssertGreaterThan(originalData.count, 50 * 1024)

        // 1. Level 6 Standard Deflate
        guard let l6Compressed = LibdeflateCAdapter.shared.compressData(originalData, level: 6) else {
            XCTFail("Level 6 compression must succeed")
            return
        }

        // 2. Level 12 Near-Optimal Dynamic Programming Deflate
        guard let l12Compressed = LibdeflateCAdapter.shared.compressData(originalData, level: 12) else {
            XCTFail("Level 12 Near-Optimal compression must succeed")
            return
        }

        let l6Size = l6Compressed.count
        let l12Size = l12Compressed.count
        let gainPercent = Double(l6Size - l12Size) / Double(l6Size) * 100.0

        // Space saving calculated and asserted
        XCTAssertLessThanOrEqual(l12Size, l6Size, "Near-Optimal Level 12 must be smaller than or equal to Level 6")
        XCTAssertGreaterThanOrEqual(gainPercent, 1.5, "Near-Optimal parser should achieve measurable size reduction on text")
    }

    func testNearOptimal_RFC1951_DecompressionConsensus() {
        let sampleSize = 128 * 1024 // 128KB
        var sampleBytes = [UInt8](repeating: 0, count: sampleSize)
        for i in 0..<sampleSize {
            sampleBytes[i] = UInt8((i ^ (i >> 3) ^ (i >> 7)) & 0xFF)
        }
        let originalData = Data(sampleBytes)

        // Compress with Near-Optimal Level 12
        guard let compressed = LibdeflateCAdapter.shared.compressData(originalData, level: 12) else {
            XCTFail("Near-optimal compression failed")
            return
        }

        // Decompress with LibdeflateCAdapter
        guard let decompressed = LibdeflateCAdapter.shared.decompressData(compressed, originalSize: originalData.count) else {
            XCTFail("Decompression failed")
            return
        }

        XCTAssertEqual(decompressed.count, originalData.count)
        XCTAssertEqual(decompressed, originalData, "Decompressed payload must match original bit-for-bit")

        // Decompress with Apple libcompression (COMPRESSION_ZLIB / RAW DEFLATE)
        var appleDecBuffer = [UInt8](repeating: 0, count: sampleSize)
        let appleDecompressedBytes = compressed.withUnsafeBytes { srcRaw in
            appleDecBuffer.withUnsafeMutableBufferPointer { dstRaw in
                compression_decode_buffer(
                    dstRaw.baseAddress!,
                    dstRaw.count,
                    srcRaw.bindMemory(to: UInt8.self).baseAddress!,
                    srcRaw.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        XCTAssertEqual(appleDecompressedBytes, sampleSize, "Apple libcompression must successfully decode Near-Optimal stream")
        XCTAssertEqual(Data(appleDecBuffer), originalData, "Apple decompression must be 100% identical")
    }

    func testNearOptimal_ThroughputFloor() {
        let payloadSize = 1024 * 1024 // 1MB
        var sampleBytes = [UInt8](repeating: 0, count: payloadSize)
        for i in 0..<payloadSize {
            sampleBytes[i] = UInt8((i * 17 + 31) % 251)
        }
        let originalData = Data(sampleBytes)

        let iterations = 5
        let start = PlatformMonotonicTimer.nowNanoseconds()

        for _ in 0..<iterations {
            _ = LibdeflateCAdapter.shared.compressData(originalData, level: 11)
        }

        let elapsedNanos = PlatformMonotonicTimer.nowNanoseconds() - start
        let totalMB = Double(payloadSize * iterations) / (1024.0 * 1024.0)
        let elapsedSeconds = Double(elapsedNanos) / 1_000_000_000.0
        let throughputMBs = totalMB / elapsedSeconds
        _ = throughputMBs

        #if DEBUG
        XCTAssertGreaterThanOrEqual(throughputMBs, 5.0, "Debug mode throughput floor for Near-Optimal parsing")
        #else
        XCTAssertGreaterThanOrEqual(throughputMBs, 15.0, "Release mode throughput floor for Near-Optimal parsing")
        #endif
    }
}
