// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Security protection proxy error types.
public enum ProxySecurityError: Error, Equatable, LocalizedError, Sendable {
    case unauthorizedProFeature(LicenseManager.ProFeature)
    case zipSlipDetected(path: String)
    case passwordRequired(archivePath: String)
    case securityScanFailed(suspiciousFiles: [String])
    
    public var errorDescription: String? {
        switch self {
        case .unauthorizedProFeature(let feature):
            return "Commercial license interception: feature \(feature) requires active TTZip Pro license."
        case .zipSlipDetected(let path):
            return "ZipSlip security violation: path traversal attack detected '\(path)'."
        case .passwordRequired(let archivePath):
            return "Password required: archive '\(archivePath)' is encrypted."
        case .securityScanFailed(let suspicious):
            return "Security compliance interception: \(suspicious.count) suspicious or dangerous components detected."
        }
    }
}

/// Protection proxy enforcing licensing gatekeeping, path traversal defense, and security audits (Protection Proxy Pattern).
public final class SecurityProtectionProxy: TTZipEngineFacading, @unchecked Sendable {
    public static let shared = SecurityProtectionProxy()
    
    private let targetEngine: TTZipEngineFacading
    private let licenseManager: LicenseManager
    private let securityFacade: ArchiveSecurityFacading
    private let passwordVault: PasswordVaultManaging
    
    private let lock = NSLock()
    public private(set) var interceptedProCount: Int = 0
    public private(set) var interceptedZipSlipCount: Int = 0
    public private(set) var approvedCallCount: Int = 0
    
    private convenience init() {
        self.init(
            targetEngine: TTZipEngineFacade.shared,
            licenseManager: LicenseManager.shared,
            securityFacade: ArchiveSecurityFacade.shared,
            passwordVault: PasswordVaultManager.shared
        )
    }
    
    internal init(
        targetEngine: TTZipEngineFacading = TTZipEngineFacade.shared,
        licenseManager: LicenseManager = LicenseManager.shared,
        securityFacade: ArchiveSecurityFacading = ArchiveSecurityFacade.shared,
        passwordVault: PasswordVaultManaging = PasswordVaultManager.shared
    ) {
        self.targetEngine = targetEngine
        self.licenseManager = licenseManager
        self.securityFacade = securityFacade
        self.passwordVault = passwordVault
    }
    
    /// Detects path traversal, URL-encoding bypasses, null bytes, and sensitive path escapes.
    public static func isPathTraversalOrEscape(_ rawPath: String) -> Bool {
        // 1. URL decoding unwrapping up to 5 layers
        var decoded = rawPath
        for _ in 0..<5 {
            if let next = decoded.removingPercentEncoding, next != decoded {
                decoded = next
            } else {
                break
            }
        }
        
        // 2. Null byte defense
        if decoded.contains("\0") {
            return true
        }
        
        // 3. Normalizing slashes
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")
        
        // 4. Component-level ".." traversal
        let components = normalized.components(separatedBy: "/")
        if components.contains("..") {
            return true
        }
        
        // 5. Absolute path to sensitive directories or UNC paths
        if normalized.hasPrefix("/etc/") || normalized.hasPrefix("/var/log/") || normalized.hasPrefix("/private/etc/") ||
           normalized.hasPrefix("//") || hasWindowsDriveLetterPrefix(normalized) {
            return true
        }
        
        // 6. Encoded traversal escape components
        let rawLower = rawPath.lowercased()
        if rawLower.contains("%2e%2e/") || rawLower.contains("/%2e%2e") || rawLower == "%2e%2e" ||
           rawLower.contains("%2e%2e\\") || rawLower.contains("\\%2e%2e") {
            return true
        }
        
        return false
    }
    
    private static func hasWindowsDriveLetterPrefix(_ path: String) -> Bool {
        guard path.count >= 2 else { return false }
        let utf8 = path.utf8
        let first = utf8[utf8.startIndex]
        let second = utf8[utf8.index(after: utf8.startIndex)]
        let isLetter = (first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A)
        return isLetter && second == 0x3A
    }
    
