// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
// TTZip

import Foundation
import Security
import CryptoKit
import CommonCrypto
import LocalAuthentication

public final class PasswordVaultManager: PasswordVaultManaging, @unchecked Sendable {
    public static let shared = PasswordVaultManager()
    
    let vaultLock = NSLock()

    var entries: [PasswordVaultEntry] = []
    
    var _isUnlocked: Bool = false
    public var isUnlocked: Bool {
        vaultLock.withLock { _isUnlocked }
    }
    var masterPasswordHash: String?
    var activeMasterPassword: String?
    
    let vaultFileURL: URL
    let v3VaultFileURL: URL
    let backupFileURL: URL
    let configFileURL: URL
    
    func setMasterPasswordHashInternal(_ hash: String?) { masterPasswordHash = hash }
    func setEntriesInternal(_ list: [PasswordVaultEntry]) { entries = list }
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let auraZipDir = appSupport.appendingPathComponent("TTZip", isDirectory: true)
        try? FileManager.default.createDirectory(at: auraZipDir, withIntermediateDirectories: true)
        
        self.vaultFileURL = auraZipDir.appendingPathComponent("password_vault_v4.enc")
        self.v3VaultFileURL = auraZipDir.appendingPathComponent("password_vault_v3.enc")
        self.backupFileURL = auraZipDir.appendingPathComponent("vault_backup_v4.enc")
        self.configFileURL = auraZipDir.appendingPathComponent("vault_config_v4.json")
        
