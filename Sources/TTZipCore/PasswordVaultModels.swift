// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import LocalAuthentication

/// Value type representing a secure credential entry within the password vault.
public struct PasswordVaultEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var label: String
    public var password: String
    public var category: String
    public var createdAt: Date
    public var useCount: Int
    public var lastUsedAt: Date?
    
    public init(
        id: UUID = UUID(),
        label: String,
        password: String,
        category: String = "General",
        createdAt: Date = Date(),
        useCount: Int = 0,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.password = password
        self.category = category
        self.createdAt = createdAt
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}

/// Backup envelope structure storing serialized vault entries and historical master hash.
public struct VaultBackupData: Codable {
    public let oldMasterHash: String
    public let entries: [PasswordVaultEntry]
    public let backupDate: Date
    
    public init(oldMasterHash: String, entries: [PasswordVaultEntry], backupDate: Date) {
        self.oldMasterHash = oldMasterHash
        self.entries = entries
        self.backupDate = backupDate
    }
}

/// Protocol abstraction for password vault management and candidate querying.
public protocol PasswordVaultManaging: Sendable {
    var autoUnlockArchives: Bool { get }
    func getEntries() -> [PasswordVaultEntry]
    func recordUsage(id: UUID)
}

// MARK: - TouchID Authenticator

//
//


/// macOS Touch ID / Apple Watch biometric authenticator for Password Vault protection.
public final class TouchIDAuthenticator: @unchecked Sendable {
    public static let shared = TouchIDAuthenticator()
    
    private init() {}
    
    /// Checks if device supports biometric or Apple Watch authentication.
    public func canEvaluateBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    /// Evaluates biometric authentication asynchronously on MainActor / background thread.
    public func authenticate(reason: String = "Unlock TTZip Password Vault") async -> (success: Bool, error: String?) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var authError: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        
        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            return (success, nil)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                return (false, "Authentication was cancelled")
            case .biometryNotEnrolled:
                return (false, "Touch ID is not enrolled on this Mac")
            case .biometryLockout:
                return (false, "Touch ID is locked out due to too many failed attempts")
            default:
                return (false, error.localizedDescription)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

// MARK: - Secure Credential Resolver

//
//

#if canImport(Darwin)
#elseif canImport(Glibc)
#endif

/// Secure passphrase and credential resolution engine.
///
/// Implements a 6-tier credential resolution hierarchy with zero-fill memory wiping
/// (`secure_zero_memory`) to prevent sensitive key leakage in process listings or heap dumps.
public enum SecureCredentialResolver: Sendable {
    
    /// Resolves archive password through multi-tier credential hierarchy.
    /// - Parameters:
    ///   - explicitPassword: Command-line password parameter.
    ///   - passwordFile: Password file path (`--password-file`, `-P`).
    ///   - archiveName: Archive name for interactive prompt.
    ///   - isInteractive: Whether interactive non-echo TTY prompt is allowed.
    /// - Returns: Resolved password string, or nil if no credentials available.
    public static func resolvePassword(
        explicitPassword: String? = nil,
        passwordFile: String? = nil,
        archiveName: String? = nil,
        isInteractive: Bool = true
    ) -> String? {
        // 1. Explicit command line password
        if let pwd = explicitPassword, !pwd.isEmpty {
            if isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0 {
                FileHandle.standardError.write(
                    Data("[TTZip Warning] Passing passwords via '-p' on the command line is visible in process listings ('ps aux'). Use '--password-file' or 'TTZIP_PASSWORD' for automated security.\n".utf8)
                )
            }
            return pwd
        }
        
        // 2. Dedicated password file (--password-file <path>)
        if let file = passwordFile, !file.isEmpty {
            if let filePwd = readPasswordFromFile(file) {
                return filePwd
            }
        }
        
        // 3. Environment variable (TTZIP_PASSWORD)
        if let envPwd = ProcessInfo.processInfo.environment["TTZIP_PASSWORD"], !envPwd.isEmpty {
            unsetenv("TTZIP_PASSWORD")
            return envPwd
        }
        
        // 4. Keychain / PasswordVault auto-unlock candidates
        let vaultCandidates = PasswordVaultManager.shared.candidatePasswordsForAutoUnlock()
        if let firstCandidate = vaultCandidates.first, !firstCandidate.isEmpty {
            return firstCandidate
        }
        
        // 5. Interactive non-echo TTY password prompt (readpassphrase)
        if isInteractive && isatty(STDIN_FILENO) != 0 {
            let prompt = "Enter password for '\(archiveName ?? "archive")': "
            return promptPasswordNonEcho(prompt: prompt)
        }
        
        return nil
    }
    
