// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class BloscLZNativeEngineTests: XCTestCase {

    func testBloscLZCompressAndDecompressParity() throws {
        // 1. Generate 64KB structured ramp + repeating pattern
        let count = 65536
        var original = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            original[i] = UInt8((i / 4) % 256)
        }

        let maxOut = count + 1024
        var compressed = [UInt8](repeating: 0, count: maxOut)
        var decompressed = [UInt8](repeating: 0, count: count)

        // Compress
        let cBytes = ttzip_blosclz_compress(
            original,
            Int32(count),
            &compressed,
            Int32(maxOut),
            5,
            14
        )

        XCTAssertGreaterThan(cBytes, 0, "BloscLZ compression must succeed")
        XCTAssertLessThan(Int(cBytes), count, "Structured pattern must achieve positive compression")

        // Decompress
        let dBytes = ttzip_blosclz_decompress(
            compressed,
            cBytes,
            &decompressed,
            Int32(count)
        )

        XCTAssertEqual(dBytes, Int32(count), "Decompressed byte count must match original")
        XCTAssertEqual(decompressed, original, "Decompressed payload must match bit-for-bit")
    }

    func testBloscLZShortMatchesAndSmallBuffers() throws {
        let text = "ABCABCABCABC123123123123XYZXYZXYZXYZ"
        let data = Array(text.utf8)
        var compressed = [UInt8](repeating: 0, count: data.count + 64)
        var decompressed = [UInt8](repeating: 0, count: data.count)

        let cBytes = ttzip_blosclz_compress(
            data,
            Int32(data.count),
            &compressed,
            Int32(compressed.count),
            9,
            12
        )

        XCTAssertGreaterThan(cBytes, 0)
        let dBytes = ttzip_blosclz_decompress(
            compressed,
            cBytes,
            &decompressed,
            Int32(decompressed.count)
        )

        XCTAssertEqual(dBytes, Int32(data.count))
        XCTAssertEqual(decompressed, data)
    }

    func testBloscLZThroughputBenchmark() throws {
        let sizeMB = TestBenchmarkTier.isBenchmarkMode ? 10 : 2
        let totalBytes = sizeMB * 1024 * 1024
        var source = [UInt8](repeating: 0, count: totalBytes)
        for i in 0..<totalBytes {
            source[i] = UInt8(i % 128)
        }

        var compressed = [UInt8](repeating: 0, count: totalBytes + 65536)
        var decompressed = [UInt8](repeating: 0, count: totalBytes)

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        let cBytes = ttzip_blosclz_compress(
            source,
            Int32(totalBytes),
            &compressed,
            Int32(compressed.count),
            1,
            14
        )
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let compSec = max(1e-6, Double(t1 - t0) / 1_000_000_000.0)
        let compThroughput = (Double(totalBytes) / 1_048_576.0) / compSec

        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let dBytes = ttzip_blosclz_decompress(
            compressed,
            cBytes,
            &decompressed,
            Int32(totalBytes)
        )
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let decompSec = max(1e-6, Double(t3 - t2) / 1_000_000_000.0)
        let decompThroughput = (Double(totalBytes) / 1_048_576.0) / decompSec

        XCTAssertEqual(dBytes, Int32(totalBytes))
        XCTAssertGreaterThan(compThroughput, 1500.0, "BloscLZ Level 1 compression throughput must exceed 1.5 GB/s")
        XCTAssertGreaterThan(decompThroughput, 4000.0, "BloscLZ decompression throughput must exceed 4.0 GB/s")
    }
}