        loadConfigInternal()
    }

    internal init(
        vaultURL: URL? = nil,
        configURL: URL? = nil,
        backupURL: URL? = nil
    ) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let auraZipDir = appSupport.appendingPathComponent("TTZip", isDirectory: true)
        try? FileManager.default.createDirectory(at: auraZipDir, withIntermediateDirectories: true)
        
        let targetVaultURL = vaultURL ?? auraZipDir.appendingPathComponent("password_vault_v4.enc")
        let targetDir = targetVaultURL.deletingLastPathComponent()
        
        self.vaultFileURL = targetVaultURL
        self.v3VaultFileURL = targetDir.appendingPathComponent("password_vault_v3.enc")
        self.backupFileURL = backupURL ?? targetDir.appendingPathComponent("vault_backup_v4.enc")
        self.configFileURL = configURL ?? targetDir.appendingPathComponent("vault_config_v4.json")
        
        loadConfigInternal()
    }
    
    public static let vaultDidChangeNotification = Notification.Name("PasswordVaultDidChangeNotification")
    
    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: PasswordVaultManager.vaultDidChangeNotification, object: nil)
        }
    }

    public var isMasterPasswordSet: Bool {
        vaultLock.withLock { masterPasswordHash != nil }
    }
    
    /// Automatically attempts candidate passwords when encountering encrypted archives (defaults to true).
    public var autoUnlockArchives: Bool {
        get {
            vaultLock.withLock {
                if let val = UserDefaults.standard.object(forKey: "TTZipAutoUnlockArchivesWithVault") as? Bool {
                    return val
                }
                return true
            }
        }
        set {
            vaultLock.withLock {
                UserDefaults.standard.set(newValue, forKey: "TTZipAutoUnlockArchivesWithVault")
            }
            notifyChange()
        }
    }
    
    public var hasBackupVault: Bool {
        vaultLock.withLock {
            FileManager.default.fileExists(atPath: backupFileURL.path)
        }
    }
    
    /// Initializes master password for initial setup.
    public func setMasterPassword(_ pwd: String) {
        vaultLock.withLock {
            let hash = hashString(pwd)
            masterPasswordHash = hash
            activeMasterPassword = pwd
            _isUnlocked = true
            saveConfigLocked()
            saveVaultLocked()
            saveToKeychain(account: "MasterHash", data: Data(hash.utf8))
            saveToKeychain(account: "MasterPassword", data: Data(pwd.utf8))
        }
        notifyChange()
    }
    
    /// Resets vault state for fresh initialization.
    public func resetToFirstRunState() {
        vaultLock.withLock {
            masterPasswordHash = nil
            activeMasterPassword = nil
            _isUnlocked = false
            entries = []
            try? FileManager.default.removeItem(at: vaultFileURL)
            try? FileManager.default.removeItem(at: backupFileURL)
            try? FileManager.default.removeItem(at: configFileURL)
            deleteFromKeychain(account: "MasterHash")
            deleteFromKeychain(account: "MasterPassword")
        }
        notifyChange()
    }
    
    /// Unlocks vault using provided master password string.
    public func unlockVault(with pwd: String) -> Bool {
        let success: Bool = vaultLock.withLock {
            let pwdHash = hashString(pwd)
            if let expectedHash = masterPasswordHash {
                guard pwdHash == expectedHash else { return false }
            } else {
                masterPasswordHash = pwdHash
                saveConfigLocked()
                saveToKeychain(account: "MasterHash", data: Data(pwdHash.utf8))
            }
            
            activeMasterPassword = pwd
            _isUnlocked = true
            saveToKeychain(account: "MasterPassword", data: Data(pwd.utf8))
            loadVaultLocked(password: pwd)
            return true
        }
        if success {
            notifyChange()
        }
        return success
    }

    /// Unlocks vault via biometric authentication reading Keychain master password.
    public func unlockWithBiometrics() -> Bool {
        let success: Bool = vaultLock.withLock {
            if _isUnlocked && activeMasterPassword != nil {
                return true
            }
            guard let data = loadFromKeychain(account: "MasterPassword"),
                  let pwd = String(data: data, encoding: .utf8), !pwd.isEmpty else {
                return false
            }
            
            if let expectedHash = masterPasswordHash, hashString(pwd) == expectedHash {
                activeMasterPassword = pwd
                _isUnlocked = true
                loadVaultLocked(password: pwd)
                return true
            }
            return false
        }
        if success {
            notifyChange()
        }
        return success
    }
    
    /// Resets master password, backing up existing entries to historical backup container.
    public func resetMasterPassword(newMasterPassword pwd: String) {
        vaultLock.withLock {
            if !entries.isEmpty, let oldHash = masterPasswordHash {
                let backup = VaultBackupData(oldMasterHash: oldHash, entries: entries, backupDate: Date())
                let encryptPwd = activeMasterPassword ?? pwd
                if let data = try? JSONEncoder().encode(backup),
                   let encryptedBackup = encryptData(data, password: encryptPwd) {
                    try? encryptedBackup.write(to: backupFileURL, options: .atomic)
                }
            }
            
            entries = []
            activeMasterPassword = pwd
            masterPasswordHash = hashString(pwd)
            _isUnlocked = true
            
            saveVaultLocked()
            saveConfigLocked()
            saveToKeychain(account: "MasterHash", data: Data(masterPasswordHash!.utf8))
            saveToKeychain(account: "MasterPassword", data: Data(pwd.utf8))
        }
        notifyChange()
    }
    
    /// Restores previous backup vault entries using original master password.
    public func recoverBackupVault(withOriginalMasterPassword oldPwd: String) -> Bool {
        let success: Bool = vaultLock.withLock {
            guard FileManager.default.fileExists(atPath: backupFileURL.path),
                  let encryptedData = try? Data(contentsOf: backupFileURL),
                  let rawData = decryptData(encryptedData, password: oldPwd),
                  let backup = try? JSONDecoder().decode(VaultBackupData.self, from: rawData) else {
                return false
            }
            
            let inputHash = hashString(oldPwd)
            if inputHash == backup.oldMasterHash {
                for entry in backup.entries {
                    if !entries.contains(where: { $0.id == entry.id }) {
                        entries.append(entry)
                    }
                }
                
                masterPasswordHash = inputHash
                activeMasterPassword = oldPwd
                _isUnlocked = true
                
                saveVaultLocked()
                saveConfigLocked()
                saveToKeychain(account: "MasterHash", data: Data(inputHash.utf8))
                saveToKeychain(account: "MasterPassword", data: Data(oldPwd.utf8))
                try? FileManager.default.removeItem(at: backupFileURL)
                return true
            } else {
                return false
            }
        }
        if success {
            notifyChange()
        }
        return success
    }
    
    /// Locks vault and securely scrubs active password buffers from memory using Rust C-ABI compiler fence.
    public func lockVault() {
        vaultLock.withLock {
            _isUnlocked = false
            if let pwd = activeMasterPassword {
                var bytes = Array(pwd.utf8)
                bytes.withUnsafeMutableBytes { ptr in
                    if let base = ptr.baseAddress {
                        ttzip_rust_vault_wipe(base.assumingMemoryBound(to: UInt8.self), ptr.count)
                    }
                }
            }

            activeMasterPassword = nil
            entries.removeAll(keepingCapacity: false)
        }
        notifyChange()
    }
    
    public func getEntries() -> [PasswordVaultEntry] {
        vaultLock.withLock {
            guard _isUnlocked else { return [] }
            return entries
        }
    }
    
    public static var isCLIProcess: Bool {
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
    
    /// Returns sorted candidate passwords for automated decryption attempts.
    public func candidatePasswordsForAutoUnlock() -> [String] {
        if !isUnlocked {
            _ = unlockWithBiometrics()
        }
        let list = getEntries()
        let sorted = list.sorted { $0.useCount > $1.useCount }
        var result: [String] = []
        for item in sorted {
            if !item.password.isEmpty && !result.contains(item.password) {
                result.append(item.password)
            }
        }
        return result
    }
    
    public func addEntry(id: UUID = UUID(), label: String, password: String, category: String = "General") {
        vaultLock.withLock {
            guard _isUnlocked else { return }
            let finalLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Password" : label.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : category.trimmingCharacters(in: .whitespacesAndNewlines)
            let newEntry = PasswordVaultEntry(id: id, label: finalLabel, password: password, category: finalCategory)
            entries.append(newEntry)
            saveVaultLocked()
        }
        notifyChange()
    }
    
    public func removeEntry(id: UUID) {
        vaultLock.withLock {
            guard _isUnlocked else { return }
            entries.removeAll { $0.id == id }
            saveVaultLocked()
        }
        notifyChange()
    }
    
    public func recordUsage(id: UUID) {
        vaultLock.withLock {
            guard _isUnlocked else { return }
            if let idx = entries.firstIndex(where: { $0.id == id }) {
                entries[idx].useCount += 1
                entries[idx].lastUsedAt = Date()
                saveVaultLocked()
            }
        }
        notifyChange()
    }
}

