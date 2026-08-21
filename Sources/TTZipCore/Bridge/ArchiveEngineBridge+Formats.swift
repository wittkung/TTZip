// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// MARK: - Concrete Implementors

/// Bridge implementor for ZIP archives.
public final class ZipEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .zip
    public let zipEngine: ZipEngineProtocol

    public init(zipEngine: ZipEngineProtocol = NativeZipEngine.shared) {
        self.zipEngine = zipEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter(zipEngine: zipEngine)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zip,
            level: .normal,
            inputPaths: inputPaths,
            options: .defaultClean,
            advancedOptions: options
        )
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let extractor = ArchiveEngineFactory.makeExtractor(for: .zip)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// Bridge implementor for 7z archives.
public final class SevenZipEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .sevenZip
    public let sevenZipEngine: SevenZipEngineProtocol

    public init(sevenZipEngine: SevenZipEngineProtocol = SevenZipParallelWriter.shared) {
        self.sevenZipEngine = sevenZipEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter(sevenZipEngine: sevenZipEngine)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .sevenZip,
            level: .normal,
            inputPaths: inputPaths,
            options: .defaultClean,
            advancedOptions: options
        )
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let extractor = ArchiveEngineFactory.makeExtractor(for: .sevenZip)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// Bridge implementor for Zstandard (.zst) archives.
public final class ZstdEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .zst
    public let zstdEngine: ZstdEngineProtocol

    public init(zstdEngine: ZstdEngineProtocol = NativeZstdEngine.shared) {
        self.zstdEngine = zstdEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter(zstdEngine: zstdEngine)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .zst,
            level: .normal,
            inputPaths: inputPaths,
            options: .defaultClean,
            advancedOptions: options
        )
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let extractor = ArchiveEngineFactory.makeExtractor(for: .zst)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// Bridge implementor for POSIX TAR archives.
public final class TarEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .tar
    public let tarEngine: POSIXTarEngineProtocol

    public init(tarEngine: POSIXTarEngineProtocol = POSIXTarCAdapter.shared) {
        self.tarEngine = tarEngine
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let success = try tarEngine.createTar(outputPath: outputPath, inputPaths: inputPaths, workingDirectory: nil)
        if !success {
            let writer = ArchiveEngineFactory.makeWriter(for: .tar)
            try writer.createArchiveSync(
                outputPath: outputPath,
                format: .tar,
                level: .normal,
                inputPaths: inputPaths,
                options: .defaultClean,
                advancedOptions: options
            )
        }
        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let success = try tarEngine.extractTar(archivePath: archivePath, destinationDir: destinationDir)
        if !success {
            let extractor = ArchiveEngineFactory.makeExtractor(for: .tar)
            try extractor.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: .defaultClean,
                advancedOptions: options
            )
        }
        return calculateDirectorySize(at: destinationDir)
    }
}

/// Bridge implementor for Unified Rust Engine (US4 - High-performance safe Rust C-ABI).
public final class RustUnifiedArchiveEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat

    public init(format: ArchiveCompressionFormat = .zip) {
        self.supportedFormat = format
    }

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let rustFormat: TTZipArchiveFormat
        switch supportedFormat {
        case .zip: rustFormat = TTZIP_ARCHIVE_FORMAT_ZIP
        case .sevenZip: rustFormat = TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP
        case .tar: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR
        case .tarGz: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR_GZ
        case .tarBz2: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR_BZ2
        case .tarXz: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR_XZ
        case .tarZst, .zst: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR_ZSTD
        default: rustFormat = TTZIP_ARCHIVE_FORMAT_ZIP
        }

        var createOptions = TTZipCreateOptions(
            format: rustFormat,
            level: TTZIP_COMPRESSION_LEVEL_NORMAL,
            encryption: TTZIP_ENCRYPTION_NONE,
            password: nil,
            thread_budget: UInt32(options.cpuThreads > 0 ? options.cpuThreads : 4),
            solid_block_size_mb: 0,
            progress_callback: nil,
            user_data: nil
        )

        let status = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
            CUnsafeBufferAdapter.withCString(outputPath) { outPtr in
                guard let outPtr = outPtr else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                return ttzip_rust_create_archive(
                    cInputPaths,
                    inputPaths.count,
                    outPtr,
                    &createOptions
                )
            }
        }

        guard status == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: status.rawValue)
        }

        let attr = try? FileManager.default.attributesOfItem(atPath: outputPath)
        return (attr?[.size] as? Int64) ?? 0
    }

    public func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        var extractOptions = TTZipExtractOptions(
            destination_path: nil,
            password: nil,
            thread_budget: UInt32(options.cpuThreads > 0 ? options.cpuThreads : 4),
            overwrite_existing: true,
            preserve_permissions: true,
            dry_run: false,
            progress_callback: nil,
            user_data: nil
        )

        let status = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
            CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                guard let aPtr = aPtr, let dPtr = dPtr else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                extractOptions.destination_path = dPtr
                return ttzip_rust_extract_archive(
                    aPtr,
                    dPtr,
                    &extractOptions
                )
            }
        }

        guard status == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: status.rawValue)
        }

        return calculateDirectorySize(at: destinationDir)
    }
}