    // MARK: - Compression Protection
    
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = .defaultClean,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        let isUltraLevel = (level == .ultra) ||
            (advancedOptions?.zstdLevel ?? 0) >= 9 ||
            (advancedOptions?.sevenZipOptions.dictionarySizeMB ?? 0) >= 64
        if isUltraLevel {
            guard licenseManager.canUseFeature(.ultraCompression) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.ultraCompression)
            }
        }
        
        let isEncrypted = (password != nil && !password!.isEmpty) ||
            (advancedOptions?.encryptFileNames == true) ||
            (advancedOptions?.zipOptions.zipEncryptionMethod.contains("AES") == true && password != nil)
        if isEncrypted {
            guard licenseManager.canUseFeature(.aes256Encryption) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.aes256Encryption)
            }
        }
        
        let isSplit = (splitSize != nil && splitSize! > 0)
        if isSplit {
            guard licenseManager.canUseFeature(.volumeSplit) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.volumeSplit)
            }
        }
        
        if inputs.count > 5 {
            guard licenseManager.canUseFeature(.batchProcessing) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.batchProcessing)
            }
        }
        
        for input in inputs {
            if SecurityProtectionProxy.isPathTraversalOrEscape(input) {
                recordZipSlipInterception()
                throw ProxySecurityError.zipSlipDetected(path: input)
            }
        }
        
        if SecurityProtectionProxy.isPathTraversalOrEscape(outputPath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: outputPath)
        }
        
        recordApproval()
        return try await targetEngine.quickCompress(
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: filterOptions,
            advancedOptions: advancedOptions,
            progress: progress
        )
    }
    
    // MARK: - Extraction Protection
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        guard licenseManager.canUseFeature(.basicExtract) else {
            recordProInterception()
            throw ProxySecurityError.unauthorizedProFeature(.basicExtract)
        }
        
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) || SecurityProtectionProxy.isPathTraversalOrEscape(destinationDir) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: destinationDir)
        }
        
        let targetPassword = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        if let inspection = try? await targetEngine.inspectArchive(archivePath: archivePath, password: targetPassword, autoVaultUnlock: autoVaultUnlock) {
            for entry in inspection.entries {
                if !securityFacade.validateExtractPath(entryPath: entry.path, destinationDir: destinationDir) {
                    recordZipSlipInterception()
                    throw ProxySecurityError.zipSlipDetected(path: entry.path)
                }
            }
            if !inspection.securityReport.isSafe && inspection.securityReport.hasZipSlipRisk {
                recordZipSlipInterception()
                throw ProxySecurityError.zipSlipDetected(path: archivePath)
            }
        }
        
        recordApproval()
        return try await targetEngine.quickExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            autoVaultUnlock: autoVaultUnlock,
            progress: progress
        )
    }
    
    // MARK: - Single Entry Extraction Protection
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) || SecurityProtectionProxy.isPathTraversalOrEscape(destinationDir) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: entryPath)
        }
        
        guard securityFacade.validateExtractPath(entryPath: entryPath, destinationDir: destinationDir) else {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: entryPath)
        }
        
        recordApproval()
        try await targetEngine.extractSingleEntry(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: destinationDir,
            password: password
        )
    }
    
    // MARK: - Metadata Inspection Protection
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: archivePath)
        }
        
        recordApproval()
        return try await targetEngine.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
    }
    
    // MARK: - Additional Engine Delegations
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: archivePath)
        }
        recordApproval()
        return try await targetEngine.verifyIntegrity(archivePath: archivePath)
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        if SecurityProtectionProxy.isPathTraversalOrEscape(damagedPath) || SecurityProtectionProxy.isPathTraversalOrEscape(outputPath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: damagedPath)
        }
        recordApproval()
        return try await targetEngine.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: archivePath)
        }
        recordApproval()
        return try await targetEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }
    
    // MARK: - Metrics & Diagnostics
    
    private func recordProInterception() {
        lock.withLock {
            interceptedProCount += 1
        }
    }
    
    private func recordZipSlipInterception() {
        lock.withLock {
            interceptedZipSlipCount += 1
        }
    }
    
    private func recordApproval() {
        lock.withLock {
            approvedCallCount += 1
        }
    }
    
    public func resetMetrics() {
        lock.withLock {
            interceptedProCount = 0
            interceptedZipSlipCount = 0
            approvedCallCount = 0
        }
    }
}
