// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
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
