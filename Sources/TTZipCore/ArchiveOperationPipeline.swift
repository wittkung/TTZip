// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type representing metrics and outputs from an archive creation workflow.
public struct ArchiveOperationResult: Sendable {
    public let outputPath: String
    public let originalBytes: Int64
    public let compressedBytes: Int64
    public let durationSeconds: Double
    public let throughputMBs: Double

    public init(
        outputPath: String,
        originalBytes: Int64,
        compressedBytes: Int64,
        durationSeconds: Double,
        throughputMBs: Double
    ) {
        self.outputPath = outputPath
        self.originalBytes = originalBytes
        self.compressedBytes = compressedBytes
        self.durationSeconds = durationSeconds
        self.throughputMBs = throughputMBs
    }
}

/// Unified archiving pipeline coordinating creation, extraction, and throughput calculations.
public final class ArchiveOperationPipeline: Sendable {
    public let writer: ArchiveWriting
    public let extractor: ArchiveExtracting

    public init(
        writer: ArchiveWriting = ArchiveEngineFactory.makeWriter(),
        extractor: ArchiveExtracting = ArchiveEngineFactory.makeExtractor()
    ) {
        self.writer = writer
        self.extractor = extractor
    }

    /// Executes unified archive creation workflow and computes real-time performance metrics.
    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .sevenZip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        let startTime = Date()

        try await writer.createArchive(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password,
            advancedOptions: advancedOptions ?? ArchiveAdvancedOptions(),
            progressHandler: progress
        )

        let duration = max(0.001, Date().timeIntervalSince(startTime))
        let totalOriginalBytes = inputPaths.reduce(Int64(0)) { $0 + calculateDirectorySize(at: $1) }
        let writtenBytes = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64) ?? totalOriginalBytes
        let throughput = Double(totalOriginalBytes) / (1024.0 * 1024.0 * duration)

        return ArchiveOperationResult(
            outputPath: outputPath,
            originalBytes: totalOriginalBytes,
            compressedBytes: writtenBytes,
            durationSeconds: duration,
            throughputMBs: throughput
        )
    }

    /// Executes unified archive extraction workflow.
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        format: ArchiveCompressionFormat = .sevenZip,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        let startTime = Date()

        try await extractor.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        )

        let duration = max(0.001, Date().timeIntervalSince(startTime))
        let extractedBytes = calculateDirectorySize(at: destinationDir)
        let throughput = Double(extractedBytes) / (1024.0 * 1024.0 * duration)

        return ArchiveOperationResult(
            outputPath: destinationDir,
            originalBytes: extractedBytes,
            compressedBytes: extractedBytes,
            durationSeconds: duration,
            throughputMBs: throughput
        )
    }
}
