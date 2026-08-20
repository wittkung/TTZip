// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Represents multi-dimensional tensor shape geometry and 2-level hypercube partition layout (b2nd standard).
public struct NDimTensorShape: Sendable, Codable, Equatable {
    public let dimensions: [Int64]
    public let chunkShape: [Int64]
    public let blockShape: [Int64]
    public let dataType: String
    public let elementByteSize: Int

    public var rank: Int { dimensions.count }
    public var totalElements: Int64 { dimensions.reduce(1, *) }
    public var totalBytes: Int64 { totalElements * Int64(elementByteSize) }

    public init(
        dimensions: [Int64],
        chunkShape: [Int64],
        blockShape: [Int64],
        dataType: String = "<f4",
        elementByteSize: Int = 4
    ) {
        precondition(dimensions.count == chunkShape.count && chunkShape.count == blockShape.count, "Rank mismatch across tensor geometries")
        self.dimensions = dimensions
        self.chunkShape = chunkShape
        self.blockShape = blockShape
        self.dataType = dataType
        self.elementByteSize = elementByteSize
    }

    /// Computes strided strides (in elements) for multi-dimensional coordinate linearisation (Row-Major / C-Contiguous).
    public func rowMajorStrides() -> [Int64] {
        var strides = [Int64](repeating: 1, count: rank)
        for i in (0..<(rank - 1)).reversed() {
            strides[i] = strides[i + 1] * dimensions[i + 1]
        }
        return strides
    }
}

/// Bounding-box multi-dimensional slice range [start, end) with optional step strides.
public struct NDimSliceCoordinateRange: Sendable, Codable, Equatable {
    public let startIndices: [Int64]
    public let endIndices: [Int64]
    public let strides: [Int64]

    public init(start: [Int64], end: [Int64], strides: [Int64]? = nil) {
        self.startIndices = start
        self.endIndices = end
        self.strides = strides ?? Array(repeating: 1, count: start.count)
    }

    public func sliceShape() -> [Int64] {
        return zip(startIndices, zip(endIndices, strides)).map { s, es in
            let (e, step) = es
            return max(0, (e - s + step - 1) / step)
        }
    }

    public var totalSliceElements: Int64 {
        return sliceShape().reduce(1, *)
    }
}

/// Identifies an intersecting atomic micro-block within the 2-level hypercube partition.
public struct NDimIntersectingBlock: Sendable, Codable, Equatable {
    public let chunkIndex: Int64
    public let blockIndexInChunk: Int32
    public let chunkCoord: [Int64]
    public let blockCoord: [Int64]
    public let blockStartGlobalCoord: [Int64]
}

/// Solves coordinate intersections and selective block extraction for N-dimensional datasets.
public enum NDimHypercubeChunker {

    /// Computes number of chunks along each dimension.
    public static func chunkGridDimensions(shape: NDimTensorShape) -> [Int64] {
        return zip(shape.dimensions, shape.chunkShape).map { dim, chunk in
            (dim + chunk - 1) / chunk
        }
    }

    /// Computes number of blocks along each dimension inside a chunk.
    public static func blockGridDimensions(shape: NDimTensorShape) -> [Int64] {
        return zip(shape.chunkShape, shape.blockShape).map { chunk, block in
            (chunk + block - 1) / block
        }
    }

    /// Total chunks in the dataset.
    public static func totalChunks(shape: NDimTensorShape) -> Int64 {
        return chunkGridDimensions(shape: shape).reduce(1, *)
    }

    /// Total blocks per chunk.
    public static func blocksPerChunk(shape: NDimTensorShape) -> Int32 {
        return Int32(blockGridDimensions(shape: shape).reduce(1, *))
    }

    /// Total atomic micro-blocks in the global dataset.
    public static func totalBlocks(shape: NDimTensorShape) -> Int64 {
        return totalChunks(shape: shape) * Int64(blocksPerChunk(shape: shape))
    }

