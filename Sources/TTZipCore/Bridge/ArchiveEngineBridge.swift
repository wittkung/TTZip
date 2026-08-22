// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
@_exported import CTTZipBridge

// MARK: - Native Microkernel Bridge

/// High-performance thin Swift bridge for format sniffing and natural string sorting.
public enum NativeMicrokernelBridge {
    
    /// Sniffs file format magic numbers in constant time (<1ns).
    public static func sniffMagic(data: Data) -> (kind: ttzip_file_kind_t, format: String, mime: String) {
        guard data.count >= 2 else {
            return (TTZIP_KIND_UNKNOWN, "UNKNOWN", "application/octet-stream")
        }
        return data.withUnsafeBytes { rawBuf in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return (TTZIP_KIND_UNKNOWN, "UNKNOWN", "application/octet-stream")
            }
            let len = rawBuf.count
            if len >= 4 && ptr[0] == 0x50 && ptr[1] == 0x4B && ptr[2] == 0x03 && ptr[3] == 0x04 {
                return (TTZIP_KIND_ARCHIVE, "ZIP", "application/zip")
            }
            if len >= 6 && ptr[0] == 0x37 && ptr[1] == 0x7A && ptr[2] == 0xBC && ptr[3] == 0xAF && ptr[4] == 0x27 && ptr[5] == 0x1C {
                return (TTZIP_KIND_ARCHIVE, "7Z", "application/x-7z-compressed")
            }
            if len >= 2 && ptr[0] == 0x1F && ptr[1] == 0x8B {
                return (TTZIP_KIND_ARCHIVE, "GZIP", "application/gzip")
            }
            if len >= 6 && ptr[0] == 0xFD && ptr[1] == 0x37 && ptr[2] == 0x7A && ptr[3] == 0x58 && ptr[4] == 0x5A && ptr[5] == 0x00 {
                return (TTZIP_KIND_ARCHIVE, "XZ", "application/x-xz")
            }
            if len >= 4 && ptr[0] == 0x28 && ptr[1] == 0xB5 && ptr[2] == 0x2F && ptr[3] == 0xFD {
                return (TTZIP_KIND_ARCHIVE, "ZSTD", "application/zstd")
            }
            if len >= 3 && ptr[0] == 0x42 && ptr[1] == 0x5A && ptr[2] == 0x68 {
                return (TTZIP_KIND_ARCHIVE, "BZIP2", "application/x-bzip2")
            }
            if len >= 7 && ptr[0] == 0x52 && ptr[1] == 0x61 && ptr[2] == 0x72 && ptr[3] == 0x21 && ptr[4] == 0x1A && ptr[5] == 0x07 {
                return (TTZIP_KIND_ARCHIVE, "RAR", "application/x-rar-compressed")
            }
            if len >= 8 && ptr[0] == 0x89 && ptr[1] == 0x50 && ptr[2] == 0x4E && ptr[3] == 0x43 && ptr[4] == 0x0D && ptr[5] == 0x0A && ptr[6] == 0x1A && ptr[7] == 0x0A {
                return (TTZIP_KIND_IMAGE, "PNG", "image/png")
            }
            if len >= 3 && ptr[0] == 0xFF && ptr[1] == 0xD8 && ptr[2] == 0xFF {
                return (TTZIP_KIND_IMAGE, "JPEG", "image/jpeg")
            }
            if len >= 6 && ptr[0] == 0x47 && ptr[1] == 0x49 && ptr[2] == 0x46 && ptr[3] == 0x38 && (ptr[4] == 0x37 || ptr[4] == 0x39) && ptr[5] == 0x61 {
                return (TTZIP_KIND_IMAGE, "GIF", "image/gif")
            }
            if len >= 4 && ptr[0] == 0x25 && ptr[1] == 0x50 && ptr[2] == 0x44 && ptr[3] == 0x46 {
                return (TTZIP_KIND_BINARY, "PDF", "application/pdf")
            }
            return (TTZIP_KIND_UNKNOWN, "BINARY", "application/octet-stream")
        }
    }
    
    /// Fast natural sort on paths.
    public static func naturalSort(_ paths: [String]) -> [String] {
        return paths.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Natural string comparator.
    public static func naturalCompare(_ a: String, _ b: String) -> ComparisonResult {
        return a.localizedStandardCompare(b)
    }
}