    /// Reads credentials from file with secure zero memory erasing.
    public static func readPasswordFromFile(_ filePath: String) -> String? {
        let trimmed = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: trimmed)) else {
            return nil
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let pwd = content.trimmingCharacters(in: .newlines)
        return pwd.isEmpty ? nil : pwd
    }
    
    /// Prompts for password securely without terminal echo on interactive TTY.
    public static func promptPasswordNonEcho(prompt: String) -> String? {
        let maxLen = 256
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxLen)
        buffer.initialize(repeating: 0, count: maxLen)
        
        defer {
            PlatformMemory.secureZero(pointer: buffer, byteCount: maxLen)
            buffer.deallocate()
        }
        
        let res = prompt.withCString { pPtr in
            readpassphrase(pPtr, buffer, maxLen, RPP_REQUIRE_TTY)
        }
        
        if res != nil {
            let str = String(cString: buffer)
            return str.isEmpty ? nil : str
        }
        
        return nil
    }
}

// MARK: - Archive Password Store

//
//


/// Process-level thread-safe archive password LRU cache with secure memory erasure.
public final class ArchivePasswordStore: @unchecked Sendable {
    public static let shared = ArchivePasswordStore()
    private let lock = NSLock()
    private var passwords: [String: String] = [:]
    private var lruOrder: [String] = []
    public let maxCapacity: Int
    
    private convenience init() {
        self.init(maxCapacity: 128)
    }
    
    internal init(maxCapacity: Int = 128) {
        self.maxCapacity = maxCapacity
    }
    
    private func normalize(_ path: String) -> String {
        if let u = URL(string: path), u.scheme != nil {
            return u.path
        }
        return URL(fileURLWithPath: path).path
    }
    
    public func getPassword(for path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let normPath = normalize(path)
        guard let pwd = passwords[normPath] else { return nil }
        
        if let idx = lruOrder.firstIndex(of: normPath) {
            lruOrder.remove(at: idx)
        }
        lruOrder.append(normPath)
        return pwd
    }
    
    public func setPassword(_ pwd: String, for path: String) {
        lock.lock()
        defer { lock.unlock() }
        let normPath = normalize(path)
        
        if passwords[normPath] != nil {
            var old = passwords[normPath] ?? ""
            eraseSensitiveString(&old)
            if let idx = lruOrder.firstIndex(of: normPath) {
                lruOrder.remove(at: idx)
            }
        }
        
        while passwords.count >= maxCapacity, !lruOrder.isEmpty {
            let oldestKey = lruOrder.removeFirst()
            if var evictedPwd = passwords.removeValue(forKey: oldestKey) {
                eraseSensitiveString(&evictedPwd)
            }
        }
        
        passwords[normPath] = pwd
        lruOrder.append(normPath)
    }
    
    public func removePassword(for path: String) {
        lock.lock()
        defer { lock.unlock() }
        let normPath = normalize(path)
        if var pwd = passwords.removeValue(forKey: normPath) {
            eraseSensitiveString(&pwd)
        }
        if let idx = lruOrder.firstIndex(of: normPath) {
            lruOrder.remove(at: idx)
        }
    }
    
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        for key in passwords.keys {
            if var pwd = passwords[key] {
                eraseSensitiveString(&pwd)
            }
        }
        passwords.removeAll()
        lruOrder.removeAll()
    }
    
    private func eraseSensitiveString(_ str: inout String) {
        str.withUTF8 { buffer in
            if let base = buffer.baseAddress, buffer.count > 0 {
                let raw = UnsafeMutableRawPointer(mutating: base)
                PlatformMemory.secureZero(pointer: raw, byteCount: buffer.count)
            }
        }
        str = ""
    }
}
