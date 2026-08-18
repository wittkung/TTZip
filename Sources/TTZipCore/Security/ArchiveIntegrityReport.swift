// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Integrity Status

/// Overall verdict classification for archive integrity verification.
public enum IntegrityStatus: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case passed = "passed"
    case corrupted = "corrupted"
    case unreadable = "unreadable"
    case encryptedMissingKey = "encrypted_missing_key"
}

// MARK: - Corruption Error Type

/// Detailed corruption classification for archive entries.
public enum IntegrityCorruptionErrorType: String, Sendable, Codable, CaseIterable, Equatable, Hashable {
    case crc32Mismatch = "crc32_mismatch"
    case headerDamaged = "header_damaged"
    case blockTruncated = "block_truncated"
    case invalidDictionary = "invalid_dictionary"
}

// MARK: - Corrupted Entry Detail

/// Specific diagnostic details for a corrupted or damaged archive entry.
public struct CorruptedEntryDetail: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: String { entryPath + "_" + errorType.rawValue }
    
    /// Relative path of corrupted file inside archive.
    public let entryPath: String
    
    /// Classification of corruption.
    public let errorType: IntegrityCorruptionErrorType
    
    /// Expected CRC32 / SHA-256 hex string from archive header.
    public let expectedChecksum: String
    
    /// Actual CRC32 / SHA-256 computed over decompressed bytes.
    public let actualChecksum: String
    
    /// Detailed diagnostic message from low-level decompressor.
    public let diagnosticMessage: String

    public init(
        entryPath: String,
        errorType: IntegrityCorruptionErrorType,
        expectedChecksum: String = "",
        actualChecksum: String = "",
        diagnosticMessage: String
    ) {
        self.entryPath = entryPath
        self.errorType = errorType
        self.expectedChecksum = expectedChecksum
        self.actualChecksum = actualChecksum
        self.diagnosticMessage = diagnosticMessage
    }
}

// MARK: - Archive Integrity Report

/// Result of an in-memory CRC32/SHA-256 integrity verification pass.
/// Conforms strictly to `contracts/archive-integrity-report.json`.
public struct ArchiveIntegrityReport: Sendable, Codable, Equatable, Hashable {
    /// Absolute path to verified archive.
    public let archivePath: String
    
    /// Total number of entries examined.
    public let totalEntriesCount: Int
    
    /// Total number of entries passing all checksum validations.
    public let verifiedEntriesCount: Int
    
    /// Number of corrupt or unreadable entries.
    public let corruptedEntriesCount: Int
    
    /// Overall status verdict.
    public let overallStatus: IntegrityStatus
    
    /// Elapsed duration of verification pass in seconds.
    public let verificationDurationSeconds: Double
    
    /// In-memory decoding and verification throughput in MB/s.
    public let averageThroughputMBs: Double
    
    /// List of corrupted entry records.
    public let corruptedEntries: [CorruptedEntryDetail]

    public init(
        archivePath: String,
        totalEntriesCount: Int,
        verifiedEntriesCount: Int,
        corruptedEntriesCount: Int,
        overallStatus: IntegrityStatus,
        verificationDurationSeconds: Double,
        averageThroughputMBs: Double,
        corruptedEntries: [CorruptedEntryDetail] = []
    ) {
        self.archivePath = archivePath
        self.totalEntriesCount = totalEntriesCount
        self.verifiedEntriesCount = verifiedEntriesCount
        self.corruptedEntriesCount = corruptedEntriesCount
        self.overallStatus = overallStatus
        self.verificationDurationSeconds = verificationDurationSeconds
        self.averageThroughputMBs = averageThroughputMBs
        self.corruptedEntries = corruptedEntries
    }

    /// Returns `true` if all entries were successfully verified with zero corruptions.
    public var isClean: Bool {
        return overallStatus == .passed && corruptedEntriesCount == 0 && corruptedEntries.isEmpty
    }
}
