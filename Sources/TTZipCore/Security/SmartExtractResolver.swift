// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Resolution decision mode for smart extraction.
public enum SmartExtractResolutionMode: String, Sendable, Equatable {
    /// The archive has a single top-level directory or file. Extract directly into destination parent folder without extra wrapping.
    case directExtract
    /// The archive contains multiple loose root files/directories. Wrap all contents inside a folder named after the archive stem.
    case wrapInFolder
    /// The archive has no valid user files.
    case emptyArchive
}

/// Collision handling policy when destination path already exists.
public enum SmartExtractCollisionPolicy: String, Sendable, Equatable {
    case autoRenameNumbered
    case overwriteExisting
    case skipExisting
    case abortWithError
}

/// Result of smart extraction resolution.
public struct SmartExtractResolutionResult: Sendable, Equatable {
    public let resolutionMode: SmartExtractResolutionMode
    public let effectiveRootCount: Int
    public let singleRootName: String?
    public let finalExtractionURL: URL
    
    public init(
        resolutionMode: SmartExtractResolutionMode,
        effectiveRootCount: Int,
        singleRootName: String?,
        finalExtractionURL: URL
    ) {
        self.resolutionMode = resolutionMode
        self.effectiveRootCount = effectiveRootCount
        self.singleRootName = singleRootName
        self.finalExtractionURL = finalExtractionURL
    }
}

/// High-performance smart extraction resolver (analyzes root entries and eliminates folder-in-folder nesting).
public enum SmartExtractResolver: Sendable {
    
    /// Evaluates the archive entry paths and determines the optimal extraction destination folder.
    ///
    /// - Parameters:
    ///   - entryPaths: List of relative entry paths in the archive.
    ///   - destinationParentURL: Target parent directory where extraction is triggered.
    ///   - archiveStemName: File stem of the archive (e.g. "MyProject" for "MyProject.zip").
    ///   - collisionPolicy: Strategy when destination item already exists.
    /// - Returns: Computed `SmartExtractResolutionResult`.
    public static func resolve(
        entryPaths: [String],
        destinationParentURL: URL,
        archiveStemName: String,
        collisionPolicy: SmartExtractCollisionPolicy = .autoRenameNumbered
    ) -> SmartExtractResolutionResult {
        var effectiveRoots = Set<String>()
        
        for rawPath in entryPaths {
            // 1. Skip system metadata & AppleDouble junk
            if ArchiveFilterOptions.isSystemMetadata(path: rawPath) {
                continue
            }
            
            var normalized = rawPath.replacingOccurrences(of: "\\", with: "/")
            while normalized.hasPrefix("./") {
                normalized.removeFirst(2)
            }
            normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            guard !normalized.isEmpty else { continue }
            
            let components = normalized.split(separator: "/")
            if let first = components.first {
                effectiveRoots.insert(String(first))
            }
        }

        
        let rootCount = effectiveRoots.count
        let mode: SmartExtractResolutionMode
        let singleRoot: String?
        var targetURL: URL
        
        if rootCount == 0 {
            mode = .emptyArchive
            singleRoot = nil
            targetURL = destinationParentURL
        } else if rootCount == 1 {
            mode = .directExtract
            singleRoot = effectiveRoots.first
            targetURL = destinationParentURL
        } else {
            mode = .wrapInFolder
            singleRoot = nil
            targetURL = destinationParentURL.appendingPathComponent(archiveStemName, isDirectory: true)
        }
        
        // 2. Handle path collision if required and wrapping in folder
        if mode == .wrapInFolder && collisionPolicy == .autoRenameNumbered {
            targetURL = resolveNumberedCollision(initialURL: targetURL)
        }
        
        return SmartExtractResolutionResult(
            resolutionMode: mode,
            effectiveRootCount: rootCount,
            singleRootName: singleRoot,
            finalExtractionURL: targetURL
        )
    }
    
