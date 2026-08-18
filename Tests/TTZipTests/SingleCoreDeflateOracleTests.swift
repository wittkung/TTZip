// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
import CryptoKit
@testable import TTZipCore
import CTTZipBridge

final class SingleCoreDeflateOracleTests: XCTestCase {

    func testRoundTripOracleExactMatch() throws {
        let testSizes = [0, 16, 64, 1024, 65536, 1024 * 1024]

        for size in testSizes {
            var inputData = Data(count: size)
            if size > 0 {
                inputData.withUnsafeMutableBytes { ptr in
                    let buf = ptr.bindMemory(to: UInt8.self)
                    for i in 0..<size {
                        buf[i] = UInt8((i * 37 + 13) & 0xFF)
                    }
                }
            }

            guard let comp = ttzip_deflate_compressor_alloc(1) else {
                XCTFail("Failed to allocate compressor for size \(size)")
                continue
            }
            defer { ttzip_deflate_compressor_free(comp) }

            var compressedData = Data(count: size + 65536)
            var compressedSize: size_t = 0
            inputData.withUnsafeBytes { inPtr in
                compressedData.withUnsafeMutableBytes { outPtr in
                    compressedSize = ttzip_deflate_compress(
                        comp, inPtr.baseAddress, size, outPtr.baseAddress!, outPtr.count
                    )
                }
            }

            if size > 0 {
                XCTAssertGreaterThan(compressedSize, 0, "Compressed output for size \(size) must be non-zero")
            }

            guard let decomp = ttzip_deflate_decompressor_alloc() else {
                XCTFail("Failed to allocate decompressor for size \(size)")
                continue
            }
            defer { ttzip_deflate_decompressor_free(decomp) }

            var decompressedData = Data(count: size)
            var actualOut: size_t = 0
            let res = compressedData.withUnsafeBytes { cPtr in
                decompressedData.withUnsafeMutableBytes { dPtr in
                    ttzip_deflate_decompress(
                        decomp, cPtr.baseAddress, compressedSize, dPtr.baseAddress, size, &actualOut
                    )
                }
            }

            XCTAssertEqual(res, 0, "Decompression return code for size \(size) must be 0")
            XCTAssertEqual(actualOut, size, "Decompressed size must match original input size \(size)")
            XCTAssertEqual(
                SHA256.hash(data: decompressedData),
                SHA256.hash(data: inputData),
                "SHA-256 digest must match original payload 100%"
            )
        }
    }
}
