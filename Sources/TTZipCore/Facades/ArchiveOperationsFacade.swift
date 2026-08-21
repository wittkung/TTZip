// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Operations Facading Protocol

/// Unified facade protocol encapsulating high-level synchronous and asynchronous archive operations.
public protocol ArchiveOperationsFacading: Sendable {
    func compress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String?,
        splitSize: Int64?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ArchiveOperationResult
    
    func extract(
        archivePath: String,
        destinationDir: String,
        password: String?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> Double
    
    func inspect(
        archivePath: String,
        password: String?
    ) async throws -> [ArchiveEntry]
    
    func testIntegrity(
        archivePath: String,
        password: String?
    ) async throws -> HashVerificationResult
    
    func repair(
        damagedPath: String,
        outputPath: String
    ) async throws -> Int
}

// MARK: - Archive Operations Facade Implementation

/// Concrete operations facade delegating to the unified TTZip engine and specialized subsystem engines.
public final class ArchiveOperationsFacade: ArchiveOperationsFacading, @unchecked Sendable {
    public static let shared = ArchiveOperationsFacade()
    
    private let engineFacade: TTZipEngineFacading
    
    public init(engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared) {
        self.engineFacade = engineFacade
    }
    
    public func compress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        return try await engineFacade.quickCompress(
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            progress: progress
        )
    }
    
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> Double {
        let res = try await engineFacade.quickExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            autoVaultUnlock: true,
            progress: progress
        )
        return res.durationSeconds
    }
    
    public func inspect(
        archivePath: String,
        password: String? = nil
    ) async throws -> [ArchiveEntry] {
        let result = try await engineFacade.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: true
        )
        return result.entries
    }
    
    public func testIntegrity(
        archivePath: String,
        password: String? = nil
    ) async throws -> HashVerificationResult {
        return try await engineFacade.verifyIntegrity(archivePath: archivePath)
    }
    
    public func repair(
        damagedPath: String,
        outputPath: String
    ) async throws -> Int {
        return try await engineFacade.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
    }
}
