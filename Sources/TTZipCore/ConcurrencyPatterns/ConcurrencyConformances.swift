// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
