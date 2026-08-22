// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Pipeline compositor synthesizing orthogonal combinations of containers and stream filters.
public enum ArchivePipelineCompositor: Sendable {
    
    /// Composes container and stream filter into pipeline configuration.
    public static func compose(
        container: ArchiveContainerFormat,
        filter: ArchiveStreamFilter = .none
    ) -> ArchivePipelineComposition {
        let isFastPath = isFastPathSupported(container: container, filter: filter)
        let ext = formatExtension(container: container, filter: filter)
        let name = formatDisplayName(container: container, filter: filter)
        
        return ArchivePipelineComposition(
            container: container,
            filter: filter,
            supportsFastPathBypass: isFastPath,
            displayName: name,
            primaryFileExtension: ext
        )
    }
    
    /// Decomposes file path suffix into container format and stream filter.
    public static func decompose(filePath: String) -> ArchivePipelineComposition {
        let lower = filePath.lowercased()
        
        // 1. Compound extension matching
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            return compose(container: .tar, filter: .gzip)
        }
        if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".tbz") {
            return compose(container: .tar, filter: .bzip2)
        }
        if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") {
            return compose(container: .tar, filter: .xz)
        }
        if lower.hasSuffix(".tar.zst") || lower.hasSuffix(".tzst") {
            return compose(container: .tar, filter: .zstd)
        }
        if lower.hasSuffix(".tar.lz4") {
            return compose(container: .tar, filter: .lz4)
        }
        if lower.hasSuffix(".tar.br") {
            return compose(container: .tar, filter: .brotli)
        }
        if lower.hasSuffix(".tar.lz") {
            return compose(container: .tar, filter: .lzip)
        }
        if lower.hasSuffix(".tar.lrz") {
            return compose(container: .tar, filter: .lrzip)
        }
        
        // 2. Single container extension matching
        if lower.hasSuffix(".zip") || lower.hasSuffix(".zipx") {
            return compose(container: .zip, filter: .none)
        }
        if lower.hasSuffix(".7z") {
            return compose(container: .sevenZip, filter: .none)
        }
        if lower.hasSuffix(".tar") {
            return compose(container: .tar, filter: .none)
        }
        if lower.hasSuffix(".cpio") {
            return compose(container: .cpio, filter: .none)
        }
        if lower.hasSuffix(".a") || lower.hasSuffix(".ar") {
            return compose(container: .ar, filter: .none)
        }
        if lower.hasSuffix(".iso") {
            return compose(container: .iso, filter: .none)
        }
        if lower.hasSuffix(".wim") {
            return compose(container: .wim, filter: .none)
        }
        
        // 3. Raw stream filter matching
        if lower.hasSuffix(".gz") {
            return compose(container: .raw, filter: .gzip)
        }
        if lower.hasSuffix(".bz2") {
            return compose(container: .raw, filter: .bzip2)
        }
        if lower.hasSuffix(".xz") {
            return compose(container: .raw, filter: .xz)
        }
        if lower.hasSuffix(".zst") {
            return compose(container: .raw, filter: .zstd)
        }
        if lower.hasSuffix(".lz4") {
            return compose(container: .raw, filter: .lz4)
        }
        if lower.hasSuffix(".br") {
            return compose(container: .raw, filter: .brotli)
        }
        if lower.hasSuffix(".lz") {
            return compose(container: .raw, filter: .lzip)
        }
        if lower.hasSuffix(".lrz") {
            return compose(container: .raw, filter: .lrzip)
        }
        
        return compose(container: .zip, filter: .none)
    }
    
    /// Determines whether combination supports native hardware-accelerated Fast-Path bypass.
    @inlinable
    public static func isFastPathSupported(
        container: ArchiveContainerFormat,
        filter: ArchiveStreamFilter
    ) -> Bool {
        switch (container, filter) {
        case (.zip, .none):
            return true // ZipParallelExtractor / ZipParallelWriter
        case (.sevenZip, .none):
            return true // SevenZipEngine ARM NEON
        case (.tar, .zstd):
            return true // ttzip_tar_zstd_direct
        case (.tar, .none):
            return true // ttzip_create_tar_direct_c
        default:
            return false
        }
    }
    
    private static func formatExtension(container: ArchiveContainerFormat, filter: ArchiveStreamFilter) -> String {
        if container == .raw {
            return filter.filterExtension ?? "raw"
        }
        if filter == .none {
            return container.defaultExtension
        }
        return "\(container.defaultExtension).\(filter.filterExtension ?? "")"
    }
    
    private static func formatDisplayName(container: ArchiveContainerFormat, filter: ArchiveStreamFilter) -> String {
        if container == .raw {
            return (filter.filterExtension ?? "RAW").uppercased()
        }
        if filter == .none {
            return container.rawValue.uppercased()
        }
        return "\(container.rawValue.uppercased()) + \(filter.rawValue.uppercased())"
    }
}

