// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type encapsulating archive operation performance measurements.
public struct PerformanceMetrics: Sendable, Equatable {
    public let bytesProcessed: Int64
    public let durationSeconds: Double
    public let throughputMBs: Double

    public init(bytesProcessed: Int64, durationSeconds: Double, throughputMBs: Double) {
        self.bytesProcessed = bytesProcessed
        self.durationSeconds = durationSeconds
        self.throughputMBs = throughputMBs
    }
}

/// Concrete decorator measuring execution duration, processed byte count, and throughput (MB/s).
open class PerformanceMetricsDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastCompressMetrics: PerformanceMetrics?
    private var _lastExtractMetrics: PerformanceMetrics?

    public var lastCompressMetrics: PerformanceMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return _lastCompressMetrics
    }

    public var lastExtractMetrics: PerformanceMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return _lastExtractMetrics
    }

    private func updateCompressMetrics(_ metrics: PerformanceMetrics) {
        lock.lock()
        _lastCompressMetrics = metrics
        lock.unlock()
    }

    private func updateExtractMetrics(_ metrics: PerformanceMetrics) {
        lock.lock()
        _lastExtractMetrics = metrics
        lock.unlock()
    }

    public override init(inner: ArchiveEngineImplementorProtocol) {
        super.init(inner: inner)
    }

    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let startTime = Date()

        let bytesWritten = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytesWritten) / 1024.0 / 1024.0) / elapsed

        let metrics = PerformanceMetrics(
            bytesProcessed: bytesWritten,
            durationSeconds: elapsed,
            throughputMBs: throughput
        )

        updateCompressMetrics(metrics)

        TTLogger.debug(String(format: "[PerformanceMetricsDecorator] Compression: wrote %lld B, duration %.3fs, throughput %.2f MB/s", bytesWritten, elapsed, throughput))

        return bytesWritten
    }

    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let startTime = Date()

        let bytesExtracted = try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytesExtracted) / 1024.0 / 1024.0) / elapsed

        let metrics = PerformanceMetrics(
            bytesProcessed: bytesExtracted,
            durationSeconds: elapsed,
            throughputMBs: throughput
        )

        updateExtractMetrics(metrics)

        TTLogger.debug(String(format: "[PerformanceMetricsDecorator] Extraction: extracted %lld B, duration %.3fs, throughput %.2f MB/s", bytesExtracted, elapsed, throughput))

        return bytesExtracted
    }
}
