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
        familyFactory: ArchiveEngineFamilyFactoryProtocol
    ) {
        self.writer = familyFactory.makeWriter()
        self.extractor = familyFactory.makeExtractor()
    }

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
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        let startTime = Date()

        // Estimate original uncompressed byte size via Composite Pattern
        var totalOrigBytes: Int64 = 0
        for p in inputPaths {
            let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: p)
            totalOrigBytes += component.sizeBytes
        }

        try await writer.createArchive(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        let compressedSize = (attr?[.size] as? Int64) ?? 0
        let rate = (Double(totalOrigBytes) / 1024.0 / 1024.0) / elapsed

        return ArchiveOperationResult(
            outputPath: outputPath,
            originalBytes: totalOrigBytes,
            compressedBytes: compressedSize,
            durationSeconds: elapsed,
            throughputMBs: rate
        )
    }

    /// Convenience overload executing archive creation via `ArchiveOptionsBuilder`.
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        optionsBuilder: ArchiveOptionsBuilder,
        filterOptions: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        return try await createArchive(
            outputPath: outputPath,
            format: optionsBuilder.format ?? .sevenZip,
            level: optionsBuilder.level ?? .normal,
            inputPaths: inputPaths,
            options: filterOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: optionsBuilder.password,
            advancedOptions: optionsBuilder.build(),
            progressHandler: progressHandler
        )
    }

    /// Executes archive extraction workflow and records duration.
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws -> Double {
        let startTime = Date()

        try await extractor.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        )

        return max(0.001, Date().timeIntervalSince(startTime))
    }
}