// MARK: - Container Format

//
//


/// Archive container format defining directory structures and metadata headers.
public enum ArchiveContainerFormat: String, Sendable, CaseIterable, Codable {
    case zip
    case sevenZip = "7z"
    case tar
    case cpio
    case ar
    case iso
    case wim
    case raw
    
    /// Default primary file extension.
    public var defaultExtension: String {
        switch self {
        case .zip: return "zip"
        case .sevenZip: return "7z"
        case .tar: return "tar"
        case .cpio: return "cpio"
        case .ar: return "a"
        case .iso: return "iso"
        case .wim: return "wim"
        case .raw: return "raw"
        }
    }
}

/// Stream compression and encoding filter.
public enum ArchiveStreamFilter: String, Sendable, CaseIterable, Codable {
    case none
    case gzip
    case bzip2
    case xz
    case zstd
    case lz4
    case brotli
    case lzip
    case lrzip
    
    /// File extension associated with stream filter.
    public var filterExtension: String? {
        switch self {
        case .none: return nil
        case .gzip: return "gz"
        case .bzip2: return "bz2"
        case .xz: return "xz"
        case .zstd: return "zst"
        case .lz4: return "lz4"
        case .brotli: return "br"
        case .lzip: return "lz"
        case .lrzip: return "lrz"
        }
    }
}

/// Orthogonal combination of container format and stream filter.
public struct ArchivePipelineComposition: Sendable, Codable, Equatable {
    public let container: ArchiveContainerFormat
    public let filter: ArchiveStreamFilter
    public let supportsFastPathBypass: Bool
    public let displayName: String
    public let primaryFileExtension: String
    
    public init(
        container: ArchiveContainerFormat,
        filter: ArchiveStreamFilter,
        supportsFastPathBypass: Bool,
        displayName: String,
        primaryFileExtension: String
    ) {
        self.container = container
        self.filter = filter
        self.supportsFastPathBypass = supportsFastPathBypass
        self.displayName = displayName
        self.primaryFileExtension = primaryFileExtension
    }
}

// MARK: - TTZip Status

//
//


/// Unified 6-level archive operation status code hierarchy matching libarchive standard (`archive.h`).
public enum TTZipStatus: Int32, Sendable, Codable, Equatable {
    /// End of archive reached (`ARCHIVE_EOF`).
    case eof = 1
    
    /// Operation succeeded (`ARCHIVE_OK`).
    case ok = 0
    
    /// Transient retry requested (`ARCHIVE_RETRY`).
    case retry = -10
    
    /// Non-fatal warning (`ARCHIVE_WARN`).
    case warn = -20
    
    /// Non-fatal entry error with possible stream recovery (`ARCHIVE_FAILED`).
    case failed = -25
    
    /// Fatal unrecoverable error (`ARCHIVE_FATAL`).
    case fatal = -30
    
    public var isFatal: Bool {
        return self == .fatal
    }
    
    public var allowsDataRecovery: Bool {
        return self == .warn || self == .failed
    }
}

/// Archive engine internal lifecycle state machine flags.
public struct TTZipEngineState: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let initial      = TTZipEngineState(rawValue: 1 << 0) // New handle
    public static let header       = TTZipEngineState(rawValue: 1 << 1) // Reading/writing entry header
    public static let data         = TTZipEngineState(rawValue: 1 << 2) // Reading/writing payload data
    public static let dataRecovery = TTZipEngineState(rawValue: 1 << 3) // Skipping damaged blocks in recovery mode
    public static let eof          = TTZipEngineState(rawValue: 1 << 4) // End of archive reached
    public static let closed       = TTZipEngineState(rawValue: 1 << 5) // Handle safely closed
    public static let fatalError   = TTZipEngineState(rawValue: 1 << 15) // Fatal error lock
}

// MARK: - Operation Pipeline

//
//


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
