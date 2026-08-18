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

final class SingleCoreDecompressPkTests: XCTestCase {

    func testSingleCoreDecompressionThroughput() throws {
        let sampleSize = 10 * 1024 * 1024 // 10 MB
        var inputData = Data(count: sampleSize)
        inputData.withUnsafeMutableBytes { ptr in
            let buf = ptr.bindMemory(to: UInt8.self)
            for i in 0..<sampleSize {
                buf[i] = UInt8(65 + (i % 26))
            }
        }

        // Compress first
        guard let comp = ttzip_deflate_compressor_alloc(1) else {
            XCTFail("Failed to allocate compressor")
            return
        }
        defer { ttzip_deflate_compressor_free(comp) }

        var compressedData = Data(count: sampleSize + 65536)
        var compressedSize: size_t = 0
        inputData.withUnsafeBytes { inPtr in
            compressedData.withUnsafeMutableBytes { outPtr in
                compressedSize = ttzip_deflate_compress(
                    comp, inPtr.baseAddress!, sampleSize, outPtr.baseAddress!, outPtr.count
                )
            }
        }
        XCTAssertGreaterThan(compressedSize, 0)

        guard let decomp = ttzip_deflate_decompressor_alloc() else {
            XCTFail("Failed to allocate decompressor")
            return
        }
        defer { ttzip_deflate_decompressor_free(decomp) }

        var decompressedData = Data(count: sampleSize)
        var actualOut: size_t = 0

        // Warm up
        _ = compressedData.withUnsafeBytes { cPtr in
            decompressedData.withUnsafeMutableBytes { dPtr in
                ttzip_deflate_decompress(
                    decomp, cPtr.baseAddress!, compressedSize, dPtr.baseAddress!, sampleSize, &actualOut
                )
            }
        }

        let iterations = 10
        let start = CACurrentMediaTime()
        for _ in 0..<iterations {
            compressedData.withUnsafeBytes { cPtr in
                decompressedData.withUnsafeMutableBytes { dPtr in
                    let res = ttzip_deflate_decompress(
                        decomp, cPtr.baseAddress!, compressedSize, dPtr.baseAddress!, sampleSize, &actualOut
                    )
                    XCTAssertEqual(res, 0, "Decompression must return 0 (success)")
                }
            }
        }
        let elapsed = CACurrentMediaTime() - start
        let totalMB = Double(sampleSize * iterations) / (1024.0 * 1024.0)
        let mbPerSec = totalMB / elapsed

        XCTAssertEqual(actualOut, sampleSize, "Decompressed size must match input sample size")
        XCTAssertEqual(decompressedData, inputData, "Decompressed data must match original input byte-for-byte")
        XCTAssertGreaterThan(mbPerSec, 4500.0, "Single-core decompression speed must exceed 4500 MB/s floor")
    }
}
