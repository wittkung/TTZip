// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import Security
import LocalAuthentication
import CommonCrypto
import CTTZipBridge

// MARK: - PasswordVaultManager Persistence, AES-GCM Encryption & Keychain Extension

extension PasswordVaultManager {
    
    func hashString(_ str: String) -> String {
        let data = Data(str.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Crypto v4 (PBKDF2-SHA256 + Per-vault 32-byte Random Salt + 600k rounds)
    
    static let vaultMagicV4 = Data([0x54, 0x54, 0x56, 0x34]) // "TTV4"
    static let defaultV4Iterations: UInt32 = 600_000
    
    func deriveSymmetricKeyV4(_ password: String, salt: Data, iterations: UInt32 = defaultV4Iterations) -> SymmetricKey {
        var derivedKey = [UInt8](repeating: 0, count: 32)
        defer {
            derivedKey.withUnsafeMutableBytes { ptr in
                guard let base = ptr.baseAddress else { return }
                memset_s(base, ptr.count, 0, ptr.count)
            }
        }
        let passBytes = Array(password.utf8)
        let status = salt.withUnsafeBytes { sBuf in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, passBytes.count,
                sBuf.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &derivedKey, 32
            )
        }
        if status == kCCSuccess {
            return SymmetricKey(data: derivedKey)
        }
        let hash = SHA256.hash(data: Data(password.utf8))
        return SymmetricKey(data: hash)
    }
    
    func encryptDataV4(_ data: Data, password: String) -> Data? {
        var saltBytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes) == errSecSuccess else {
            return nil
        }
        let salt = Data(saltBytes)
        let iterations = Self.defaultV4Iterations
        let key = deriveSymmetricKeyV4(password, salt: salt, iterations: iterations)
        
        guard let sealedBox = try? AES.GCM.seal(data, using: key),
              let combinedPayload = sealedBox.combined else {
            return nil
        }
        
        var result = Data()
        result.append(Self.vaultMagicV4) // 4 bytes
        var iterBigEndian = iterations.bigEndian
        result.append(Data(bytes: &iterBigEndian, count: 4)) // 4 bytes
        var saltLen = UInt8(salt.count)
        result.append(Data(bytes: &saltLen, count: 1)) // 1 byte
        result.append(salt) // 32 bytes
        result.append(combinedPayload) // AES-GCM combined sealed box
        return result
    }
    
    func decryptDataV4(_ data: Data, password: String) -> Data? {
        guard data.count >= 69 else { return nil }
        let magic = data.prefix(4)
        guard magic == Self.vaultMagicV4 else { return nil }
        
        let iterations = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
        
        let saltLen = Int(data[8])
        guard data.count >= 9 + saltLen + 28 else { return nil }
        let salt = data.subdata(in: 9..<(9 + saltLen))
        
        let payload = data.subdata(in: (9 + saltLen)..<data.count)
        let key = deriveSymmetricKeyV4(password, salt: salt, iterations: iterations)
        
        guard let sealedBox = try? AES.GCM.SealedBox(combined: payload),
              let decrypted = try? AES.GCM.open(sealedBox, using: key) else {
            return nil
        }
        return decrypted
    }
    
    // MARK: - Deprecated Crypto v3 (PBKDF2-SHA1 Legacy Fallback)
    
