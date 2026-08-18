// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class StreamingDecompressorDualSymbolLutTests: XCTestCase {

    // MARK: - 1. Multi-Compressor Oracle Equivalence Test

    func testDecompressorOracleEquivalence() throws {
        let dec = ttzip_deflate_decompressor_alloc()
        defer { ttzip_deflate_decompressor_free(dec) }
        XCTAssertNotNil(dec, "Failed to allocate native decompressor")

        let sizes = [64, 512, 4096, 65536, 262144, 1048576]

        for sz in sizes {
            var rawData = Data(count: sz)
            rawData.withUnsafeMutableBytes { ptr in
                let p = ptr.bindMemory(to: UInt8.self).baseAddress!
                for i in 0..<sz {
                    p[i] = UInt8((i * 13 + (i >> 4) * 7) & 0xFF)
                }
            }

            let maxComp = sz + 65536
            var compBuf = [UInt8](repeating: 0, count: maxComp)
            var decompBuf = [UInt8](repeating: 0, count: sz + 4096)

            // Compress with libdeflate Level 6
            let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
                return compBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                    return ttzip_libdeflate_compress(inPtr, sz, rawOut.baseAddress!, maxComp, 6)
                }
            }

            XCTAssertGreaterThan(compSize, 0, "Compression failed for size \(sz)")

            var actualOut: size_t = 0
            let status = compBuf.withUnsafeBytes { rawComp -> Int32 in
                let compPtr = rawComp.bindMemory(to: UInt8.self).baseAddress!
                return decompBuf.withUnsafeMutableBufferPointer { rawDecomp -> Int32 in
                    return ttzip_deflate_decompress(
                        dec, compPtr, compSize, rawDecomp.baseAddress!, sz, &actualOut
                    )
                }
            }

            XCTAssertEqual(status, 0, "Native decompression failed for size \(sz)")
            XCTAssertEqual(actualOut, sz, "Decompressed size mismatch for size \(sz)")
            let decompData = Data(decompBuf.prefix(sz))
            XCTAssertEqual(decompData, rawData, "Decompressed byte mismatch for size \(sz)")
        }
    }

    // MARK: - 2. Single-Core Decompression Throughput Floor Benchmark

    func testDecompressionThroughputFloor() throws {
        let dec = ttzip_deflate_decompressor_alloc()
        defer { ttzip_deflate_decompressor_free(dec) }

        let payloadSize = 10 * 1024 * 1024 // 10 MB payload
        var rawData = Data(count: payloadSize)
        rawData.withUnsafeMutableBytes { ptr in
            let p = ptr.bindMemory(to: UInt8.self).baseAddress!
            for i in 0..<payloadSize {
                p[i] = UInt8(((i % 17) * 9 + (i >> 8) * 3) & 0xFF)
            }
        }

        let maxComp = payloadSize + 65536
        var compBuf = [UInt8](repeating: 0, count: maxComp)
        var decompBuf = [UInt8](repeating: 0, count: payloadSize)

        let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
            let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
            return compBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                return ttzip_libdeflate_compress(inPtr, payloadSize, rawOut.baseAddress!, maxComp, 1)
            }
        }

        XCTAssertGreaterThan(compSize, 0)

        // Warm up
        var actualOut: size_t = 0
        _ = compBuf.withUnsafeBytes { rawComp in
            decompBuf.withUnsafeMutableBufferPointer { rawDecomp in
                ttzip_deflate_decompress(
                    dec, rawComp.baseAddress!, compSize, rawDecomp.baseAddress!, payloadSize, &actualOut
                )
            }
        }

        let iterations = 10
        let t0 = DispatchTime.now()

        for _ in 0..<iterations {
            _ = compBuf.withUnsafeBytes { rawComp in
                decompBuf.withUnsafeMutableBufferPointer { rawDecomp in
                    ttzip_deflate_decompress(
                        dec, rawComp.baseAddress!, compSize, rawDecomp.baseAddress!, payloadSize, &actualOut
                    )
                }
            }
        }

        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000_000.0
        let totalMB = (Double(payloadSize) * Double(iterations)) / (1024.0 * 1024.0)
        let throughputMBs = totalMB / elapsedSec

        print(String(format: "[BENCH] Single-Core Deflate Decompression: %.1f MB/s", throughputMBs))
        XCTAssertGreaterThanOrEqual(throughputMBs, 7500.0, "Decompression throughput fell below 7500 MB/s floor")
    }
}