// MARK: - Implementor Protocol

/// Unified low-level archive engine implementor protocol (Implementor in Bridge Pattern).
public protocol ArchiveEngineImplementorProtocol: Sendable {
    var supportedFormat: ArchiveCompressionFormat { get }

    func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64

    func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64
}

internal func calculateDirectorySize(at path: String) -> Int64 {
    let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: path)
    return component.sizeBytes
}

// MARK: - Abstraction in Bridge Pattern

/// High-level archiving abstraction base class holding an `ArchiveEngineImplementorProtocol`.
open class ArchiveOperationAbstraction: @unchecked Sendable {
    private let lock = NSLock()
    private var _implementor: ArchiveEngineImplementorProtocol

    public var implementor: ArchiveEngineImplementorProtocol {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _implementor
        }
        set {
            lock.lock()
            _implementor = newValue
            lock.unlock()
        }
    }

    public init(implementor: ArchiveEngineImplementorProtocol) {
        self._implementor = implementor
    }

    @discardableResult
    public func setImplementor(_ newImplementor: ArchiveEngineImplementorProtocol) -> Self {
        lock.lock()
        _implementor = newImplementor
        lock.unlock()
        return self
    }

    open func compress(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> Int64 {
        let currentImpl = implementor
        return try await currentImpl.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )
    }

    open func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> Int64 {
        let currentImpl = implementor
        return try await currentImpl.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }
}

/// Refined archiving pipeline abstraction measuring performance metrics.
open class AdvancedArchiveOperationPipelineAbstraction: ArchiveOperationAbstraction, @unchecked Sendable {
    open func compressWithMetrics(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> (bytesWritten: Int64, durationSeconds: Double, throughputMBs: Double) {
        let startTime = Date()
        let bytes = try await compress(inputPaths: inputPaths, outputPath: outputPath, options: options)
        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytes) / 1024.0 / 1024.0) / elapsed
        return (bytesWritten: bytes, durationSeconds: elapsed, throughputMBs: throughput)
    }

    open func extractWithMetrics(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions = .defaultOptions
    ) async throws -> (bytesExtracted: Int64, durationSeconds: Double, throughputMBs: Double) {
        let startTime = Date()
        let bytes = try await extract(archivePath: archivePath, destinationDir: destinationDir, options: options)
        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(bytes) / 1024.0 / 1024.0) / elapsed
        return (bytesExtracted: bytes, durationSeconds: elapsed, throughputMBs: throughput)
    }
}

// MARK: - Concrete Implementors

/// Bridge implementor for ZIP archives.
public final class ZipEngineBridgeImplementor: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    public let supportedFormat: ArchiveCompressionFormat = .zip

    public init() {}

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter()
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
        let extractor = ArchiveExtractor()
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

    public init() {}

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter()
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
        let extractor = ArchiveExtractor()
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

    public init() {}

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveWriter()
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
        let extractor = ArchiveExtractor()
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

    public init() {}

    public func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let writer = ArchiveEngineFactory.makeWriter(for: .tar)
        try writer.createArchiveSync(
            outputPath: outputPath,
            format: .tar,
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
        let extractor = ArchiveEngineFactory.makeExtractor(for: .tar)
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: .defaultClean,
            advancedOptions: options
        )
        return calculateDirectorySize(at: destinationDir)
    }
}

/// Bridge implementor for Unified Rust Engine (High-performance safe Rust C-ABI).
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

// MARK: - ArchiveEngineBridge Factory

public enum ArchiveEngineBridge {
    public static func makeImplementor(for format: ArchiveCompressionFormat = .zip) -> ArchiveEngineImplementorProtocol {
        switch format {
        case .zip:
            return ZipEngineBridgeImplementor()
        case .sevenZip:
            return SevenZipEngineBridgeImplementor()
        case .zst:
            return ZstdEngineBridgeImplementor()
        default:
            return RustUnifiedArchiveEngineBridgeImplementor(format: format)
        }
    }
}