    /// Finds all micro-blocks that intersect with a requested slice range.
    public static func intersectingBlocks(
        for range: NDimSliceCoordinateRange,
        in shape: NDimTensorShape
    ) -> [NDimIntersectingBlock] {
        let rank = shape.rank
        guard rank <= 8 else {
            return fallbackIntersectingBlocks(for: range, in: shape)
        }

        var geom = ttzip_tensor_geom_t()
        var cShape = [Int64](repeating: 0, count: 8)
        var cChunk = [Int32](repeating: 0, count: 8)
        var cBlock = [Int32](repeating: 0, count: 8)

        for i in 0..<rank {
            cShape[i] = shape.dimensions[i]
            cChunk[i] = Int32(shape.chunkShape[i])
            cBlock[i] = Int32(shape.blockShape[i])
        }

        let initRes = cShape.withUnsafeBufferPointer { sPtr in
            cChunk.withUnsafeBufferPointer { cPtr in
                cBlock.withUnsafeBufferPointer { bPtr in
                    ttzip_tensor_geom_init(&geom, Int8(rank), UInt8(shape.elementByteSize), sPtr.baseAddress, cPtr.baseAddress, bPtr.baseAddress)
                }
            }
        }
        guard initRes == 0 else {
            return fallbackIntersectingBlocks(for: range, in: shape)
        }

        var slice = ttzip_tensor_slice_req_t()
        for i in 0..<rank {
            slice.start.0 = range.startIndices[0]
            if i == 0 { slice.start.0 = range.startIndices[0]; slice.stop.0 = range.endIndices[0]; slice.step.0 = range.strides[0] }
            else if i == 1 { slice.start.1 = range.startIndices[1]; slice.stop.1 = range.endIndices[1]; slice.step.1 = range.strides[1] }
            else if i == 2 { slice.start.2 = range.startIndices[2]; slice.stop.2 = range.endIndices[2]; slice.step.2 = range.strides[2] }
            else if i == 3 { slice.start.3 = range.startIndices[3]; slice.stop.3 = range.endIndices[3]; slice.step.3 = range.strides[3] }
            else if i == 4 { slice.start.4 = range.startIndices[4]; slice.stop.4 = range.endIndices[4]; slice.step.4 = range.strides[4] }
            else if i == 5 { slice.start.5 = range.startIndices[5]; slice.stop.5 = range.endIndices[5]; slice.step.5 = range.strides[5] }
            else if i == 6 { slice.start.6 = range.startIndices[6]; slice.stop.6 = range.endIndices[6]; slice.step.6 = range.strides[6] }
            else if i == 7 { slice.start.7 = range.startIndices[7]; slice.stop.7 = range.endIndices[7]; slice.step.7 = range.strides[7] }
        }

        let maxExpected = max(1024, Int(totalBlocks(shape: shape)))
        var cBlocks = [ttzip_tensor_intersect_block_t](repeating: ttzip_tensor_intersect_block_t(), count: maxExpected)

        let foundCount = cBlocks.withUnsafeMutableBufferPointer { bBuf in
            ttzip_tensor_find_intersecting_blocks(&geom, &slice, bBuf.baseAddress, maxExpected)
        }

        if foundCount > 0 {
            var results = [NDimIntersectingBlock]()
            results.reserveCapacity(foundCount)
            for i in 0..<foundCount {
                let cb = cBlocks[i]
                var chunkCoord = [Int64]()
                var blockCoord = [Int64]()
                var globalStart = [Int64]()
                for k in 0..<rank {
                    if k == 0 { chunkCoord.append(cb.chunk_coords.0); blockCoord.append(cb.block_coords.0); globalStart.append(cb.global_start_coords.0) }
                    else if k == 1 { chunkCoord.append(cb.chunk_coords.1); blockCoord.append(cb.block_coords.1); globalStart.append(cb.global_start_coords.1) }
                    else if k == 2 { chunkCoord.append(cb.chunk_coords.2); blockCoord.append(cb.block_coords.2); globalStart.append(cb.global_start_coords.2) }
                    else if k == 3 { chunkCoord.append(cb.chunk_coords.3); blockCoord.append(cb.block_coords.3); globalStart.append(cb.global_start_coords.3) }
                    else if k == 4 { chunkCoord.append(cb.chunk_coords.4); blockCoord.append(cb.block_coords.4); globalStart.append(cb.global_start_coords.4) }
                    else if k == 5 { chunkCoord.append(cb.chunk_coords.5); blockCoord.append(cb.block_coords.5); globalStart.append(cb.global_start_coords.5) }
                    else if k == 6 { chunkCoord.append(cb.chunk_coords.6); blockCoord.append(cb.block_coords.6); globalStart.append(cb.global_start_coords.6) }
                    else if k == 7 { chunkCoord.append(cb.chunk_coords.7); blockCoord.append(cb.block_coords.7); globalStart.append(cb.global_start_coords.7) }
                }
                results.append(NDimIntersectingBlock(
                    chunkIndex: cb.chunk_idx,
                    blockIndexInChunk: cb.block_idx_in_chunk,
                    chunkCoord: chunkCoord,
                    blockCoord: blockCoord,
                    blockStartGlobalCoord: globalStart
                ))
            }
            return results
        }

        return fallbackIntersectingBlocks(for: range, in: shape)
    }

