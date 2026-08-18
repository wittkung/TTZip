// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - ZipParallelWriter Bounded Queue Extension

extension ZipParallelWriter {
    
    /// Creates archive with cooperative backpressure control via `BoundedProducerConsumerQueue`.
    public func createArchiveWithBoundedQueue(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        maxQueueCapacity: Int = 16,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> Bool {
        let queue = BoundedProducerConsumerQueue<String>(maxCapacity: maxQueueCapacity)
        let totalItemsCount = inputPaths.count
        
        let producerTask = Task {
            for path in inputPaths {
                try await queue.push(path)
            }
            queue.finish()
        }
        
        let progressCounter = ConcurrencyProgressCounter()
        let workerCount = max(2, min(16, ProcessInfo.processInfo.activeProcessorCount))
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<workerCount {
                group.addTask {
                    while let path = try await queue.pop() {
                        let fm = FileManager.default
                        if fm.fileExists(atPath: path) {
                            let current = progressCounter.increment()
                            progressHandler?(ArchiveProgress(
                                state: .processing,
                                bytesProcessed: current,
                                totalBytes: Int64(totalItemsCount),
                                currentFileName: path,
                                throughputMBs: 0
                            ))
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
        
        _ = try await producerTask.value
        
        let result = try self.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            skipMacJunk: true,
            password: nil,
            progressHandler: progressHandler
        )
        
        return result
    }
}

// MARK: - ArchiveOperationPipeline Producer-Consumer Engine Extension

extension ArchiveOperationPipeline {
    
    /// Creates archive using the streaming producer-consumer bounded queue engine.
    public func createArchiveWithProducerConsumerEngine(
        inputPath: String,
        outputPath: String,
        chunkSize: Int = 64 * 1024,
        maxQueueCapacity: Int = 16,
        workerCount: Int = max(2, ProcessInfo.processInfo.activeProcessorCount),
        level: ArchiveCompressionLevel = .normal
    ) async throws -> ArchivePipelineProducerConsumerEngine.PipelineStats {
        let engine = ArchivePipelineProducerConsumerEngine()
        return try await engine.processPipeline(
            inputPath: inputPath,
            outputPath: outputPath,
            chunkSize: chunkSize,
            maxQueueCapacity: maxQueueCapacity,
            workerCount: workerCount,
            level: level
        )
    }
}

// MARK: - Thread-Safe Progress Counter Helper

private final class ConcurrencyProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count: Int64 = 0
    
    func increment() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        _count += 1
        return _count
    }
}
