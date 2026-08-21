// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Sequential disk write consumer ensuring ordered writes from out-of-order parallel compressors.
public final class DiskWriteConsumer: AsyncConsumerProtocol, @unchecked Sendable {
    private let outputPath: String
    public let maxReorderBufferCapacity: Int
    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var nextExpectedChunkID: Int64 = 0
    private var pendingChunks: [Int64: ArchiveDataChunk] = [:]
    private var waitingContinuations: [CheckedContinuation<Void, Error>] = []
    private var isCancelled: Bool = false
    private var cancelError: Error? = nil
    
    private var _totalWrittenBytes: Int64 = 0
    private var _totalChunksProcessed: Int64 = 0

    public var totalWrittenBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return _totalWrittenBytes
    }

    public var totalChunksProcessed: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return _totalChunksProcessed
    }

    public var pendingChunksCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingChunks.count
    }

    public init(outputPath: String, maxReorderBufferCapacity: Int = 64) throws {
        self.outputPath = outputPath
        self.maxReorderBufferCapacity = max(1, maxReorderBufferCapacity)
        let fm = FileManager.default
        try? fm.removeItem(atPath: outputPath)
        fm.createFile(atPath: outputPath, contents: nil)
        self.fileHandle = FileHandle(forWritingAtPath: outputPath)
    }

    deinit {
        try? fileHandle?.close()
    }

    private func checkCapacityAndRegisterContinuation(_ chunk: ArchiveDataChunk, continuation: CheckedContinuation<Void, Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if isCancelled {
            continuation.resume(throwing: cancelError ?? BoundedProducerConsumerQueue<ArchiveDataChunk>.QueueError.cancelled)
            return true
        }

        if pendingChunks.count >= maxReorderBufferCapacity && chunk.chunkID != nextExpectedChunkID {
            waitingContinuations.append(continuation)
            return true
        }

        return false
    }

    private func performSyncConsume(_ chunk: ArchiveDataChunk) throws -> [CheckedContinuation<Void, Error>] {
        lock.lock()
        defer { lock.unlock() }

        if isCancelled {
            throw cancelError ?? BoundedProducerConsumerQueue<ArchiveDataChunk>.QueueError.cancelled
        }

        pendingChunks[chunk.chunkID] = chunk

        while let nextChunk = pendingChunks.removeValue(forKey: nextExpectedChunkID) {
            if !nextChunk.data.isEmpty, let handle = fileHandle {
                try handle.write(contentsOf: nextChunk.data)
                _totalWrittenBytes += Int64(nextChunk.data.count)
            }
            _totalChunksProcessed += 1
            nextExpectedChunkID += 1
        }

        if pendingChunks.count < maxReorderBufferCapacity && !waitingContinuations.isEmpty {
            let toResume = waitingContinuations
            waitingContinuations.removeAll()
            return toResume
        }
        return []
    }

    private func handleConsumeError(_ error: Error) -> [CheckedContinuation<Void, Error>] {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        cancelError = error
        let toResume = waitingContinuations
        waitingContinuations.removeAll()
        return toResume
    }

    public func consume(_ chunk: ArchiveDataChunk) async throws {
        if chunk.isEOF {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let handled = checkCapacityAndRegisterContinuation(chunk, continuation: continuation)
            if !handled {
                continuation.resume()
            }
        }

        let continuationsToResume: [CheckedContinuation<Void, Error>]
        do {
            continuationsToResume = try performSyncConsume(chunk)
        } catch {
            let toResume = handleConsumeError(error)
            for c in toResume {
                c.resume(throwing: error)
            }
            throw error
        }

        for continuation in continuationsToResume {
            continuation.resume()
        }
    }

    public func cancel(error: Error? = nil) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            return
        }
        isCancelled = true
        cancelError = error
        pendingChunks.removeAll()
        let toResume = waitingContinuations
        waitingContinuations.removeAll()
        lock.unlock()

        let err = error ?? BoundedProducerConsumerQueue<ArchiveDataChunk>.QueueError.cancelled
        for c in toResume {
            c.resume(throwing: err)
        }
    }

    public func finish() throws {
        lock.lock()
        defer { lock.unlock() }
        if isCancelled { return }
        try fileHandle?.synchronize()
        try fileHandle?.close()
        fileHandle = nil
    }
}