    private static func fallbackIntersectingBlocks(
        for range: NDimSliceCoordinateRange,
        in shape: NDimTensorShape
    ) -> [NDimIntersectingBlock] {
        let rank = shape.rank
        let chunkGrid = chunkGridDimensions(shape: shape)
        let blockGrid = blockGridDimensions(shape: shape)

        var chunkMin = [Int64](repeating: 0, count: rank)
        var chunkMax = [Int64](repeating: 0, count: rank)
        for i in 0..<rank {
            chunkMin[i] = range.startIndices[i] / shape.chunkShape[i]
            chunkMax[i] = (max(range.startIndices[i], range.endIndices[i] - 1)) / shape.chunkShape[i]
        }

        var results: [NDimIntersectingBlock] = []

        func iterateChunks(dim: Int, currentChunkCoord: inout [Int64]) {
            if dim == rank {
                var cIdx: Int64 = 0
                var stride: Int64 = 1
                for k in (0..<rank).reversed() {
                    cIdx += currentChunkCoord[k] * stride
                    stride *= chunkGrid[k]
                }

                var blockMin = [Int64](repeating: 0, count: rank)
                var blockMax = [Int64](repeating: 0, count: rank)
                for i in 0..<rank {
                    let chunkStart = currentChunkCoord[i] * shape.chunkShape[i]
                    let chunkEnd = min(shape.dimensions[i], chunkStart + shape.chunkShape[i])
                    let localStart = max(0, range.startIndices[i] - chunkStart)
                    let localEnd = min(chunkEnd - chunkStart, range.endIndices[i] - chunkStart)

                    blockMin[i] = localStart / shape.blockShape[i]
                    blockMax[i] = max(0, (localEnd - 1) / shape.blockShape[i])
                }

                func iterateBlocks(bDim: Int, currentBlockCoord: inout [Int64]) {
                    if bDim == rank {
                        var bIdx: Int64 = 0
                        var bStride: Int64 = 1
                        for k in (0..<rank).reversed() {
                            bIdx += currentBlockCoord[k] * bStride
                            bStride *= blockGrid[k]
                        }

                        var globalStartCoord = [Int64](repeating: 0, count: rank)
                        for k in 0..<rank {
                            globalStartCoord[k] = currentChunkCoord[k] * shape.chunkShape[k] + currentBlockCoord[k] * shape.blockShape[k]
                        }

                        results.append(NDimIntersectingBlock(
                            chunkIndex: cIdx,
                            blockIndexInChunk: Int32(bIdx),
                            chunkCoord: currentChunkCoord,
                            blockCoord: currentBlockCoord,
                            blockStartGlobalCoord: globalStartCoord
                        ))
                        return
                    }

                    for b in blockMin[bDim]...blockMax[bDim] {
                        currentBlockCoord[bDim] = b
                        iterateBlocks(bDim: bDim + 1, currentBlockCoord: &currentBlockCoord)
                    }
                }

                var blockCoord = [Int64](repeating: 0, count: rank)
                iterateBlocks(bDim: 0, currentBlockCoord: &blockCoord)
                return
            }

            for c in chunkMin[dim]...chunkMax[dim] {
                currentChunkCoord[dim] = c
                iterateChunks(dim: dim + 1, currentChunkCoord: &currentChunkCoord)
            }
        }

        var chunkCoord = [Int64](repeating: 0, count: rank)
        iterateChunks(dim: 0, currentChunkCoord: &chunkCoord)

        return results
    }

    /// Extracts a dense sub-tensor slice directly into a destination memory buffer.
    public static func extractSubTensor(
        source: UnsafeRawPointer,
        shape: NDimTensorShape,
        range: NDimSliceCoordinateRange,
        destination: UnsafeMutableRawPointer
    ) {
        let rank = shape.rank
        let elemSize = shape.elementByteSize
        let srcStrides = shape.rowMajorStrides()
        let sliceDims = range.sliceShape()

        var dstStrides = [Int64](repeating: 1, count: rank)
        for i in (0..<(rank - 1)).reversed() {
            dstStrides[i] = dstStrides[i + 1] * sliceDims[i + 1]
        }

        func copyRecursive(dim: Int, srcOffset: Int64, dstOffset: Int64) {
            if dim == rank - 1 {
                // Fastest inner-most contiguous or strided row copy
                let start = range.startIndices[dim]
                let step = range.strides[dim]
                let count = sliceDims[dim]

                if step == 1 {
                    let rowBytes = Int(count) * elemSize
                    let sPtr = source.advanced(by: Int(srcOffset + start * srcStrides[dim]) * elemSize)
                    let dPtr = destination.advanced(by: Int(dstOffset) * elemSize)
                    memcpy(dPtr, sPtr, rowBytes)
                } else {
                    for i in 0..<count {
                        let sIdx = start + i * step
                        let sPtr = source.advanced(by: Int(srcOffset + sIdx * srcStrides[dim]) * elemSize)
                        let dPtr = destination.advanced(by: Int(dstOffset + i * dstStrides[dim]) * elemSize)
                        memcpy(dPtr, sPtr, elemSize)
                    }
                }
                return
            }

            let start = range.startIndices[dim]
            let step = range.strides[dim]
            let count = sliceDims[dim]

            for i in 0..<count {
                let sCoord = start + i * step
                let nextSrc = srcOffset + sCoord * srcStrides[dim]
                let nextDst = dstOffset + i * dstStrides[dim]
                copyRecursive(dim: dim + 1, srcOffset: nextSrc, dstOffset: nextDst)
            }
        }

        copyRecursive(dim: 0, srcOffset: 0, dstOffset: 0)
    }
}
