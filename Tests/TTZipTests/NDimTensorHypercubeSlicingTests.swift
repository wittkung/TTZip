// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class NDimTensorHypercubeSlicingTests: XCTestCase {

    func test3DTensorOrthogonalCrossSectionSlicing() throws {
        // Global shape: 128 x 128 x 32 (Float32 volume = 2MB)
        // Chunks: 64 x 64 x 16 (4 chunks total)
        // Blocks: 16 x 16 x 8 (32 blocks per chunk)
        let shape = NDimTensorShape(
            dimensions: [128, 128, 32],
            chunkShape: [64, 64, 16],
            blockShape: [16, 16, 8],
            dataType: "<f4",
            elementByteSize: 4
        )

        let totalBlocks = NDimHypercubeChunker.totalBlocks(shape: shape)
        XCTAssertEqual(totalBlocks, 8 * 32, "Total blocks must be 256 (8 chunks * 32 blocks)")

        // Request a 2D orthogonal slice plane: [0..128, 0..128, 10..11]
        let sliceRange = NDimSliceCoordinateRange(
            start: [0, 0, 10],
            end: [128, 128, 11]
        )

        let intersecting = NDimHypercubeChunker.intersectingBlocks(for: sliceRange, in: shape)
        XCTAssertGreaterThan(intersecting.count, 0)
        XCTAssertLessThanOrEqual(intersecting.count, 64, "Intersecting blocks must be a fraction of total volume")

        // Generate synthetic tensor
        let elemCount = Int(shape.totalElements)
        var sourceTensor = [Float](repeating: 0.0, count: elemCount)
        for i in 0..<elemCount {
            sourceTensor[i] = Float(i) * 0.1
        }

        let sliceElems = Int(sliceRange.totalSliceElements)
        var extractedSlice = [Float](repeating: 0.0, count: sliceElems)

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        sourceTensor.withUnsafeBytes { sBytes in
            extractedSlice.withUnsafeMutableBytes { dBytes in
                NDimHypercubeChunker.extractSubTensor(
                    source: sBytes.baseAddress!,
                    shape: shape,
                    range: sliceRange,
                    destination: dBytes.baseAddress!
                )
            }
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let elapsedMs = Double(t1 - t0) / 1_000_000.0

        XCTAssertLessThan(elapsedMs, 5.0, "Sub-tensor extraction must be < 5.0 ms")

        // Verify correct coordinate extraction: element at (10, 20, 10)
        let strides = shape.rowMajorStrides()
        let expectedVal = sourceTensor[Int(10 * strides[0] + 20 * strides[1] + 10 * strides[2])]
        let actualVal = extractedSlice[10 * 128 + 20]
        XCTAssertEqual(actualVal, expectedVal, accuracy: 1e-5)
    }
}
