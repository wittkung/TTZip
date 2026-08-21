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
