// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Compression
@testable import TTZipCore

final class FastContainerStreamTests: XCTestCase {

    func testGzipContainer_RoundTrip_AndAppleGzipConsensus() {
        let sampleSize = 64 * 1024 // 64KB
        var sampleBytes = [UInt8](repeating: 0, count: sampleSize)
        for i in 0..<sampleSize {
            sampleBytes[i] = UInt8((i * 33 + 7) & 0xFF)
        }
        let originalData = Data(sampleBytes)

        // 1. Compress via FastContainerEngine
        guard let gzipData = FastContainerEngine.compressGzip(originalData, level: 6) else {
            XCTFail("GZIP fast compression failed")
            return
        }

        // Verify RFC 1952 Header
        XCTAssertGreaterThanOrEqual(gzipData.count, 18)
        XCTAssertEqual(gzipData[0], 0x1F)
        XCTAssertEqual(gzipData[1], 0x8B)
        XCTAssertEqual(gzipData[2], 0x08)

        // 2. Decompress via FastContainerEngine
        guard let decompressed = FastContainerEngine.decompressGzip(gzipData, expectedSize: sampleSize) else {
            XCTFail("GZIP fast decompression failed")
            return
        }

        XCTAssertEqual(decompressed.count, originalData.count)
        XCTAssertEqual(decompressed, originalData, "Decompressed GZIP data must match original bit-for-bit")

        // 3. Apple libcompression consensus on the Deflate payload (skip 10-byte header, exclude 8-byte trailer)
        let deflatePayload = gzipData.subdata(in: 10..<(gzipData.count - 8))
        var appleDecBuffer = [UInt8](repeating: 0, count: sampleSize)
        let appleDecompressedBytes = deflatePayload.withUnsafeBytes { srcRaw in
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

        XCTAssertEqual(appleDecompressedBytes, sampleSize, "Apple libcompression must decode the raw Deflate payload from GZIP")
        XCTAssertEqual(Data(appleDecBuffer), originalData, "Apple decompression must be 100% identical")
    }

    func testZlibContainer_RoundTrip_AndAppleZlibConsensus() {
        let sampleSize = 64 * 1024 // 64KB
        var sampleBytes = [UInt8](repeating: 0, count: sampleSize)
        for i in 0..<sampleSize {
            sampleBytes[i] = UInt8((i * 47 + 19) & 0xFF)
        }
        let originalData = Data(sampleBytes)

        // 1. Compress via FastContainerEngine
        guard let zlibData = FastContainerEngine.compressZlib(originalData, level: 6) else {
            XCTFail("ZLIB fast compression failed")
            return
        }

        // Verify RFC 1950 Header
        XCTAssertGreaterThanOrEqual(zlibData.count, 6)
        let hdr = (UInt16(zlibData[0]) << 8) | UInt16(zlibData[1])
        XCTAssertEqual(hdr % 31, 0, "ZLIB header CMF/FLG must satisfy modulo 31")

        // 2. Decompress via FastContainerEngine
        guard let decompressed = FastContainerEngine.decompressZlib(zlibData, expectedSize: sampleSize) else {
            XCTFail("ZLIB fast decompression failed")
            return
        }

        XCTAssertEqual(decompressed.count, originalData.count)
        XCTAssertEqual(decompressed, originalData, "Decompressed ZLIB data must match original bit-for-bit")

        // 3. Apple libcompression consensus on the Deflate payload (skip 2-byte header, exclude 4-byte trailer)
        let deflatePayload = zlibData.subdata(in: 2..<(zlibData.count - 4))
        var appleDecBuffer = [UInt8](repeating: 0, count: sampleSize)
        let appleDecompressedBytes = deflatePayload.withUnsafeBytes { srcRaw in
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

        XCTAssertEqual(appleDecompressedBytes, sampleSize, "Apple libcompression must decode the raw Deflate payload from ZLIB")
        XCTAssertEqual(Data(appleDecBuffer), originalData, "Apple decompression must be 100% identical")
    }

    func testContainer_ThroughputFloor() {
        let payloadSize = 10 * 1024 * 1024 // 10MB
        var sampleBytes = [UInt8](repeating: 0, count: payloadSize)
        for i in 0..<payloadSize {
            sampleBytes[i] = UInt8((i * 13 + 5) % 251)
        }
        let originalData = Data(sampleBytes)

        let iterations = 3
        let start = PlatformMonotonicTimer.nowNanoseconds()

        for _ in 0..<iterations {
            _ = FastContainerEngine.compressGzip(originalData, level: 1)
        }

        let elapsedNanos = PlatformMonotonicTimer.nowNanoseconds() - start
        let totalMB = Double(payloadSize * iterations) / (1024.0 * 1024.0)
        let elapsedSeconds = Double(elapsedNanos) / 1_000_000_000.0
        let throughputMBs = totalMB / elapsedSeconds

        print("⚡ [Fast GZIP Container] Level 1 Framing Throughput: \(String(format: "%.2f", throughputMBs)) MB/s")

        #if DEBUG
        XCTAssertGreaterThanOrEqual(throughputMBs, 1000.0, "Debug mode throughput floor for GZIP fast framing")
        #else
        XCTAssertGreaterThanOrEqual(throughputMBs, 1800.0, "Release mode throughput floor for GZIP fast framing")
        #endif
    }
}
