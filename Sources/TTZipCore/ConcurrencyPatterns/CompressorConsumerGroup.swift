// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Multi-threaded parallel compressor consumer group leveraging Apple Silicon SIMD and multicore acceleration.
public final class CompressorConsumerGroup: @unchecked Sendable {
    private let workerCount: Int
    private let compressionLevel: ArchiveCompressionLevel

    public init(
        workerCount: Int = max(2, ProcessInfo.processInfo.activeProcessorCount),
        compressionLevel: ArchiveCompressionLevel = .normal
    ) {
        self.workerCount = max(1, workerCount)
        self.compressionLevel = compressionLevel
    }

    /// Compresses chunk payload using flyweight pool or fallback allocation buffer.
    private func compressPayload(rawData: Data, level: ArchiveCompressionLevel, libdeflateLevel: Int32) -> Data {
        guard level != .store && !rawData.isEmpty else { return rawData }
        let maxCap = rawData.count + 512
        let pageSize: MemoryPageSize = maxCap > 4096 ? .page64K : .page4K
        var compSize: size_t = 0
        var payloadBuf = Data()

        MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            if capacity >= maxCap {
                compSize = rawData.withUnsafeBytes { inPtr -> Int in
                    guard let src = inPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    var outLen: Int = 0
                    let st = ttzip_rust_deflate_compress(src, rawData.count, dstPtr, capacity, libdeflateLevel, &outLen)
                    return st == TTZIP_STATUS_OK ? outLen : 0
                }
                if compSize > 0 && compSize < rawData.count {
                    payloadBuf = Data(bytes: dstPtr, count: compSize)
                }
            } else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxCap)
                compSize = rawData.withUnsafeBytes { inPtr -> Int in
                    guard let src = inPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    var outLen: Int = 0
                    let st = ttzip_rust_deflate_compress(src, rawData.count, uninitPtr, maxCap, libdeflateLevel, &outLen)
                    return st == TTZIP_STATUS_OK ? outLen : 0
                }
                if compSize > 0 && compSize < rawData.count {
                    payloadBuf = Data(bytesNoCopy: uninitPtr, count: compSize, deallocator: .custom { ptr, _ in ptr.deallocate() })
                } else {
                    uninitPtr.deallocate()
                }
            }
        }

        if compSize > 0 && compSize < rawData.count {
            return payloadBuf
        }
        return rawData
    }

    /// Computes CRC32 checksum for raw data.
    private func computeCRC32(data: Data) -> UInt32 {
        data.withUnsafeBytes { ptr -> UInt32 in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return ttzip_rust_crc32(0, base, data.count)
        }
    }

    /// Processes an individual data chunk through compression and checksumming.
    private func processChunk(_ chunk: ArchiveDataChunk, libdeflateLevel: Int32) -> ArchiveDataChunk {
        let rawData = chunk.data
        let compressedData = compressPayload(rawData: rawData, level: compressionLevel, libdeflateLevel: libdeflateLevel)
        let crc = computeCRC32(data: rawData)

        return ArchiveDataChunk(
            chunkID: chunk.chunkID,
            offset: chunk.offset,
            data: compressedData,
            isEOF: false,
            crc32: crc,
            metadata: ["originalSize": "\(rawData.count)"]
        )
    }

    /// Starts parallel compression pipelines consuming from input queue and pushing compressed chunks to output queue.
    public func startProcessing(
        inputQueue: BoundedProducerConsumerQueue<ArchiveDataChunk>,
        outputQueue: BoundedProducerConsumerQueue<ArchiveDataChunk>
    ) async throws {
        let level = compressionLevel
        let libdeflateLevel: Int32 = Int32(min(12, max(0, level.rawValue)))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<workerCount {
                group.addTask {
                    while true {
                        guard let chunk = try await inputQueue.pop() else { break }
                        
                        if chunk.isEOF {
                            try await outputQueue.push(chunk)
                            break
                        }

                        let processedChunk = self.processChunk(chunk, libdeflateLevel: libdeflateLevel)
                        try await outputQueue.push(processedChunk)
                    }
                }
            }
            try await group.waitForAll()
        }
        outputQueue.finish()
    }
}
