import Foundation
import CryptoKit
import Security
import CTTZipBridge

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
        category: String = "通用",
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

public struct VaultBackupData: Codable {
    public let oldMasterHash: String
    public let entries: [PasswordVaultEntry]
    public let backupDate: Date
}

/// 密码库抽象管理接口 (支持依赖注入与解耦)
public protocol PasswordVaultManaging: Sendable {
    var autoUnlockArchives: Bool { get }
    func getEntries() -> [PasswordVaultEntry]
    func recordUsage(id: UUID)
}

/// macOS Apple 最佳实践集中式高安全性密码库管理器 (AES-256 GCM 硬件加密持久化 + Keychain + 找回保护)
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
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: PasswordVaultManager.vaultDidChangeNotification, object: nil)
            ArchiveEventCenter.shared.postPasswordVaultUnlocked(archivePath: "", password: "", isVaultUnlocked: self.isUnlocked)
        }
    }

    public var isMasterPasswordSet: Bool {
        vaultLock.withLock { masterPasswordHash != nil }
    }
    
    /// 自动使用已解锁密码库中的口令解密压缩包设置 (默认 true)
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
    
    /// 首次设置主口令
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
    
    /// 首次与重置隔离清理
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
    
    /// 校验主口令解密并加载持久化数据
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

    /// Touch ID / 生物识别解锁真正的密码库（安全提取 Keychain 中的 MasterPassword）
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
    
    /// 忘记密码/重置主口令：将原有加密库移入历史备份库，并清空当前主口令
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
    
    /// 找回历史密码库：凭原口令解密历史备份数据并合并
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
    
    public func lockVault() {
        vaultLock.withLock {
            _isUnlocked = false
            if let pwd = activeMasterPassword {
                var bytes = Array(pwd.utf8)
                bytes.withUnsafeMutableBytes { ptr in
                    if let base = ptr.baseAddress {
                        PlatformMemory.secureZero(pointer: base, byteCount: ptr.count)
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
    
    /// 自动为加密归档尝试已保存口令候选池 (优先按使用频率降序排列)
    public func candidatePasswordsForAutoUnlock() -> [String] {
        if !isUnlocked {
            if PasswordVaultManager.isCLIProcess {
                return []
            }
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
    
    public func addEntry(id: UUID = UUID(), label: String, password: String, category: String = "通用") {
        vaultLock.withLock {
            guard _isUnlocked else { return }
            let finalLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "解压口令" : label.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "通用" : category.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    /// 强随机密码生成器
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
    
    /// 评估密码强度 (1-5 级)
    public func evaluatePasswordStrength(_ pwd: String) -> (score: Int, label: String) {
        if pwd.isEmpty { return (0, "极弱") }
        var score = 0
        if pwd.count >= 8 { score += 1 }
        if pwd.count >= 12 { score += 1 }
        if pwd.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if pwd.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }
        if pwd.rangeOfCharacter(from: .uppercaseLetters) != nil && pwd.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        
        switch score {
        case 0...1: return (score, "极弱 (易破解)")
        case 2: return (score, "弱")
        case 3: return (score, "中等")
        case 4: return (score, "强")
        default: return (score, "极高安全 (推荐)")
        }
    }
}
