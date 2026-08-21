// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Core pipeline orchestrator executing streaming producer-consumer transformations.
public final class ArchivePipelineProducerConsumerEngine: Sendable {

    /// Metrics telemetry report for pipeline executions.
    public struct PipelineStats: Sendable, Equatable {
        public let totalOriginalBytes: Int64
        public let totalCompressedBytes: Int64
        public let totalChunksProcessed: Int64
        public let durationSeconds: Double
        public let throughputMBs: Double
    }

    public init() {}

    /// Runs end-to-end streaming producer-consumer pipeline.
    public func processPipeline(
        inputPath: String,
        outputPath: String,
        chunkSize: Int = 64 * 1024,
        maxQueueCapacity: Int = 16,
        maxReorderBufferCapacity: Int = 64,
        workerCount: Int = max(2, ProcessInfo.processInfo.activeProcessorCount),
        level: ArchiveCompressionLevel = .normal
    ) async throws -> PipelineStats {
        let startTime = Date()
        let fm = FileManager.default
        let attr = try fm.attributesOfItem(atPath: inputPath)
        let totalOriginalBytes = (attr[.size] as? Int64) ?? 0

        let producer = try DiskReadProducer(filePath: inputPath, chunkSize: chunkSize)
        let consumer = try DiskWriteConsumer(outputPath: outputPath, maxReorderBufferCapacity: maxReorderBufferCapacity)

        let inputQueue = BoundedProducerConsumerQueue<ArchiveDataChunk>(maxCapacity: maxQueueCapacity)
        let outputQueue = BoundedProducerConsumerQueue<ArchiveDataChunk>(maxCapacity: maxQueueCapacity)

        let compressorGroup = CompressorConsumerGroup(workerCount: workerCount, compressionLevel: level)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Stage 1: Producer task reading from disk into input queue
                group.addTask {
                    do {
                        while let chunk = try await producer.produce() {
                            let isEOF = chunk.isEOF
                            try await inputQueue.push(chunk)
                            if isEOF { break }
                        }
                        inputQueue.finish()
                    } catch {
                        inputQueue.cancel(error: error)
                        outputQueue.cancel(error: error)
                        consumer.cancel(error: error)
                        throw error
                    }
                }

                // Stage 2: Compressor consumer group reading from input queue and pushing compressed chunks
                group.addTask {
                    do {
                        try await compressorGroup.startProcessing(inputQueue: inputQueue, outputQueue: outputQueue)
                    } catch {
                        inputQueue.cancel(error: error)
                        outputQueue.cancel(error: error)
                        consumer.cancel(error: error)
                        throw error
                    }
                }

                // Stage 3: Disk write consumers draining output queue and ordering disk writes
                for _ in 0..<max(2, workerCount) {
                    group.addTask {
                        do {
                            while let chunk = try await outputQueue.pop() {
                                if chunk.isEOF { break }
                                try await consumer.consume(chunk)
                            }
                        } catch {
                            inputQueue.cancel(error: error)
                            outputQueue.cancel(error: error)
                            consumer.cancel(error: error)
                            throw error
                        }
                    }
                }

                try await group.waitForAll()
            }
            try consumer.finish()
        } catch {
            inputQueue.cancel(error: error)
            outputQueue.cancel(error: error)
            consumer.cancel(error: error)
            throw error
        }

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(totalOriginalBytes) / (1024 * 1024)) / elapsed

        return PipelineStats(
            totalOriginalBytes: totalOriginalBytes,
            totalCompressedBytes: consumer.totalWrittenBytes,
            totalChunksProcessed: consumer.totalChunksProcessed,
            durationSeconds: elapsed,
            throughputMBs: throughput
        )
    }
}
