import XCTest
@testable import TTZipCore

final class PasswordVaultV4Tests: XCTestCase {
    
    func testVaultV4EncryptionDecryptionAndRandomSalt() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let vaultURL = tempDir.appendingPathComponent("vault_test_v4.enc")
        let configURL = tempDir.appendingPathComponent("config_test_v4.json")
        let backupURL = tempDir.appendingPathComponent("backup_test_v4.enc")
        
        let manager1 = PasswordVaultManager(vaultURL: vaultURL, configURL: configURL, backupURL: backupURL)
        let masterPassword = "TestMasterPassword2026!"
        
        manager1.setMasterPassword(masterPassword)
        XCTAssertTrue(manager1.unlockVault(with: masterPassword))
        
        manager1.addEntry(label: "GitHub Key", password: "ghp_secure_token_123", category: "开发")
        manager1.addEntry(label: "Email Pass", password: "secret_email_pwd", category: "个人")
        
        XCTAssertEqual(manager1.getEntries().count, 2)
        
        // 验证文件存在且头部包含 Magic TTV4
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
        let encryptedData = try! Data(contentsOf: vaultURL)
        XCTAssertGreaterThanOrEqual(encryptedData.count, 69)
        XCTAssertEqual(encryptedData.prefix(4), PasswordVaultManager.vaultMagicV4)
        
        // 使用新实例再次解锁并验证解密
        let manager2 = PasswordVaultManager(vaultURL: vaultURL, configURL: configURL, backupURL: backupURL)
        XCTAssertTrue(manager2.unlockVault(with: masterPassword))
        let loadedEntries = manager2.getEntries()
        XCTAssertEqual(loadedEntries.count, 2)
        XCTAssertEqual(loadedEntries[0].label, "GitHub Key")
        XCTAssertEqual(loadedEntries[0].password, "ghp_secure_token_123")
        XCTAssertEqual(loadedEntries[1].label, "Email Pass")
        XCTAssertEqual(loadedEntries[1].password, "secret_email_pwd")
    }
    
    func testVaultV3ToV4AutomaticMigration() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let v4VaultURL = tempDir.appendingPathComponent("password_vault_v4.enc")
        let v3VaultURL = tempDir.appendingPathComponent("password_vault_v3.enc")
        let configURL = tempDir.appendingPathComponent("vault_config_v4.json")
        let backupURL = tempDir.appendingPathComponent("vault_backup_v4.enc")
        
        let masterPassword = "MigrationPassword2026"
        
        // 手动构造一个旧版 v3 加密 Vault 文件
        let oldEntries = [
            PasswordVaultEntry(label: "Legacy Service", password: "legacy_password_v3", category: "旧版")
        ]
        let rawJSON = try! JSONEncoder().encode(oldEntries)
        
        // 旧版 v3 加密方式 (PBKDF2-SHA1)
        let managerSetup = PasswordVaultManager(vaultURL: v4VaultURL, configURL: configURL, backupURL: backupURL)
        let v3Encrypted = managerSetup.encryptData(rawJSON, password: masterPassword)!
        try! v3Encrypted.write(to: v3VaultURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: v3VaultURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: v4VaultURL.path))
        
        // 触发自动无感迁移
        let managerMigrated = PasswordVaultManager(vaultURL: v4VaultURL, configURL: configURL, backupURL: backupURL)
        XCTAssertTrue(managerMigrated.unlockVault(with: masterPassword))
        
        // 验证条目被成功解密
        let entries = managerMigrated.getEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].label, "Legacy Service")
        XCTAssertEqual(entries[0].password, "legacy_password_v3")
        
        // 验证 v4 文件已被写出且包含 TTV4 魔数
        XCTAssertTrue(FileManager.default.fileExists(atPath: v4VaultURL.path))
        let v4Data = try! Data(contentsOf: v4VaultURL)
        XCTAssertEqual(v4Data.prefix(4), PasswordVaultManager.vaultMagicV4)
        
        // 验证旧的 v3 文件已被安全清理删除
        XCTAssertFalse(FileManager.default.fileExists(atPath: v3VaultURL.path))
    }
}