    /// Generates a non-colliding directory URL (e.g., "Folder 2", "Folder 3").
    private static func resolveNumberedCollision(initialURL: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: initialURL.path) else {
            return initialURL
        }
        
        let parentURL = initialURL.deletingLastPathComponent()
        let baseName = initialURL.lastPathComponent
        var counter = 2
        
        while counter < 1000 {
            let candidateURL = parentURL.appendingPathComponent("\(baseName) \(counter)", isDirectory: true)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
        
        return parentURL.appendingPathComponent("\(baseName)_\(UUID().uuidString.prefix(6))", isDirectory: true)
    }
}

// MARK: - Security Scanner

//
//


/// Threat assessment report generated by the security scanning engine.
public struct SecurityScanResult: Sendable {
    public let isSafe: Bool
    public let suspiciousFileNames: [String]
    public let detailMessage: String
}

/// Security risk classification levels.
public enum SecurityRiskLevel: String, Sendable, Codable, Comparable {
    case safe = "SAFE"
    case warning = "WARNING"
    case critical = "CRITICAL"
    
    private var severity: Int {
        switch self {
        case .safe: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
    
    public static func < (lhs: SecurityRiskLevel, rhs: SecurityRiskLevel) -> Bool {
        return lhs.severity < rhs.severity
    }
}

/// Unified archive security audit report.
public struct SecurityReport: Sendable, Equatable {
    public let isSafe: Bool
    public let suspiciousFileNames: [String]
    public let hasZipSlipRisk: Bool
    public let detailMessage: String
    public let riskLevel: SecurityRiskLevel
    
    public init(
        isSafe: Bool,
        suspiciousFileNames: [String],
        hasZipSlipRisk: Bool,
        detailMessage: String,
        riskLevel: SecurityRiskLevel
    ) {
        self.isSafe = isSafe
        self.suspiciousFileNames = suspiciousFileNames
        self.hasZipSlipRisk = hasZipSlipRisk
        self.detailMessage = detailMessage
        self.riskLevel = riskLevel
    }
}

/// In-memory threat and vulnerability scanning engine (Zip Slip, dangerous extensions, and traversal checks).
public final class SecurityScanner: @unchecked Sendable {
    public static let shared = SecurityScanner()
    
    private let dangerousExtensions: Set<String> = [
        "exe", "bat", "cmd", "vbs", "js", "scr", "pif", "sh", "command"
    ]
    
    private init() {}
    
    /// Asserts whether a path is free of Zip Slip traversal (`..`), absolute prefixes, or reserved characters.
    public static func isPathSafe(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        if path.contains("\0") { return false }
        let res = PlatformPathSanitizer.sanitize(path: path)
        if res.hasTraversalAttack || res.isAbsolute || res.isUNCPath || res.containsWindowsReservedDeviceName || res.strippedAlternateDataStream != nil {
            return false
        }
        return !res.normalizedPath.isEmpty
    }
    
    /// Normalizes and cleanses a path across platforms.
    public static func sanitizePath(_ path: String) -> String? {
        let res = PlatformPathSanitizer.sanitize(path: path)
        guard !res.normalizedPath.isEmpty else { return nil }
        return res.normalizedPath
    }

    /// Scans an array of `ArchiveEntry` items for executable scripts or Zip Slip threats.
    public func scanArchiveEntries(_ entries: [ArchiveEntry]) -> SecurityScanResult {
        var suspicious: [String] = []
        for entry in entries {
            // Zip Slip path traversal check
            if !Self.isPathSafe(entry.path) {
                if !suspicious.contains(entry.path) {
                    suspicious.append(entry.path)
                }
                continue
            }
            
            let ext = (entry.name as NSString).pathExtension.lowercased()
            if dangerousExtensions.contains(ext) {
                if !suspicious.contains(entry.path) {
                    suspicious.append(entry.path)
                }
                continue
            }
        }
        if suspicious.isEmpty {
            return SecurityScanResult(
                isSafe: true,
                suspiciousFileNames: [],
                detailMessage: "Memory scan clean: No malicious extensions or path traversal threats detected"
            )
        } else {
            return SecurityScanResult(
                isSafe: false,
                suspiciousFileNames: suspicious,
                detailMessage: "Security warning: Detected \(suspicious.count) potentially suspicious files or paths"
            )
        }
    }

    /// Scans entries and constructs a unified `SecurityReport`.
    public func scanEntriesForReport(_ entries: [ArchiveEntry]) -> SecurityReport {
        let rawScan = scanArchiveEntries(entries)
        var hasZipSlip = false
        
        for entry in entries {
            let p = entry.path.lowercased()
            if p.contains("..") || p.hasPrefix("/") || p.contains(":\\") || !Self.isPathSafe(entry.path) {
                hasZipSlip = true
                break
            }
        }
        
        let riskLevel: SecurityRiskLevel
        if hasZipSlip {
            riskLevel = .critical
        } else if !rawScan.isSafe {
            riskLevel = .warning
        } else {
            riskLevel = .safe
        }
        
        var message = rawScan.detailMessage
        if hasZipSlip {
            message = "Critical security alert: Zip Slip path traversal vulnerability detected!"
        }
        
        return SecurityReport(
            isSafe: rawScan.isSafe && !hasZipSlip,
            suspiciousFileNames: rawScan.suspiciousFileNames,
            hasZipSlipRisk: hasZipSlip,
            detailMessage: message,
            riskLevel: riskLevel
        )
    }

    /// Scans a composite component tree.
    public func scanComponent(_ component: ArchiveComponentProtocol) -> SecurityScanResult {
        var suspicious: [String] = []
        for leaf in component.flattenLeaves() {
            let path = leaf.path
            let lowerPath = path.lowercased()
            if lowerPath.contains("..") || lowerPath.hasPrefix("/") || !Self.isPathSafe(path) {
                if !suspicious.contains(path) {
                    suspicious.append(path)
                }
                continue
            }
            
            let ext = (leaf.name as NSString).pathExtension.lowercased()
            if dangerousExtensions.contains(ext) {
                if !suspicious.contains(path) {
                    suspicious.append(path)
                }
                continue
            }
            
            if let compressedSize = leaf.compressedSizeBytes, compressedSize > 0 {
                let ratio = Double(leaf.sizeBytes) / Double(compressedSize)
                if ratio > 100.0 && leaf.sizeBytes > 1_000_000 {
                    if !suspicious.contains(path) {
                        suspicious.append(path)
                    }
                }
            }
        }
        
        if suspicious.isEmpty {
            return SecurityScanResult(
                isSafe: true,
                suspiciousFileNames: [],
                detailMessage: "Memory scan clean: No malicious extensions or path traversal threats detected"
            )
        } else {
            return SecurityScanResult(
                isSafe: false,
                suspiciousFileNames: suspicious,
                detailMessage: "Security warning: Detected \(suspicious.count) potentially suspicious files or paths"
            )
        }
    }
    
    public func scanComponents(_ components: [ArchiveComponentProtocol]) -> SecurityScanResult {
        var suspicious: [String] = []
        for component in components {
            let res = scanComponent(component)
            if !res.isSafe {
                for item in res.suspiciousFileNames {
                    if !suspicious.contains(item) {
                        suspicious.append(item)
                    }
                }
            }
        }
        
        if suspicious.isEmpty {
            return SecurityScanResult(
                isSafe: true,
                suspiciousFileNames: [],
                detailMessage: "Memory scan clean: No malicious extensions or path traversal threats detected"
            )
        } else {
            return SecurityScanResult(
                isSafe: false,
                suspiciousFileNames: suspicious,
                detailMessage: "Security warning: Detected \(suspicious.count) potentially suspicious files or paths"
            )
        }
    }
}

// MARK: - Integrity Report

//
//


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
