// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Base decorator in the Decorator Pattern for archive operations.
///
/// Implements `ArchiveEngineImplementorProtocol` and forwards operations to the inner component.
open class ArchiveOperationDecorator: ArchiveEngineImplementorProtocol, @unchecked Sendable {
    /// Wrapped inner implementor or decorator.
    public var inner: ArchiveEngineImplementorProtocol

    public init(inner: ArchiveEngineImplementorProtocol) {
        self.inner = inner
    }

    /// Supported archive format forwarded to the inner component.
    open var supportedFormat: ArchiveCompressionFormat {
        return inner.supportedFormat
    }

    /// Base compression stream forwarding.
    open func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        return try await inner.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )
    }

    /// Base extraction stream forwarding.
    open func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        return try await inner.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }
}

// MARK: - Fluent Chaining API

extension ArchiveEngineImplementorProtocol {
    /// Decorates the engine with transparent encryption / decryption capabilities.
    public func withEncryption(password: String?) -> EncryptionDecorator {
        return EncryptionDecorator(inner: self, password: password)
    }

    /// Decorates the engine with progress monitoring and ETA tracking.
    public func withProgressMonitoring(
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) -> ProgressMonitoringDecorator {
        return ProgressMonitoringDecorator(inner: self, progressHandler: progressHandler)
    }

    /// Decorates the engine with split-volume management.
    public func withSplitVolume(splitVolumeSizeBytes: Int64?) -> SplitVolumeDecorator {
        return SplitVolumeDecorator(inner: self, splitVolumeSizeBytes: splitVolumeSizeBytes)
    }

    /// Decorates the engine with checksum verification (CRC-32 / SHA-256).
    public func withChecksumVerification(algorithm: HashType = .crc32) -> ChecksumVerificationDecorator {
        return ChecksumVerificationDecorator(inner: self, algorithm: algorithm)
    }

    /// Decorates the engine with throughput and timing metrics collection.
    public func withPerformanceMetrics() -> PerformanceMetricsDecorator {
        return PerformanceMetricsDecorator(inner: self)
    }
}
