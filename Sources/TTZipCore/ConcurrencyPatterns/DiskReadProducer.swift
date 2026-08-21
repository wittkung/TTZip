// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Streaming disk read producer using `MemoryPageFlyweightPool` for zero-allocation I/O chunking.
public final class DiskReadProducer: AsyncProducerProtocol, @unchecked Sendable {
    private let fileURL: URL
    private let chunkSize: Int
    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var currentChunkID: Int64 = 0
    private var currentOffset: Int64 = 0
    private var isEOFReached: Bool = false

    public init(filePath: String, chunkSize: Int = 64 * 1024) throws {
        self.fileURL = URL(fileURLWithPath: filePath)
        self.chunkSize = max(4096, chunkSize)
        self.fileHandle = try FileHandle(forReadingFrom: fileURL)
    }

    deinit {
        try? fileHandle?.close()
    }

    private func performSyncProduce() throws -> ArchiveDataChunk? {
        lock.lock()
        defer { lock.unlock() }

        if isEOFReached {
            return nil
        }

        guard let handle = fileHandle else {
            isEOFReached = true
            return nil
        }

        let pageSize: MemoryPageSize = chunkSize <= 4096 ? .page4K : .page64K
        let flyweight = MemoryPageFlyweightPool.shared.borrowBuffer(size: pageSize)
        defer { MemoryPageFlyweightPool.shared.returnBuffer(flyweight) }

        let readData = (try? handle.read(upToCount: chunkSize)) ?? Data()
        if readData.isEmpty {
            isEOFReached = true
            let eofChunk = ArchiveDataChunk.eof(chunkID: currentChunkID)
            currentChunkID += 1
            return eofChunk
        }

        let chunk = ArchiveDataChunk(
            chunkID: currentChunkID,
            offset: currentOffset,
            data: readData,
            isEOF: false
        )

        currentChunkID += 1
        currentOffset += Int64(readData.count)

        if readData.count < chunkSize {
            isEOFReached = true
        }

        return chunk
    }

    public func produce() async throws -> ArchiveDataChunk? {
        return try performSyncProduce()
    }
}