    func deriveSymmetricKey(_ password: String) -> SymmetricKey {
        let salt = Array("TTZipVaultSalt2026".utf8)
        var derivedKey = [UInt8](repeating: 0, count: 32)
        let passBytes = Array(password.utf8)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password, passBytes.count,
            salt, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
            10000,
            &derivedKey, 32
        )
        if status == kCCSuccess {
            return SymmetricKey(data: Data(derivedKey))
        }
        let hash = SHA256.hash(data: Data(password.utf8))
        return SymmetricKey(data: hash)
    }
    
    func encryptData(_ data: Data, password: String) -> Data? {
        let key = deriveSymmetricKey(password)
        guard let sealedBox = try? AES.GCM.seal(data, using: key),
              let combined = sealedBox.combined else {
            return nil
        }
        return combined
    }
    
    func decryptData(_ data: Data, password: String) -> Data? {
        let key = deriveSymmetricKey(password)
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(sealedBox, using: key) else {
            return nil
        }
        return decrypted
    }
    
    func loadConfigInternal() {
        if !PasswordVaultManager.isCLIProcess,
           let keychainData = loadFromKeychain(account: "MasterHash"),
           let hash = String(data: keychainData, encoding: .utf8), !hash.isEmpty {
            setMasterPasswordHashInternal(hash)
            return
        }
        
        guard FileManager.default.fileExists(atPath: configFileURL.path) else { return }
        if let data = try? Data(contentsOf: configFileURL),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let hash = dict["masterHash"] {
            setMasterPasswordHashInternal(hash)
        }
    }
    
    func saveConfigLocked() {
        guard let hash = masterPasswordHash else { return }
        let dict = ["masterHash": hash]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            try? data.write(to: configFileURL, options: .atomic)
        }
        saveToKeychain(account: "MasterHash", data: Data(hash.utf8))
    }
    
    func loadVaultLocked(password: String) {
        // 1. Prioritize v4 vault format
        if FileManager.default.fileExists(atPath: vaultFileURL.path) {
            do {
                let encryptedData = try Data(contentsOf: vaultFileURL)
                if let rawJSON = decryptDataV4(encryptedData, password: password) {
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode([PasswordVaultEntry].self, from: rawJSON)
                    setEntriesInternal(decoded)
                    return
                }
            } catch {
                // v4 load failure fallback
            }
        }
        
        // 2. Automatic migration fallback from legacy v3 format
        if FileManager.default.fileExists(atPath: v3VaultFileURL.path) {
            do {
                let v3Data = try Data(contentsOf: v3VaultFileURL)
                if let rawJSON = decryptData(v3Data, password: password) {
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode([PasswordVaultEntry].self, from: rawJSON)
                    setEntriesInternal(decoded)
                    
                    // Seamless re-encryption with v4 (PBKDF2-SHA256 + random salt)
                    activeMasterPassword = password
                    _isUnlocked = true
                    saveVaultLocked()
                    try? FileManager.default.removeItem(at: v3VaultFileURL)
                    TTLogger.info("[PasswordVaultManager] Upgraded vault from v3 (SHA1) to v4 (SHA256 + Random Salt)")
                    return
                }
            } catch {
                // v3 decrypt failure fallback
            }
        }
        
        setEntriesInternal([])
    }
    
    func saveVaultLocked() {
        guard _isUnlocked, let password = activeMasterPassword else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let rawJSON = try encoder.encode(entries)
            
            if let encryptedData = encryptDataV4(rawJSON, password: password) {
                try encryptedData.write(to: vaultFileURL, options: .atomic)
            }
        } catch {
            TTLogger.error("Failed to encrypt vault: \(error.localizedDescription)")
        }
    }
    
    private var isCLIProcess: Bool {
        let procName = ProcessInfo.processInfo.processName.lowercased()
        if procName.contains("cli") || procName.contains("bench") || procName.contains("swift") || procName.contains("xctest") {
            return true
        }
        if CommandLine.arguments.contains(where: { $0.contains("bench") || $0.contains("test") || $0.contains("cli") }) {
            return true
        }
        if let bundleId = Bundle.main.bundleIdentifier, bundleId.contains("com.ttzip.app") {
            return false
        }
        return true
    }
    
    private func applyCLIUIPrevention(to query: inout [String: Any]) {
        if isCLIProcess {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
            query[kSecUseAuthenticationUI as String] = kCFBooleanFalse
        }
    }
    
    // MARK: - Keychain Services
    
    func saveToKeychain(account: String, data: Data) {
        if PasswordVaultManager.isCLIProcess { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ttzip.app.vault",
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]
        applyCLIUIPrevention(to: &query)
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func loadFromKeychain(account: String) -> Data? {
        if PasswordVaultManager.isCLIProcess { return nil }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ttzip.app.vault",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        applyCLIUIPrevention(to: &query)
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        return nil
    }
    
    func deleteFromKeychain(account: String) {
        if PasswordVaultManager.isCLIProcess { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ttzip.app.vault",
            kSecAttrAccount as String: account
        ]
        applyCLIUIPrevention(to: &query)
        SecItemDelete(query as CFDictionary)
    }
}
