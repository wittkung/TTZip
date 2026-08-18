// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unified low-level archive engine implementor protocol (Implementor in Bridge Pattern).
///
/// Decouples high-level archiving orchestration from concrete algorithm implementations.
public protocol ArchiveEngineImplementorProtocol: Sendable {
    /// Supported compression format.
    var supportedFormat: ArchiveCompressionFormat { get }

    /// Stream-compresses input paths into an archive file.
    /// - Parameters:
    ///   - inputPaths: List of target input files or directories.
    ///   - outputPath: Target output archive path.
    ///   - options: Advanced archive options.
    /// - Returns: Total written bytes (Int64).
    func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64

    /// Stream-extracts archive contents into destination directory.
    /// - Parameters:
    ///   - archivePath: Source archive path.
    ///   - destinationDir: Target extraction directory path.
    ///   - options: Advanced archive options.
    /// - Returns: Total extracted uncompressed bytes (Int64).
    func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64
}

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

// MARK: - Helper Functions

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

    /// Dynamically switches the underlying implementor.
    @discardableResult
    public func setImplementor(_ newImplementor: ArchiveEngineImplementorProtocol) -> Self {
        lock.lock()
        _implementor = newImplementor
        lock.unlock()
        return self
    }

    /// High-level unified compression orchestration.
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

    /// High-level unified extraction orchestration.
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
    /// Executes compression and captures detailed throughput metrics.
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

    /// Executes extraction and captures detailed throughput metrics.
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