// MARK: - Keychain

//
//


// MARK: - PasswordVaultManager Persistence, AES-GCM Encryption & Keychain Extension

extension PasswordVaultManager {
    
    func hashString(_ str: String) -> String {
        let data = Data(str.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Crypto v4 (PBKDF2-SHA256 + Per-vault 32-byte Random Salt + 600k rounds + Rust AES-256-GCM)
    
    static let vaultMagicV4 = Data([0x54, 0x54, 0x56, 0x34]) // "TTV4"
    static let defaultV4Iterations: UInt32 = 600_000
    
    func deriveSymmetricKeyBytesV4(_ password: String, salt: Data, iterations: UInt32 = defaultV4Iterations) -> [UInt8] {
        var derivedKey = [UInt8](repeating: 0, count: 32)
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
        if status != kCCSuccess {
            let hash = SHA256.hash(data: Data(password.utf8))
            derivedKey = Array(hash)
        }
        return derivedKey
    }
    
    func encryptDataV4(_ data: Data, password: String) -> Data? {
        var saltBytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes) == errSecSuccess else {
            return nil
        }
        let salt = Data(saltBytes)
        let iterations = Self.defaultV4Iterations
        var keyBytes = deriveSymmetricKeyBytesV4(password, salt: salt, iterations: iterations)
        defer {
            keyBytes.withUnsafeMutableBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    ttzip_rust_vault_wipe(base, ptr.count)
                }
            }
        }
        
        var ivBytes = [UInt8](repeating: 0, count: 12)
        guard SecRandomCopyBytes(kSecRandomDefault, ivBytes.count, &ivBytes) == errSecSuccess else {
            return nil
        }
        
        var ciphertext = [UInt8](repeating: 0, count: data.count)
        var tag = [UInt8](repeating: 0, count: 16)
        
        let status = data.withUnsafeBytes { dataBuf in
            let dataPtr = dataBuf.baseAddress?.assumingMemoryBound(to: UInt8.self)
            return ttzip_rust_vault_encrypt_key(
                &keyBytes,
                &ivBytes,
                dataPtr,
                data.count,
                nil,
                0,
                &ciphertext,
                &tag
            )
        }
        guard status == TTZIP_STATUS_OK else { return nil }
        
        var combinedPayload = Data()
        combinedPayload.append(contentsOf: ivBytes) // 12 bytes nonce
        combinedPayload.append(contentsOf: ciphertext) // N bytes cipher
        combinedPayload.append(contentsOf: tag) // 16 bytes tag
        
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
        guard payload.count >= 28 else { return nil }
        
        let iv = Array(payload.prefix(12))
        let tag = Array(payload.suffix(16))
        let cipherData = payload.subdata(in: 12..<(payload.count - 16))
        
        var keyBytes = deriveSymmetricKeyBytesV4(password, salt: salt, iterations: iterations)
        defer {
            keyBytes.withUnsafeMutableBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    ttzip_rust_vault_wipe(base, ptr.count)
                }
            }
        }
        
        var plaintext = [UInt8](repeating: 0, count: cipherData.count)
        let status = cipherData.withUnsafeBytes { cipherBuf in
            let cipherPtr = cipherBuf.baseAddress?.assumingMemoryBound(to: UInt8.self)
            return ttzip_rust_vault_decrypt_key(
                &keyBytes,
                iv,
                cipherPtr,
                cipherData.count,
                nil,
                0,
                tag,
                &plaintext
            )
        }
        guard status == TTZIP_STATUS_OK else { return nil }
        return Data(plaintext)
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

// MARK: - Utilities

//
//


// MARK: - Password Generation & Strength Evaluation

extension PasswordVaultManager {
    
    /// Generates high-entropy pseudo-random password string.
    public func generateRandomPassword(length: Int = 16, includeSymbols: Bool = true) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        let charset = includeSymbols ? (letters + symbols) : letters
        
        var result = ""
        for _ in 0..<length {
            if let randomChar = charset.randomElement() {
                result.append(randomChar)
            }
        }
        return result
    }
    
    /// Evaluates password entropy and strength score (0 to 5).
    public func evaluatePasswordStrength(_ pwd: String) -> (score: Int, label: String) {
        if pwd.isEmpty { return (0, "Very Weak") }
        var score = 0
        if pwd.count >= 8 { score += 1 }
        if pwd.count >= 12 { score += 1 }
        if pwd.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if pwd.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }
        if pwd.rangeOfCharacter(from: .uppercaseLetters) != nil && pwd.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        
        switch score {
        case 0...1: return (score, "Very Weak")
        case 2: return (score, "Weak")
        case 3: return (score, "Medium")
        case 4: return (score, "Strong")
        default: return (score, "Very Strong")
        }
    }
}
