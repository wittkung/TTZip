// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - ArchiveReading Default Implementations & Extensions

extension ArchiveReading {
    public func inspect(archivePath: String, password: String?) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
    }
    
    public func inspectTree(archivePath: String, password: String? = nil, candidatePasswords: [String]? = nil) async throws -> ArchiveCompositeDirectory {
        let entries = try await inspect(archivePath: archivePath, password: password, candidatePasswords: candidatePasswords)
        return ArchiveComponentTreeBuilder.buildTree(from: entries)
    }
    
    public func probeEncryption(archivePath: String) async throws -> ArchiveEncryptionTier {
        do {
            let entries = try await inspect(archivePath: archivePath, password: nil, candidatePasswords: nil)
            if entries.isEmpty {
                return .none
            }
            let hasEncrypted = entries.contains { $0.isEncrypted }
            return hasEncrypted ? .dataOnly : .none
        } catch let error as ArchiveError {
            switch error {
            case .passwordRequired, .passwordRequiredDetailed(_, .headerAndData):
                return .headerAndData
            case .passwordRequiredDetailed(_, .dataOnly):
                return .dataOnly
            default:
                throw error
            }
        } catch {
            throw error
        }
    }
}

// MARK: - ArchiveWriting Default Implementations & Extensions

extension ArchiveWriting {
    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        try await createArchive(
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
    }

    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        try createArchiveSync(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )
    }

    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        components: [ArchiveComponentProtocol],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        let inputPaths = components.map { $0.path }
        try await createArchive(
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
    }

    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        components: [ArchiveComponentProtocol],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        let inputPaths = components.map { $0.path }
        try createArchiveSync(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )
    }
}

// MARK: - ArchiveExtracting Default Implementations & Extensions

extension ArchiveExtracting {
    public func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool {
        if let extractor = self as? ArchiveExtractor {
            return extractor.joinSplitVolumes(firstVolumePath: firstVolumePath, outputPath: outputPath)
        }
        return false
    }

    public func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws {
        try await extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        )
    }

    public func extractSingleFile(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        if let extractor = self as? ArchiveExtractor {
            try await extractor.extractSingleFile(
                archivePath: archivePath,
                entryPath: entryPath,
                destinationDir: destinationDir,
                password: password
            )
        } else {
            try await extract(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: .defaultClean,
                password: password,
                advancedOptions: nil
            )
        }
    }

    public func extractSync(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) throws {
        if let extractor = self as? ArchiveExtractor {
            try extractor.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: options,
                password: password,
                advancedOptions: advancedOptions
            )
        } else {
            let extractor = ArchiveEngineFactory.makeExtractor()
            try extractor.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: options,
                password: password,
                advancedOptions: advancedOptions
            )
        }
    }
}

// MARK: - ArchiveIntegrityChecking Default Implementations & Extensions

extension ArchiveIntegrityChecking {
    @discardableResult
    public func verifyExtractedDirectory(
        directoryPath: String,
        expectedOriginalBytes: Int64,
        sourceFilePath: String? = nil,
        sourceCRC32: String? = nil,
        label: String = "Verification"
    ) -> (isValid: Bool, totalExtractedBytes: Int64, crc32: String?) {
        return verifyExtractedDirectory(
            directoryPath: directoryPath,
            expectedOriginalBytes: expectedOriginalBytes,
            sourceFilePath: sourceFilePath,
            sourceCRC32: sourceCRC32,
            label: label
        )
    }
}
