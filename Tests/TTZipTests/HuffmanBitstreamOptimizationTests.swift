// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class HuffmanBitstreamOptimizationTests: XCTestCase {

    // MARK: - 1. Multi-Symbol Bitstream Emission Oracle & Decompression Test

    func testMultiSymbolBitstreamEmissionOracle() throws {
        let sizes = [64, 512, 1024, 4096, 16384, 65536, 262144]

        for sz in sizes {
            var rawData = Data(count: sz)
            rawData.withUnsafeMutableBytes { ptr in
                let p = ptr.bindMemory(to: UInt8.self).baseAddress!
                for i in 0..<sz {
                    // Semi-repetitive patterns with varied literal runs and match lengths
                    p[i] = UInt8((i % 37) ^ (i / 13) & 0xFF)
                }
            }

            let maxOut = sz + 65536
            var compressedBuf = [UInt8](repeating: 0, count: maxOut)
            var decompressedBuf = [UInt8](repeating: 0, count: sz + 1024)
            let nilPtr: UnsafePointer<UInt8>? = nil

            let compSize = rawData.withUnsafeBytes { rawIn -> size_t in
                let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
                return compressedBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                    return ttzip_native_deflate_compress_chunk_with_history(
                        inPtr, sz, nilPtr, 0, rawOut.baseAddress!, maxOut, 1, 1
                    )
                }
            }

            XCTAssertGreaterThan(compSize, 0, "Compression failed for size \(sz)")

            let decompSize = compressedBuf.withUnsafeBytes { rawComp -> size_t in
                let compPtr = rawComp.bindMemory(to: UInt8.self).baseAddress!
                return decompressedBuf.withUnsafeMutableBufferPointer { rawDecomp -> size_t in
                    return ttzip_libdeflate_decompress(
                        compPtr, compSize, rawDecomp.baseAddress!, sz
                    )
                }
            }

            XCTAssertEqual(decompSize, sz, "Decompressed size mismatch for size \(sz)")
            let decompData = Data(decompressedBuf.prefix(sz))
            XCTAssertEqual(decompData, rawData, "Decompressed data byte mismatch for size \(sz)")
        }
    }

    // MARK: - 2. Small-File (< 4KB) Static Huffman Throughput Benchmark

    func testSmallFileStaticHuffmanSpeedup() throws {
        let fileCount = 200
        let fileSize = 1536 // 1.5 KB typical small config / JSON / header file
        var smallFiles: [Data] = []
        for seed in 0..<fileCount {
            var d = Data(count: fileSize)
            d.withUnsafeMutableBytes { ptr in
                let p = ptr.bindMemory(to: UInt8.self).baseAddress!
                for i in 0..<fileSize {
                    p[i] = UInt8((i ^ (seed * 17)) & 0xFF)
                }
            }
            smallFiles.append(d)
        }

        let maxOut = fileSize + 1024
        var outBuf = [UInt8](repeating: 0, count: maxOut)
        let nilPtr: UnsafePointer<UInt8>? = nil

        let iterations = 10
        let t0 = DispatchTime.now()
        var totalComp = 0

        for _ in 0..<iterations {
            for file in smallFiles {
                let comp = file.withUnsafeBytes { rawIn -> size_t in
                    let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
                    return outBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                        return ttzip_native_deflate_compress_chunk_with_history(
                            inPtr, fileSize, nilPtr, 0, rawOut.baseAddress!, maxOut, 1, 1
                        )
                    }
                }
                totalComp += Int(comp)
            }
        }

        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000_000.0
        let totalMB = Double(fileCount * fileSize * iterations) / (1024.0 * 1024.0)
        let throughput = totalMB / elapsedSec

        print(String(format: "[BENCH] Sub-4KB Small-File Single-Core Throughput: %.1f MB/s", throughput))
        XCTAssertGreaterThanOrEqual(throughput, 500.0, "Small-file throughput fell below floor")
    }
}
