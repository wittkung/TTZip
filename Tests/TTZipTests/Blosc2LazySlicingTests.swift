// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2LazySlicingTests: XCTestCase {

    func testLazyBlockSlicingAccuracyAndBypass() throws {
        var config = ttzip_schunk_config_t()
        config.chunk_size = 64 * 1024 // 64KB chunks
        config.block_size = 128 * 1024
        config.typesize = 1
        config.use_dict = false

        guard let schunk = ttzip_schunk_create(&config) else {
            XCTFail("Failed to create super-chunk")
            return
        }
        defer { ttzip_schunk_free(schunk) }

        // Append 4 distinct chunks (total 256KB)
        var originalData = Data()
        for chunkIdx in 0..<4 {
            var chunkData = Data(count: 64 * 1024)
            for i in 0..<chunkData.count {
                chunkData[i] = UInt8((chunkIdx * 50 + i) & 0xFF)
            }
            originalData.append(chunkData)
            let appended = chunkData.withUnsafeBytes { raw in
                ttzip_schunk_append_chunk(schunk, raw.baseAddress!, raw.count)
            }
            XCTAssertGreaterThanOrEqual(appended, 0)
        }

        XCTAssertEqual(schunk.pointee.uncompressed_size, 256 * 1024)

        // Test 1: Slice spanning across chunk boundaries [32KB, 32KB + 64KB) -> from chunk 0 middle to chunk 1 middle
        let sliceStart: Int64 = 32 * 1024
        let sliceLength: Int64 = 64 * 1024
        var extractedSlice = Data(count: Int(sliceLength))

        let ret1 = extractedSlice.withUnsafeMutableBytes { rawOut in
            ttzip_schunk_get_slice_buffer(
                schunk,
                sliceStart,
                sliceLength,
                rawOut.baseAddress!,
                rawOut.count
            )
        }

        XCTAssertEqual(ret1, sliceLength)
        let expectedSlice1 = originalData.subdata(in: Int(sliceStart)..<Int(sliceStart + sliceLength))
        XCTAssertEqual(extractedSlice, expectedSlice1, "Lazy slice across chunk boundaries must be bit-exact")

        // Test 2: Small header slice [0, 4KB)
        let headerLen: Int64 = 4096
        var headerSlice = Data(count: Int(headerLen))
        let ret2 = headerSlice.withUnsafeMutableBytes { rawOut in
            ttzip_schunk_get_slice_buffer(
                schunk,
                0,
                headerLen,
                rawOut.baseAddress!,
                rawOut.count
            )
        }
        XCTAssertEqual(ret2, headerLen)
        let expectedHeader = originalData.subdata(in: 0..<Int(headerLen))
        XCTAssertEqual(headerSlice, expectedHeader)

        // Test 3: Slice inside special-value sparse chunk
        let zeroChunk = Data(count: 64 * 1024)
        _ = zeroChunk.withUnsafeBytes { raw in
            ttzip_schunk_append_chunk(schunk, raw.baseAddress!, raw.count)
        }
        // Chunk 4 is sparse zero, range [256KB, 320KB)
        var zeroSlice = Data(count: 1024)
        let ret3 = zeroSlice.withUnsafeMutableBytes { rawOut in
            ttzip_schunk_get_slice_buffer(
                schunk,
                256 * 1024 + 500,
                1024,
                rawOut.baseAddress!,
                rawOut.count
            )
        }
        XCTAssertEqual(ret3, 1024)
        XCTAssertEqual(zeroSlice, Data(count: 1024), "Special-value zero slice must be all zeroes")
    }
}
