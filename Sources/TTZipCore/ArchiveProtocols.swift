// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 3-Tier archive encryption classification topology.
public enum ArchiveEncryptionTier: String, Sendable, Codable, Equatable {
    /// Tier 0: Unencrypted archive.
    case none = "NONE"
    /// Tier 1: Entry payloads are encrypted, but metadata headers remain in cleartext (browsable without password).
    case dataOnly = "DATA_ONLY"
    /// Tier 2: Both metadata headers and entry payloads are encrypted (password required to list directory tree).
    case headerAndData = "HEADER_AND_DATA"
    /// Encryption status cannot be reliably determined or is unsupported.
    case unsupported = "UNSUPPORTED"
}

/// Core archive inspection and metadata discovery interface.
public protocol ArchiveReading: Sendable {
    /// Inspects archive contents and returns a flat array of archive entries.
    func inspect(archivePath: String) async throws -> [ArchiveEntry]
    
    /// Inspects archive contents with optional password or candidate password list.
    func inspect(archivePath: String, password: String?, candidatePasswords: [String]?) async throws -> [ArchiveEntry]
    
    /// Asynchronously inspects archive and returns a hierarchical directory tree (Composite Pattern).
    func inspectTree(archivePath: String, password: String?, candidatePasswords: [String]?) async throws -> ArchiveCompositeDirectory
    
    /// Fast zero-decompression probe of archive encryption tier.
    func probeEncryption(archivePath: String) async throws -> ArchiveEncryptionTier
}

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

/// Core archive creation and compression engine interface.
public protocol ArchiveWriting: Sendable {
    func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws

    func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        password: String?,
        splitVolumeSizeBytes: Int64?,
        advancedOptions: ArchiveAdvancedOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws
}

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

/// Core archive decompression and extraction engine interface.
public protocol ArchiveExtracting: Sendable {
    func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions?
    ) async throws

    func extractSingleFile(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String?
    ) async throws
    
    func extractSync(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions?
    ) throws

    func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool
}

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

/// Archive data integrity and checksum verification interface.
public protocol ArchiveIntegrityChecking: Sendable {
    func computeCRC32(filePath: String) -> String
    func computeSHA256(filePath: String) async throws -> String
    @discardableResult
    func verifyExtractedDirectory(
        directoryPath: String,
        expectedOriginalBytes: Int64,
        sourceFilePath: String?,
        sourceCRC32: String?,
        label: String
    ) -> (isValid: Bool, totalExtractedBytes: Int64, crc32: String?)
}

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

/// Cryptographic hash calculation interface.
public protocol HashCalculating: Sendable {
    func computeHashSync(filePath: String, type: HashType) throws -> String
    func computeHash(filePath: String, type: HashType) async throws -> String
}

/// ZIP format hardware-accelerated encryption and decryption engine interface.
public protocol ZipCryptoEngineProtocol: Sendable {
    func decryptZipCrypto(payload: Data, password: String) -> Data?
    func encryptAES256(payload: Data, password: String, actualCompressionMethod: UInt16) -> (payload: Data, compressionMethod: UInt16, extraField: Data)?
    func decryptAES256(payloadPtr: UnsafePointer<UInt8>, count: Int, password: String) -> Data?
    func decryptAES256Direct(payloadPtr: UnsafePointer<UInt8>, count: Int, password: String, destinationPtr: UnsafeMutablePointer<UInt8>) -> Bool
    func decryptAES256(payload: Data, password: String) -> Data?
}

/// 7z format PBKDF2-SHA256 and AES-256-CBC engine interface.
public protocol SevenZipCryptoEngineProtocol: Sendable {
    func deriveKey(password: String, salt: Data, numCyclesPower: Int) -> Data
    func processParallelAES256(
        inputData: Data,
        key: Data,
        iv: Data,
        encrypt: Bool,
        chunkSize: Int
    ) -> Data?
}
