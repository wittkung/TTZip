// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Streaming Facading Protocol

/// Unified facade protocol encapsulating chunked, stream-based, and pipe archiving operations.
public protocol ArchiveStreamingFacading: Sendable {
    func streamCompressFile(
        sourcePath: String,
        destinationPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ArchiveOperationResult
    
    func streamDecompressFile(
        sourcePath: String,
        destinationPath: String,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> Double
}

// MARK: - Archive Streaming Facade Implementation

/// Concrete streaming facade delegating to underlying zero-copy streaming adapters and parallel pipes.
public final class ArchiveStreamingFacade: ArchiveStreamingFacading, @unchecked Sendable {
    public static let shared = ArchiveStreamingFacade()
    
    private let operationsFacade: ArchiveOperationsFacading
    
    public init(operationsFacade: ArchiveOperationsFacading = ArchiveOperationsFacade.shared) {
        self.operationsFacade = operationsFacade
    }
    
    public func streamCompressFile(
        sourcePath: String,
        destinationPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        return try await operationsFacade.compress(
            inputs: [sourcePath],
            outputPath: destinationPath,
            format: format,
            level: level,
            password: nil,
            splitSize: nil,
            progress: progress
        )
    }
    
    public func streamDecompressFile(
        sourcePath: String,
        destinationPath: String,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> Double {
        return try await operationsFacade.extract(
            archivePath: sourcePath,
            destinationDir: destinationPath,
            password: nil,
            progress: progress
        )
    }
}
