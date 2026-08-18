// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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

/// Archive security and compliance auditing facade protocol.
public protocol ArchiveSecurityFacading: Sendable {
    func auditArchive(archivePath: String, password: String?, autoVaultUnlock: Bool) async throws -> SecurityReport
    func validateExtractPath(entryPath: String, destinationDir: String) -> Bool
    func scanEntries(_ entries: [ArchiveEntry]) -> SecurityReport
}

extension ArchiveSecurityFacading {
    public func auditArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> SecurityReport {
        return try await auditArchive(archivePath: archivePath, password: password, autoVaultUnlock: autoVaultUnlock)
    }
}

/// Unified security facade encapsulating AMSI heuristic filtering, Zip Slip traversal defense, and symlink isolation.
public final class ArchiveSecurityFacade: ArchiveSecurityFacading, @unchecked Sendable {
    public static let shared = ArchiveSecurityFacade()
    
    private let securityScanner: SecurityScanner
    private let reader: ArchiveReading
    
    private convenience init() {
        self.init(
            securityScanner: SecurityScanner.shared,
            reader: ArchiveEngineFactory.makeReader()
        )
    }
    
    internal init(
        securityScanner: SecurityScanner = SecurityScanner.shared,
        reader: ArchiveReading = ArchiveEngineFactory.makeReader()
    ) {
        self.securityScanner = securityScanner
        self.reader = reader
    }
    
    // MARK: - 1. Entry Security Scanning
    
    public func scanEntries(_ entries: [ArchiveEntry]) -> SecurityReport {
        let rawScan = securityScanner.scanArchiveEntries(entries)
        var hasZipSlip = false
        
        for entry in entries {
            let p = entry.path.lowercased()
            if p.contains("..") || p.hasPrefix("/") || p.contains(":\\") {
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
    
    // MARK: - 2. Deep Archive Security Audit
    
    public func auditArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> SecurityReport {
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        
        if let entries = try? await reader.inspect(archivePath: archivePath, password: explicitPwd) {
            return scanEntries(entries)
        }
        
        if autoVaultUnlock && PasswordVaultManager.shared.autoUnlockArchives {
            let vaultEntries = PasswordVaultManager.shared.getEntries()
            for entry in vaultEntries {
                if let entries = try? await reader.inspect(archivePath: archivePath, password: entry.password) {
                    return scanEntries(entries)
                }
            }
        }
        
        throw ArchiveError.passwordRequired
    }
    
    // MARK: - 3. Extraction Path Sanitization & Validation
    
    public func validateExtractPath(entryPath: String, destinationDir: String) -> Bool {
        var decodedEntry = entryPath
        for _ in 0..<3 {
            if let next = decodedEntry.removingPercentEncoding, next != decodedEntry {
                decodedEntry = next
            } else {
                break
            }
        }
        
        if decodedEntry.contains("\0") {
            return false
        }
        
        let normalizedEntry = decodedEntry.replacingOccurrences(of: "\\", with: "/")
        
        if normalizedEntry.hasPrefix("/") ||
           normalizedEntry.range(of: "^[a-zA-Z]:", options: .regularExpression) != nil ||
           normalizedEntry.hasPrefix("//") {
            return false
        }
        
        let components = normalizedEntry.components(separatedBy: "/")
        if components.contains("..") {
            return false
        }
        
        let destURL = URL(fileURLWithPath: destinationDir).standardized
        let targetURL = destURL.appendingPathComponent(normalizedEntry).standardized
        
        let normalizedDestPath = destURL.path
        let targetPath = targetURL.path
        
        guard targetPath.hasPrefix(normalizedDestPath) else {
            return false
        }
        
        let resolvedDest = destURL.resolvingSymlinksInPath().path
        let resolvedTarget = targetURL.resolvingSymlinksInPath().path
        if !resolvedTarget.hasPrefix(resolvedDest) && !resolvedTarget.hasPrefix(normalizedDestPath) {
            return false
        }
        
        return true
    }
}
