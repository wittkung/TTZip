// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2SuperChunkTests: XCTestCase {

    func testSuperChunkCreationAndChunkAppend() {
        var config = ttzip_schunk_config_t()
        config.chunk_size = 1024 * 1024 // 1MB
        config.block_size = 128 * 1024  // 128KB (Apple Silicon L1D)
        config.typesize = 4
        config.clevel = 3
        config.compcode = 1
        config.use_dict = false

        guard let schunk = ttzip_schunk_create(&config) else {
            XCTFail("Failed to create SuperChunk")
            return
        }
        defer { ttzip_schunk_free(schunk) }

        XCTAssertEqual(schunk.pointee.magic, 0x54545343)
        XCTAssertEqual(schunk.pointee.block_size, 128 * 1024)

        // Append Chunk 1 (Text payload)
        let payload1 = "SuperChunk Payload 1: ".data(using: .utf8)! + Data(repeating: 0x41, count: 65536)
        let csize1 = payload1.withUnsafeBytes { raw in
            ttzip_schunk_append_chunk(schunk, raw.baseAddress!, payload1.count)
        }
        XCTAssertGreaterThan(csize1, 0)
        XCTAssertEqual(schunk.pointee.nchunks, 1)

        // Append Chunk 2 (Special Zero block)
        let zeroPayload = Data(count: 131072)
        let csize2 = zeroPayload.withUnsafeBytes { raw in
            ttzip_schunk_append_chunk(schunk, raw.baseAddress!, zeroPayload.count)
        }
        XCTAssertEqual(csize2, 0, "Special Zero chunk must store 0 payload bytes")
        XCTAssertEqual(schunk.pointee.nchunks, 2)

        // Decompress Chunk 1
        var decBuf1 = Data(count: payload1.count)
        let dsize1 = decBuf1.withUnsafeMutableBytes { rawOut in
            ttzip_schunk_decompress_chunk(schunk, 0, rawOut.baseAddress!, payload1.count)
        }
        XCTAssertEqual(dsize1, Int64(payload1.count))
        XCTAssertEqual(decBuf1, payload1)

        // Decompress Chunk 2
        var decBuf2 = Data(count: zeroPayload.count)
        let dsize2 = decBuf2.withUnsafeMutableBytes { rawOut in
            ttzip_schunk_decompress_chunk(schunk, 1, rawOut.baseAddress!, zeroPayload.count)
        }
        XCTAssertEqual(dsize2, Int64(zeroPayload.count))
        XCTAssertEqual(decBuf2, zeroPayload)
    }

    func testSuperChunkSharedDictionaryTraining() {
        var config = ttzip_schunk_config_t()
        config.chunk_size = 512 * 1024
        config.block_size = 128 * 1024
        config.typesize = 1
        config.use_dict = true

        guard let schunk = ttzip_schunk_create(&config) else {
            XCTFail("Failed to create SuperChunk")
            return
        }
        defer { ttzip_schunk_free(schunk) }

        // Train dictionary on JSON records
        let sampleRecord = "{\"timestamp\": 1723982400, \"sensor_id\": \"M3_PRO_01\", \"metric\": 42.5, \"status\": \"HEALTHY\"}\n"
        let recData = sampleRecord.data(using: .utf8)!
        var sampleData = Data()
        for _ in 0..<200 { sampleData.append(recData) }

        let trainRet = sampleData.withUnsafeBytes { raw in
            ttzip_schunk_train_dict(schunk, raw.baseAddress!, sampleData.count)
        }
        XCTAssertEqual(trainRet, 0, "Dictionary training must succeed")
        XCTAssertNotNil(schunk.pointee.cdict_handle)
        XCTAssertNotNil(schunk.pointee.ddict_handle)

        // Compress chunks using the shared dictionary
        for i in 0..<5 {
            let chunkRecord = "{\"timestamp\": \(1723982400 + i * 10), \"sensor_id\": \"M3_PRO_01\", \"metric\": \(42.5 + Double(i)), \"status\": \"HEALTHY\"}\n"
            let cRecData = chunkRecord.data(using: .utf8)!
            var chunkData = Data()
            for _ in 0..<100 { chunkData.append(cRecData) }

            let csize = chunkData.withUnsafeBytes { raw in
                ttzip_schunk_append_chunk(schunk, raw.baseAddress!, chunkData.count)
            }
            XCTAssertGreaterThan(csize, 0)
            XCTAssertLessThan(csize, Int64(chunkData.count / 2), "Shared dictionary must achieve >2x compression on homogeneous JSON")

            var decData = Data(count: chunkData.count)
            let dsize = decData.withUnsafeMutableBytes { rawOut in
                ttzip_schunk_decompress_chunk(schunk, size_t(i), rawOut.baseAddress!, chunkData.count)
            }
            XCTAssertEqual(dsize, Int64(chunkData.count))
            XCTAssertEqual(decData, chunkData, "Decompressed record \(i) must match bit-for-bit")
        }
    }
}
