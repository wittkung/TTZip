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

final class SingleCoreDeflatePkTests: XCTestCase {

    func testSingleCoreLevel1CompressionThroughput() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("single_core_l1_test.log")
        try TestFileGenerator.createRealisticLogFile(at: tempURL, linesCount: 70362)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let inputData = try Data(contentsOf: tempURL)
        let sampleSize = inputData.count

        guard let comp = ttzip_deflate_compressor_alloc(1) else {
            XCTFail("Failed to allocate compressor")
            return
        }
        defer { ttzip_deflate_compressor_free(comp) }

        var outputData = Data(count: sampleSize + 65536)
        var compressedSize: size_t = 0

        // Warm up
        _ = inputData.withUnsafeBytes { inPtr in
            outputData.withUnsafeMutableBytes { outPtr in
                ttzip_deflate_compress(comp, inPtr.baseAddress!, sampleSize, outPtr.baseAddress!, outPtr.count)
            }
        }

        let iterations = 5
        let start = CACurrentMediaTime()
        for _ in 0..<iterations {
            inputData.withUnsafeBytes { inPtr in
                outputData.withUnsafeMutableBytes { outPtr in
                    compressedSize = ttzip_deflate_compress(
                        comp, inPtr.baseAddress!, sampleSize, outPtr.baseAddress!, outPtr.count
                    )
                }
            }
        }
        let elapsed = CACurrentMediaTime() - start
        let totalMB = Double(sampleSize * iterations) / (1024.0 * 1024.0)
        let mbPerSec = totalMB / elapsed

        XCTAssertGreaterThan(compressedSize, 0, "Compressed output must be non-zero")
        XCTAssertLessThan(compressedSize, sampleSize, "Payload must achieve compression")
        XCTAssertGreaterThan(mbPerSec, 1200.0, "Single-core Level 1 compression speed must exceed 1200 MB/s floor in Debug")
    }

    func testSingleCoreLevel6CompressionThroughput() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("single_core_l6_test.log")
        try TestFileGenerator.createRealisticLogFile(at: tempURL, linesCount: 70362)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let inputData = try Data(contentsOf: tempURL)
        let sampleSize = inputData.count

        guard let comp = ttzip_deflate_compressor_alloc(6) else {
            XCTFail("Failed to allocate compressor")
            return
        }
        defer { ttzip_deflate_compressor_free(comp) }

        var outputData = Data(count: sampleSize + 65536)
        var compressedSize: size_t = 0

        let iterations = 3
        let start = CACurrentMediaTime()
        for _ in 0..<iterations {
            inputData.withUnsafeBytes { inPtr in
                outputData.withUnsafeMutableBytes { outPtr in
                    compressedSize = ttzip_deflate_compress(
                        comp, inPtr.baseAddress!, sampleSize, outPtr.baseAddress!, outPtr.count
                    )
                }
            }
        }
        let elapsed = CACurrentMediaTime() - start
        let totalMB = Double(sampleSize * iterations) / (1024.0 * 1024.0)
        let mbPerSec = totalMB / elapsed

        XCTAssertGreaterThan(compressedSize, 0, "Compressed size must be non-zero")
        XCTAssertGreaterThan(mbPerSec, 700.0, "Single-core Level 6 compression speed must exceed 700 MB/s floor in Debug")
    }
}
