// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
import CTTZipBridge

/**
 * @class NativeDeflateEngineTests
 * @brief Test suite validating in-process native Deflate compression routines,
 *        cross-tile dictionary warm-up, dynamic canonical Huffman encoding, and RFC 1951 compatibility.
 */
final class NativeDeflateEngineTests: XCTestCase {

    /**
     * Tests native Deflate encoding on small text buffers and verifies roundtrip decompression.
     */
    func testNativeDeflateSmallBuffer() throws {
        let text = "Hello World! Native Deflate Engine 100% In-House Apple Silicon"
        let data = Data(text.utf8)

        var compressed = Data(count: 1024)
        let outSize = data.withUnsafeBytes { inBuf in
            compressed.withUnsafeMutableBytes { outBuf in
                ttzip_native_deflate_compress_chunk_with_history(
                    inBuf.bindMemory(to: UInt8.self).baseAddress,
                    inBuf.count,
                    nil,
                    0,
                    outBuf.bindMemory(to: UInt8.self).baseAddress,
                    outBuf.count,
                    3,
                    1 // is_final
                )
            }
        }

        XCTAssertGreaterThan(outSize, 0)
        let compSlice = compressed.prefix(outSize)
        let decomp = LibdeflateCAdapter.shared.decompressData(Data(compSlice), originalSize: data.count)
        XCTAssertNotNil(decomp, "Decompression should succeed")
        if let decomp = decomp {
            XCTAssertEqual(decomp, data)
        }
    }

    /**
     * Tests native Deflate match finders on highly repetitive datasets to assert >10x compression.
     */
    func testNativeDeflateRepeatedData() throws {
        let text = String(repeating: "TTZip Native Deflate Fast Greedy Matcher 128KB L1D! ", count: 2000)
        let data = Data(text.utf8)

        var compressed = Data(count: data.count + 1024)
        let outSize = data.withUnsafeBytes { inBuf in
            compressed.withUnsafeMutableBytes { outBuf in
                ttzip_native_deflate_compress_chunk_with_history(
                    inBuf.bindMemory(to: UInt8.self).baseAddress,
                    inBuf.count,
                    nil,
                    0,
                    outBuf.bindMemory(to: UInt8.self).baseAddress,
                    outBuf.count,
                    2, // Fast+
                    1  // is_final
                )
            }
        }

        XCTAssertGreaterThan(outSize, 0)
        let ratio = Double(data.count) / Double(outSize)
        XCTAssertGreaterThan(ratio, 10.0, "Repeated text should compress at least 10x")

        let compSlice = compressed.prefix(outSize)
        let decomp = LibdeflateCAdapter.shared.decompressData(Data(compSlice), originalSize: data.count)
        XCTAssertNotNil(decomp, "Decompression of repeated data must succeed")
        if let decomp = decomp {
            XCTAssertEqual(decomp.count, data.count, "Decompressed size must match")
            XCTAssertEqual(decomp, data)
        }
    }

    /**
     * Tests cross-tile 32KB dictionary warm-up to confirm improved or identical compression efficiency.
     */
    func testNativeDeflateHistoryWarmup() throws {
        let dictText = "The quick brown fox jumps over the lazy dog. "
        let historyData = Data(String(repeating: dictText, count: 50).utf8)
        let chunkData = Data(String(repeating: dictText, count: 10).utf8)

        // 1. Without dictionary warm-up
        var compNoWarmup = Data(count: chunkData.count * 2)
        let szNoWarmup = chunkData.withUnsafeBytes { inBuf in
            compNoWarmup.withUnsafeMutableBytes { outBuf in
                ttzip_native_deflate_compress_chunk_with_history(
                    inBuf.bindMemory(to: UInt8.self).baseAddress,
                    inBuf.count,
                    nil,
                    0,
                    outBuf.bindMemory(to: UInt8.self).baseAddress,
                    outBuf.count,
                    4,
                    1
                )
            }
        }

        // 2. With 32KB dictionary warm-up
        var compWithWarmup = Data(count: chunkData.count * 2)
        let szWithWarmup = chunkData.withUnsafeBytes { inBuf in
            historyData.withUnsafeBytes { histBuf in
                compWithWarmup.withUnsafeMutableBytes { outBuf in
                    ttzip_native_deflate_compress_chunk_with_history(
                        inBuf.bindMemory(to: UInt8.self).baseAddress,
                        inBuf.count,
                        histBuf.bindMemory(to: UInt8.self).baseAddress,
                        histBuf.count,
                        outBuf.bindMemory(to: UInt8.self).baseAddress,
                        outBuf.count,
                        4,
                        1
                    )
                }
            }
        }

        XCTAssertGreaterThan(szNoWarmup, 0)
        XCTAssertGreaterThan(szWithWarmup, 0)
        XCTAssertLessThanOrEqual(szWithWarmup, szNoWarmup, "Dictionary warmup must yield equal or better compression")
    }

    /**
     * Tests multi-tile parallel compression with Z_SYNC_FLUSH boundaries and validates with /usr/bin/unzip -t.
     */
    func testNativeDeflateMultiTileSyncFlushZipArchive() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("sample.txt")
        // 5MB corpus testing 5 concurrent 1MB tiles
        let sampleContent = String(repeating: "Apple Silicon Native Deflate Multi-Tile Parallel Concurrency Stream\n", count: 75000)
        try sampleContent.write(to: sampleFile, atomically: true, encoding: .utf8)

        let zipOut = tempDir.appendingPathComponent("native_test.zip")

        // Compress using Tier 2 (Fast+) profile
        let ok = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: zipOut.path,
            inputPath: sampleFile.path,
            profile: ZipCompressionProfile.fastPlus
        )
        XCTAssertTrue(ok)

        XCTAssertTrue(FileManager.default.fileExists(atPath: zipOut.path))
        let sz = (try? FileManager.default.attributesOfItem(atPath: zipOut.path)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(sz, 0)

        // Validate archive integrity using macOS system /usr/bin/unzip -t
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-t", zipOut.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        p.waitUntilExit()

        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(p.terminationStatus, 0, "System unzip must pass with 0 errors on native Deflate ZIP")
        XCTAssertTrue(out.contains("No errors detected"), "Output must assert No errors detected")
    }

    /**
     * Tests all 4 native Deflate tier levels in loopback compression and decompression.
     */
    func testNativeDeflateAllTiersRoundtrip() throws {
        let sample = "The quick brown fox jumps over the lazy dog! " + String(repeating: "TTZip Native Apple Silicon Deflate Engine 100% In-House! ", count: 50)
        let data = Data(sample.utf8)

        for tier in 1...4 {
            var compressed = Data(count: data.count + 1024)
            let outSize = data.withUnsafeBytes { inBuf in
                compressed.withUnsafeMutableBytes { outBuf in
                    ttzip_native_deflate_compress_chunk_with_history(
                        inBuf.bindMemory(to: UInt8.self).baseAddress,
                        inBuf.count,
                        nil,
                        0,
                        outBuf.bindMemory(to: UInt8.self).baseAddress,
                        outBuf.count,
                        Int32(tier),
                        1
                    )
                }
            }

            XCTAssertGreaterThan(outSize, 0, "Tier \(tier) should compress successfully")
            let compSlice = compressed.prefix(outSize)
            let decomp = LibdeflateCAdapter.shared.decompressData(Data(compSlice), originalSize: data.count)
            XCTAssertNotNil(decomp, "Tier \(tier) decompression should succeed")
            XCTAssertEqual(decomp, data, "Tier \(tier) decompressed data must match original")
        }
    }
}
