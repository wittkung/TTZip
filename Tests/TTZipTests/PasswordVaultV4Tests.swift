// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

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
        
        // Magic TTV4
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.path))
        let encryptedData = try! Data(contentsOf: vaultURL)
        XCTAssertGreaterThanOrEqual(encryptedData.count, 69)
        XCTAssertEqual(encryptedData.prefix(4), PasswordVaultManager.vaultMagicV4)
        
        // Verify expected invariant
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
        
        // v3 Vault
        let oldEntries = [
            PasswordVaultEntry(label: "Legacy Service", password: "legacy_password_v3", category: "旧版")
        ]
        let rawJSON = try! JSONEncoder().encode(oldEntries)
        
        // v3 (PBKDF2-SHA1)
        let managerSetup = PasswordVaultManager(vaultURL: v4VaultURL, configURL: configURL, backupURL: backupURL)
        let v3Encrypted = managerSetup.encryptData(rawJSON, password: masterPassword)!
        try! v3Encrypted.write(to: v3VaultURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: v3VaultURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: v4VaultURL.path))
        
        // Verify expected invariant
        let managerMigrated = PasswordVaultManager(vaultURL: v4VaultURL, configURL: configURL, backupURL: backupURL)
        XCTAssertTrue(managerMigrated.unlockVault(with: masterPassword))
        
        // Verify expected invariant
        let entries = managerMigrated.getEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].label, "Legacy Service")
        XCTAssertEqual(entries[0].password, "legacy_password_v3")
        
        // v4 TTV4
        XCTAssertTrue(FileManager.default.fileExists(atPath: v4VaultURL.path))
        let v4Data = try! Data(contentsOf: v4VaultURL)
        XCTAssertEqual(v4Data.prefix(4), PasswordVaultManager.vaultMagicV4)
        
        // v3
        XCTAssertFalse(FileManager.default.fileExists(atPath: v3VaultURL.path))
    }
    
    func testRustVaultDirectEncryptDecryptCABI() {
        var key = [UInt8](repeating: 0x42, count: 32)
        var iv = [UInt8](repeating: 0x19, count: 12)
        let secretMessage = "TopSecretCredentialsData_2026"
        let plainData = Array(secretMessage.utf8)
        var cipher = [UInt8](repeating: 0, count: plainData.count)
        var tag = [UInt8](repeating: 0, count: 16)
        
        // Encrypt
        let encStatus = ttzip_rust_vault_encrypt_key(
            &key,
            &iv,
            plainData,
            plainData.count,
            nil,
            0,
            &cipher,
            &tag
        )
        XCTAssertEqual(encStatus, TTZIP_STATUS_OK)
        XCTAssertNotEqual(cipher, plainData)
        XCTAssertFalse(tag.allSatisfy { $0 == 0 })
        
        // Decrypt
        var decrypted = [UInt8](repeating: 0, count: cipher.count)
        let decStatus = ttzip_rust_vault_decrypt_key(
            &key,
            &iv,
            cipher,
            cipher.count,
            nil,
            0,
            tag,
            &decrypted
        )
        XCTAssertEqual(decStatus, TTZIP_STATUS_OK)
        XCTAssertEqual(decrypted, plainData)
        XCTAssertEqual(String(bytes: decrypted, encoding: .utf8), secretMessage)
        
        // Tampered tag rejection
        var corruptedTag = tag
        corruptedTag[0] ^= 0xFF
        var failedPlain = [UInt8](repeating: 0xEE, count: cipher.count)
        let failStatus = ttzip_rust_vault_decrypt_key(
            &key,
            &iv,
            cipher,
            cipher.count,
            nil,
            0,
            corruptedTag,
            &failedPlain
        )
        XCTAssertNotEqual(failStatus, TTZIP_STATUS_OK)
        XCTAssertTrue(failedPlain.allSatisfy { $0 == 0 }) // Wiped on error
    }
    
    func testRustVaultMemoryWipeCompilerFence() {
        var buffer = [UInt8](repeating: 0xAA, count: 128)
        buffer.withUnsafeMutableBufferPointer { ptr in
            if let base = ptr.baseAddress {
                ttzip_rust_vault_wipe(base, ptr.count)
            }
        }
        XCTAssertTrue(buffer.allSatisfy { $0 == 0 })
    }
    
    func testVaultLockAndSanitizationLifecycle() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let vaultURL = tempDir.appendingPathComponent("vault_lifecycle.enc")
        let configURL = tempDir.appendingPathComponent("config_lifecycle.json")
        let backupURL = tempDir.appendingPathComponent("backup_lifecycle.enc")
        
        let manager = PasswordVaultManager(vaultURL: vaultURL, configURL: configURL, backupURL: backupURL)
        let password = "LifecyclePassword2026"
        manager.setMasterPassword(password)
        manager.addEntry(label: "Key1", password: "val1", category: "General")
        
        XCTAssertTrue(manager.isUnlocked)
        XCTAssertEqual(manager.getEntries().count, 1)
        
        manager.lockVault()
        XCTAssertFalse(manager.isUnlocked)
        XCTAssertEqual(manager.getEntries().count, 0)
        
        // Re-unlock
        XCTAssertTrue(manager.unlockVault(with: password))
        XCTAssertTrue(manager.isUnlocked)
        XCTAssertEqual(manager.getEntries().count, 1)
        XCTAssertEqual(manager.getEntries()[0].password, "val1")
    }
}

