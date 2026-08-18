// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Concrete decorator adding smooth progress notifications and ETA estimates.
open class ProgressMonitoringDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    private let lock = NSLock()
    private var startTime: Date?
    
    public init(
        inner: ArchiveEngineImplementorProtocol,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) {
        self.progressHandler = progressHandler
        super.init(inner: inner)
    }

    private func recordStartTime(_ time: Date) {
        lock.lock()
        startTime = time
        lock.unlock()
    }

    private func getStartTime() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return startTime ?? Date()
    }

    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let now = Date()
        recordStartTime(now)

        reportProgress(fraction: 0.05, statusMessage: "Preparing input files...", totalBytes: 0, processedBytes: 0)

        let estimatedTotalBytes = calculateTotalInputSize(inputPaths: inputPaths)

        reportProgress(fraction: 0.15, statusMessage: "Streaming compression in progress...", totalBytes: estimatedTotalBytes, processedBytes: 0)

        let resultBytes = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        let duration = Date().timeIntervalSince(now)
        let throughput = duration > 0 ? (Double(resultBytes) / 1024.0 / 1024.0) / duration : 0

        reportProgress(
            fraction: 1.0,
            statusMessage: String(format: "Compression completed (duration %.2fs, throughput %.1f MB/s)", duration, throughput),
            totalBytes: estimatedTotalBytes,
            processedBytes: resultBytes
        )

        return resultBytes
    }

    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let now = Date()
        recordStartTime(now)

        let archiveSize = (try? FileManager.default.attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0

        reportProgress(fraction: 0.10, statusMessage: "Reading archive metadata...", totalBytes: archiveSize, processedBytes: 0)

        let extractedBytes = try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )

        let duration = Date().timeIntervalSince(now)
        let throughput = duration > 0 ? (Double(extractedBytes) / 1024.0 / 1024.0) / duration : 0

        reportProgress(
            fraction: 1.0,
            statusMessage: String(format: "Extraction completed (duration %.2fs, throughput %.1f MB/s)", duration, throughput),
            totalBytes: extractedBytes,
            processedBytes: extractedBytes
        )

        return extractedBytes
    }

    private func reportProgress(
        fraction: Double,
        statusMessage: String,
        totalBytes: Int64,
        processedBytes: Int64
    ) {
        guard let handler = progressHandler else { return }

        let start = getStartTime()
        let elapsed = max(0.001, Date().timeIntervalSince(start))
        let speedBytesPerSec = elapsed > 0 ? Double(processedBytes) / elapsed : 0.0

        let progressState: ArchiveProgress.State = (fraction >= 1.0) ? .completed : .processing
        let progress = ArchiveProgress(
            state: progressState,
            bytesProcessed: processedBytes,
            totalBytes: max(processedBytes, totalBytes),
            currentFileName: statusMessage,
            throughputMBs: speedBytesPerSec / 1024.0 / 1024.0
        )
        handler(progress)
    }

    private func calculateTotalInputSize(inputPaths: [String]) -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        for path in inputPaths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            if !isDir.boolValue {
                if let attr = try? fm.attributesOfItem(atPath: path), let size = attr[.size] as? Int64 {
                    total += size
                }
            } else {
                if let enumerator = fm.enumerator(atPath: path) {
                    while let subpath = enumerator.nextObject() as? String {
                        let fullPath = (path as NSString).appendingPathComponent(subpath)
                        if let attr = try? fm.attributesOfItem(atPath: fullPath), let size = attr[.size] as? Int64 {
                            total += size
                        }
                    }
                }
            }
        }
        return total
    }
}
