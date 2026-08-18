// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2ArchitectureAbsorptionTests: XCTestCase {

    // MARK: - 1. Adaptive Cache Topology Arbiter Tests

    func testAdaptiveCacheTopologyArbiter() {
        let l1d = ttzip_cache_get_l1d_size()
        let l2 = ttzip_cache_get_l2_size()
        let cacheline = ttzip_cache_get_cacheline_size()
        let batchSize = ttzip_cache_get_optimal_batch_size()
        let maxFiles = ttzip_cache_get_optimal_max_files()

        XCTAssertGreaterThanOrEqual(l1d, 32768, "L1D Cache size must be >= 32KB")
        XCTAssertGreaterThanOrEqual(l2, 1048576, "L2 Cache size must be >= 1MB")
        XCTAssertTrue(cacheline == 64 || cacheline == 128, "Cacheline size must be 64B (x86) or 128B (Apple Silicon)")
        XCTAssertGreaterThanOrEqual(batchSize, 32768, "Optimal batch size must be >= 32KB")
        XCTAssertGreaterThanOrEqual(maxFiles, 32, "Max files per batch must be >= 32")

        #if arch(arm64)
        XCTAssertGreaterThanOrEqual(l1d, 65536, "Apple Silicon L1D Cache must be >= 64KB")
        XCTAssertEqual(cacheline, 128, "Apple Silicon hardware cacheline must be 128 bytes")
        #endif
    }

    // MARK: - 2. Zero-Alloc Filter Pipeline Cascade Tests

    func testZeroAllocFilterPipelineShuffleAndDelta() {
        // Test Float32 array (typesize = 4)
        let elementCount = 256
        var originalFloats = [Float](repeating: 0, count: elementCount)
        for i in 0..<elementCount {
            originalFloats[i] = Float(i) * 1.5 + 0.125
        }

        let totalBytes = elementCount * MemoryLayout<Float>.size
        var shuffledBytes = [UInt8](repeating: 0, count: totalBytes)
        var restoredFloats = [Float](repeating: 0, count: elementCount)

        originalFloats.withUnsafeBytes { rawOriginal in
            shuffledBytes.withUnsafeMutableBytes { rawShuffled in
                ttzip_filter_shuffle_forward(
                    rawOriginal.bindMemory(to: UInt8.self).baseAddress!,
                    rawShuffled.bindMemory(to: UInt8.self).baseAddress!,
                    totalBytes,
                    4
                )
            }
        }

        shuffledBytes.withUnsafeBytes { rawShuffled in
            restoredFloats.withUnsafeMutableBytes { rawRestored in
                ttzip_filter_shuffle_backward(
                    rawShuffled.bindMemory(to: UInt8.self).baseAddress!,
                    rawRestored.bindMemory(to: UInt8.self).baseAddress!,
                    totalBytes,
                    4
                )
            }
        }

        XCTAssertEqual(originalFloats, restoredFloats, "Byte shuffle roundtrip must preserve float array bit-for-bit")

        // Test Full Filter Pipeline Cascade: Shuffle -> Delta -> Backward
        var pipeline = ttzip_filter_pipeline_t()
        pipeline.filters.0 = TTZIP_FILTER_SHUFFLE
        pipeline.type_sizes.0 = 4
        pipeline.filters.1 = TTZIP_FILTER_DELTA
        pipeline.type_sizes.1 = 1
        pipeline.count = 2

        var filteredOutput = [UInt8](repeating: 0, count: totalBytes)
        var recoveredOutput = [Float](repeating: 0, count: elementCount)

        let forwardRet = originalFloats.withUnsafeBytes { srcPtr in
            filteredOutput.withUnsafeMutableBytes { dstPtr in
                ttzip_filter_pipeline_apply_forward(
                    &pipeline,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                    dstPtr.bindMemory(to: UInt8.self).baseAddress!,
                    totalBytes
                )
            }
        }
        XCTAssertEqual(forwardRet, 0, "Forward pipeline execution must succeed")

        let backwardRet = filteredOutput.withUnsafeBytes { srcPtr in
            recoveredOutput.withUnsafeMutableBytes { dstPtr in
                ttzip_filter_pipeline_apply_backward(
                    &pipeline,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                    dstPtr.bindMemory(to: UInt8.self).baseAddress!,
                    totalBytes
                )
            }
        }
        XCTAssertEqual(backwardRet, 0, "Backward pipeline execution must succeed")
        XCTAssertEqual(originalFloats, recoveredOutput, "Pipeline cascade roundtrip must match original bit-for-bit")
    }

    // MARK: - 3. Sparse Slicing / Sub-Chunk Prefix Tests

    func testSubChunkSparsePrefixSlicing() throws {
        // Create 100KB original payload
        let originalText = String(repeating: "TTZip High-Performance Native Compression and Slicing 2026! ", count: 2000)
        let originalData = originalText.data(using: .utf8)!
        let originalBytes = [UInt8](originalData)

        // Compress using Raw Deflate
        let config = DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
        let compressedData = try DeflateStreamEngine.compress(data: originalData, config: config)
        let compBytes = [UInt8](compressedData)

        XCTAssertGreaterThan(compBytes.count, 0, "Deflate compression must succeed")

        // Decompress ONLY first 256 bytes prefix slice
        let sliceTargetBytes = 256
        var dstSlice = [UInt8](repeating: 0, count: sliceTargetBytes)
        var actualDecomp: Int = 0

        let sliceRet = compBytes.withUnsafeBytes { rawComp in
            dstSlice.withUnsafeMutableBytes { rawDst in
                ttzip_deflate_decompress_prefix_slice(
                    rawComp.bindMemory(to: UInt8.self).baseAddress!,
                    compBytes.count,
                    rawDst.bindMemory(to: UInt8.self).baseAddress!,
                    sliceTargetBytes,
                    &actualDecomp
                )
            }
        }

        XCTAssertEqual(sliceRet, 0, "Prefix slice decompression must succeed")
        XCTAssertEqual(actualDecomp, sliceTargetBytes, "Produced slice bytes must match target")
        XCTAssertEqual(Array(dstSlice[0..<sliceTargetBytes]), Array(originalBytes[0..<sliceTargetBytes]), "Decompressed prefix slice must match original prefix bit-for-bit")
    }
}
