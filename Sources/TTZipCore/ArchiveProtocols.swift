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
    /// Convenience facade method to list entries of an archive.
    @inline(__always)
    public func listEntries(archivePath: String, password: String? = nil) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
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
    /// Convenience facade method to extract an archive.
    @inline(__always)
    public func extractArchive(
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
