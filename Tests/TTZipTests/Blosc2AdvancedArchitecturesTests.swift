// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2AdvancedArchitecturesTests: XCTestCase {

    // MARK: - 1. Float Truncate Precision & Shuffle Synergy Tests

    func testNeonFloatTruncateFilterAndShuffleSynergy() throws {
        // Generate 16384 Float32 values with noisy fractional parts
        let count = 16384
        var originalFloats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            // Simulated sensor data: base signal + micro-noise
            originalFloats[i] = sin(Float(i) * 0.05) * 100.0 + Float(i % 100) * 0.0031415926
        }

        let rawBytes = count * MemoryLayout<Float>.size
        var truncatedFloats = [Float](repeating: 0, count: count)

        // 1. NEON Mantissa Truncation (keep 7 bits of mantissa)
        originalFloats.withUnsafeBufferPointer { srcPtr in
            truncatedFloats.withUnsafeMutableBufferPointer { dstPtr in
                ttzip_filter_truncate_float32_neon(srcPtr.baseAddress!, dstPtr.baseAddress!, count, 7)
            }
        }

        // Verify truncation: all low 16 bits should be zero
        let uDst = truncatedFloats.withUnsafeBytes { $0.bindMemory(to: UInt32.self) }
        for i in 0..<count {
            let low16 = uDst[i] & 0xFFFF
            XCTAssertEqual(low16, 0, "Low 16 bits of mantissa must be zeroed by 7-bit truncation")
        }

        // 2. Execute Pipeline: Truncate -> Byte Shuffle
        var shuffledBytes = [UInt8](repeating: 0, count: rawBytes)
        truncatedFloats.withUnsafeBytes { rawTrunc in
            shuffledBytes.withUnsafeMutableBytes { rawShuf in
                ttzip_filter_shuffle_forward(
                    rawTrunc.bindMemory(to: UInt8.self).baseAddress!,
                    rawShuf.bindMemory(to: UInt8.self).baseAddress!,
                    rawBytes,
                    4
                )
            }
        }

        // 3. Compress raw floats vs. (Truncate + Shuffle) floats via Deflate
        let rawData = Data(bytes: originalFloats, count: rawBytes)
        let processedData = Data(shuffledBytes)

        let config = DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
        let compRaw = try DeflateStreamEngine.compress(data: rawData, config: config)
        let compProcessed = try DeflateStreamEngine.compress(data: processedData, config: config)

        let rawRatio = Double(rawBytes) / Double(compRaw.count)
        let processedRatio = Double(rawBytes) / Double(compProcessed.count)

        // Assert massive compression ratio boost (>= 8.0x)
        XCTAssertGreaterThan(processedRatio, 8.0, "Truncate + Shuffle + Deflate must achieve >= 8.0x compression ratio")
        XCTAssertGreaterThan(processedRatio, rawRatio * 3.0, "Synergy pipeline must outperform raw Deflate by >3x")

        // 4. Float64 NEON Truncation
        var doubleArray = [Double](repeating: 0, count: 512)
        for i in 0..<512 {
            doubleArray[i] = cos(Double(i) * 0.02) * 500.0 + Double(i) * 0.000123456789
        }
        var truncDouble = [Double](repeating: 0, count: 512)
        doubleArray.withUnsafeBufferPointer { sPtr in
            truncDouble.withUnsafeMutableBufferPointer { dPtr in
                ttzip_filter_truncate_float64_neon(sPtr.baseAddress!, dPtr.baseAddress!, 512, 14)
            }
        }
        let uDst64 = truncDouble.withUnsafeBytes { $0.bindMemory(to: UInt64.self) }
        for i in 0..<512 {
            let low38 = uDst64[i] & ((1 << 38) - 1)
            XCTAssertEqual(low38, 0, "Low 38 bits of float64 must be zeroed by 14-bit mantissa truncation")
        }
    }

    // MARK: - 2. Double-Buffered Async Prefetch Pipeline Tests

    func testDoubleBufferedAsyncPrefetchPipeline() {
        guard let pipe = ttzip_prefetch_create(1024 * 1024) else {
            XCTFail("ttzip_prefetch_create failed")
            return
        }
        defer { ttzip_prefetch_destroy(pipe) }

        let chunkCount = 50
        var payloads: [Data] = []
        for i in 0..<chunkCount {
            let content = "Prefetch_Chunk_Payload_#\(i)_" + String(repeating: "DATA_\(i)_", count: 500)
            payloads.append(content.data(using: .utf8)!)
        }
        let testPayloads = payloads
        nonisolated(unsafe) let sharedPipe = pipe

        // Producer Thread
        let producer = Thread {
            for i in 0..<chunkCount {
                let data = testPayloads[i]
                data.withUnsafeBytes { raw in
                    let ret = ttzip_prefetch_commit_slot(sharedPipe, Int64(i), raw.bindMemory(to: UInt8.self).baseAddress!, raw.count)
                    XCTAssertEqual(ret, 0)
                }
            }
        }
        producer.start()

        // Consumer Thread (Main)
        for i in 0..<chunkCount {
            var outBuf: UnsafeMutablePointer<UInt8>? = nil
            var outSize: Int = 0

            let ret = ttzip_prefetch_acquire_slot(pipe, Int64(i), &outBuf, &outSize)
            XCTAssertEqual(ret, 0)
            XCTAssertNotNil(outBuf)
            XCTAssertEqual(outSize, testPayloads[i].count)

            let retrievedData = Data(bytes: outBuf!, count: outSize)
            XCTAssertEqual(retrievedData, testPayloads[i], "Retrieved chunk \(i) must match committed payload bit-for-bit")

            ttzip_prefetch_release_slot(pipe, Int64(i))
        }

        while !producer.isFinished {
            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    // MARK: - 3. VLMeta Variable-Length Self-Compressed Trailer Tests

    func testVLMetaTrailerSerializationAndAppend() throws {
        let sandbox = try IsolatedTempSandbox(prefix: "VLMetaSandbox")
        defer { sandbox.cleanup() }

        let archiveURL = sandbox.fileURL(named: "test_archive.ttzip")
        let dummyPayload = "Base Archive Dummy Payload Content".data(using: .utf8)!
        try dummyPayload.write(to: archiveURL)

        let initialSize = try FileManager.default.attributesOfItem(atPath: archiveURL.path)[FileAttributeKey.size] as? Int64 ?? 0

        // Create 2 metadata layers
        let thumbData = Data(repeating: 0xAB, count: 2048) // 2KB QuickLook Thumb
        let indexJSON = "{\"entries\": 500, \"indexed_terms\": [\"report\", \"invoice\", \"2026\"]}".data(using: .utf8)!

        var entries = [
            ttzip_vlmeta_entry_t(),
            ttzip_vlmeta_entry_t()
        ]

        thumbData.withUnsafeBytes { rawThumb in
            indexJSON.withUnsafeBytes { rawIndex in
                strcpy(&entries[0].name.0, "quicklook_thumb")
                entries[0].payload = rawThumb.bindMemory(to: UInt8.self).baseAddress!
                entries[0].payload_size = rawThumb.count

                strcpy(&entries[1].name.0, "search_index")
                entries[1].payload = rawIndex.bindMemory(to: UInt8.self).baseAddress!
                entries[1].payload_size = rawIndex.count

                let appendRet = archiveURL.path.withCString { cPath in
                    ttzip_vlmeta_append_trailer(cPath, entries, 2)
                }
                XCTAssertEqual(appendRet, 0, "ttzip_vlmeta_append_trailer must succeed")
            }
        }

        let newSize = try FileManager.default.attributesOfItem(atPath: archiveURL.path)[FileAttributeKey.size] as? Int64 ?? 0
        XCTAssertGreaterThan(newSize, initialSize, "Archive size must increase by trailer length")

        // Readback quicklook_thumb
        var outThumb: UnsafeMutablePointer<UInt8>? = nil
        var outThumbSize: Int = 0
        let readRet1 = archiveURL.path.withCString { cPath in
            "quicklook_thumb".withCString { cName in
                ttzip_vlmeta_read_layer(cPath, cName, &outThumb, &outThumbSize)
            }
        }
        XCTAssertEqual(readRet1, 0)
        XCTAssertEqual(outThumbSize, thumbData.count)
        let extractedThumb = Data(bytes: outThumb!, count: outThumbSize)
        XCTAssertEqual(extractedThumb, thumbData, "Extracted thumbnail metadata must match bit-for-bit")
        ttzip_vlmeta_free_payload(outThumb)

        // Readback search_index
        var outIndex: UnsafeMutablePointer<UInt8>? = nil
        var outIndexSize: Int = 0
        let readRet2 = archiveURL.path.withCString { cPath in
            "search_index".withCString { cName in
                ttzip_vlmeta_read_layer(cPath, cName, &outIndex, &outIndexSize)
            }
        }
        XCTAssertEqual(readRet2, 0)
        XCTAssertEqual(outIndexSize, indexJSON.count)
        let extractedIndex = Data(bytes: outIndex!, count: outIndexSize)
        XCTAssertEqual(extractedIndex, indexJSON, "Extracted search index metadata must match bit-for-bit")
        ttzip_vlmeta_free_payload(outIndex)
    }

    // MARK: - 4. N-Dimensional Tensor Hyper-Cube Slicing Tests

    func testNDimensionalTensorHyperCubeSlicing() {
        var geom = ttzip_tensor_geom_t()
        // 4D Shape: [4, 8, 16, 32], ChunkShape: [2, 4, 8, 16], BlockShape: [1, 2, 4, 8]
        var shape: [Int64] = [4, 8, 16, 32]
        var chunkshape: [Int32] = [2, 4, 8, 16]
        var blockshape: [Int32] = [1, 2, 4, 8]

        let initRet = ttzip_tensor_geom_init(&geom, 4, 4, &shape, &chunkshape, &blockshape)
        XCTAssertEqual(initRet, 0, "ttzip_tensor_geom_init must succeed")

        // 1. Test Coordinate Translation
        var coords: [Int64] = [1, 5, 10, 20]
        var chunkIdx: Int64 = 0
        var blockIdx: Int32 = 0
        var elemByteOffset: Int = 0

        ttzip_tensor_coord_to_index(&geom, &coords, &chunkIdx, &blockIdx, &elemByteOffset)
        XCTAssertGreaterThanOrEqual(chunkIdx, 0)
        XCTAssertGreaterThanOrEqual(blockIdx, 0)
        XCTAssertGreaterThanOrEqual(elemByteOffset, 0)

        // 2. Test Strided Slicing Execution on 4D float tensor
        let totalElements = 4 * 8 * 16 * 32 // 16,384 elements
        var tensorData = [Float](repeating: 0, count: totalElements)
        for i in 0..<totalElements {
            tensorData[i] = Float(i) * 0.25
        }

        // Slice request: [1..2, 2..3, 0..16:2, 0..32:4] -> Size = 1 * 1 * 8 * 8 = 64 elements
        var sliceReq = ttzip_tensor_slice_req_t()
        sliceReq.start.0 = 1; sliceReq.stop.0 = 2; sliceReq.step.0 = 1
        sliceReq.start.1 = 2; sliceReq.stop.1 = 3; sliceReq.step.1 = 1
        sliceReq.start.2 = 0; sliceReq.stop.2 = 16; sliceReq.step.2 = 2
        sliceReq.start.3 = 0; sliceReq.stop.3 = 32; sliceReq.step.3 = 4

        var sliceDst = [Float](repeating: 0, count: 64)
        var extractedBytes: Int = 0

        let sliceRet = tensorData.withUnsafeBytes { rawSrc in
            sliceDst.withUnsafeMutableBytes { rawDst in
                ttzip_tensor_extract_strided_slice(
                    &geom,
                    rawSrc.bindMemory(to: UInt8.self).baseAddress!,
                    &sliceReq,
                    rawDst.bindMemory(to: UInt8.self).baseAddress!,
                    64 * MemoryLayout<Float>.size,
                    &extractedBytes
                )
            }
        }

        XCTAssertEqual(sliceRet, 0, "ttzip_tensor_extract_strided_slice must succeed")
        XCTAssertEqual(extractedBytes, 64 * MemoryLayout<Float>.size, "Extracted bytes must match 64 floats")

        // Verify first element of slice [1, 2, 0, 0]
        let expectedFirstIdx = (1 * 8 * 16 * 32) + (2 * 16 * 32) + (0 * 32) + 0
        XCTAssertEqual(sliceDst[0], Float(expectedFirstIdx) * 0.25, "First slice element must match expected tensor index value")
    }

    // MARK: - 5. SIMD BitShuffle & ByteDelta Roundtrip Tests

    func testBitShuffleNeonForwardBackwardRoundtrip() {
        let count = 4096 // 16KB of Float32
        var originalFloats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            originalFloats[i] = sin(Float(i) * 0.1) * 50.0 + Float(i) * 0.05
        }
        let byteCount = count * MemoryLayout<Float>.size
        let rawData = Data(bytes: originalFloats, count: byteCount)

        var forwardBuf = Data(count: byteCount)
        var backwardBuf = Data(count: byteCount)

        rawData.withUnsafeBytes { rawIn in
            forwardBuf.withUnsafeMutableBytes { rawOut in
                ttzip_filter_bitshuffle_forward_neon(
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    byteCount,
                    4
                )
            }
        }

        forwardBuf.withUnsafeBytes { rawIn in
            backwardBuf.withUnsafeMutableBytes { rawOut in
                ttzip_filter_bitshuffle_backward_neon(
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    byteCount,
                    4
                )
            }
        }

        XCTAssertEqual(backwardBuf, rawData, "BitShuffle forward -> backward must be lossless bit-for-bit")
    }

    func testByteDeltaNeonForwardBackwardRoundtrip() {
        let size = 65536 // 64KB
        var originalBytes = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            originalBytes[i] = UInt8(truncatingIfNeeded: (i * 7 + i / 128))
        }
        let rawData = Data(originalBytes)

        var forwardBuf = Data(count: size)
        var backwardBuf = Data(count: size)

        rawData.withUnsafeBytes { rawIn in
            forwardBuf.withUnsafeMutableBytes { rawOut in
                ttzip_filter_bytedelta_forward_neon(
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    size,
                    1
                )
            }
        }

        forwardBuf.withUnsafeBytes { rawIn in
            backwardBuf.withUnsafeMutableBytes { rawOut in
                ttzip_filter_bytedelta_backward_neon(
                    rawIn.bindMemory(to: UInt8.self).baseAddress!,
                    rawOut.bindMemory(to: UInt8.self).baseAddress!,
                    size,
                    1
                )
            }
        }

        XCTAssertEqual(backwardBuf, rawData, "128-byte unrolled ByteDelta forward -> backward must be lossless bit-for-bit")
    }

    func testBlosc2FilterBridgeMultiFilterPipeline() {
        let count = 2048
        var floats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            floats[i] = Float(i) * 1.5
        }
        let rawData = Data(bytes: floats, count: count * 4)

        let pipeline = Blosc2FilterBridge.PipelineConfig(
            filters: [.shuffle, .delta],
            typeSizes: [4, 4],
            truncateBits: [0, 0]
        )

        let encoded = Blosc2FilterBridge.applyForward(pipeline: pipeline, data: rawData)
        XCTAssertNotEqual(encoded, rawData)

        let decoded = Blosc2FilterBridge.applyBackward(pipeline: pipeline, data: encoded)
        XCTAssertEqual(decoded, rawData, "Filter pipeline bridge must execute lossless roundtrip")
    }
}

