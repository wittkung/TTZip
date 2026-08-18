// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// Test suite validating gap bridging features: solid archiving, file watching,
/// dictionary-based password recovery, password vault manager lifecycle, and Finder sync helpers.
final class GapBridgingTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    /// Tests solid archive creation using TAR.ZST container.
    func testSolidArchiveEngineCreation() async throws {
        let sample1 = (tempDirPath as NSString).appendingPathComponent("code1.swift")
        let sample2 = (tempDirPath as NSString).appendingPathComponent("code2.swift")
        try "print('Hello 1')".write(toFile: sample1, atomically: true, encoding: .utf8)
        try "print('Hello 2')".write(toFile: sample2, atomically: true, encoding: .utf8)
        
        let solidZip = (tempDirPath as NSString).appendingPathComponent("solid_result.tar.zst")
        let engine = SolidArchiveEngine()
        try await engine.createSolidArchive(outputPath: solidZip, inputPaths: [sample1, sample2])
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: solidZip))
    }
    
    /// Tests file watcher registration and notification callback.
    func testFileWatcherEngineRegistration() {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("watch_me.txt")
        try? "Initial Content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let watcher = FileWatcherEngine.shared
        watcher.watchFileForChanges(filePath: sampleFile, targetArchivePath: "/tmp/dummy.zip") { path, archive in
            XCTAssertEqual(path, sampleFile)
        }
        
        watcher.stopWatching(filePath: sampleFile)
    }
    
    /// Tests dictionary attack based password recovery engine.
    func testPasswordRecoveryEngine() async throws {
        let dummyZip = (tempDirPath as NSString).appendingPathComponent("dummy_pwd.zip")
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("pwd_sample.txt")
        try "Secret content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: dummyZip, format: .zip, level: .normal, inputPaths: [sampleFile], password: "password")

        let engine = PasswordRecoveryEngine()
        let dictionary = ["123456", "admin", "password", "TTZipSecurePassword2026", "secret"]

        let result = try await engine.recoverPassword(archivePath: dummyZip, dictionary: dictionary)

        XCTAssertEqual(result.foundPassword, "password")
        XCTAssertGreaterThan(result.totalAttempts, 0)
    }
    
    /// Tests PasswordVaultManager persistence, master password reset, and backup vault recovery.
    func testPasswordVaultManager() {
        PasswordVaultManager.shared.resetToFirstRunState()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VaultTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let vault = PasswordVaultManager(
            vaultURL: tempDir.appendingPathComponent("vault.enc"),
            configURL: tempDir.appendingPathComponent("config.json"),
            backupURL: tempDir.appendingPathComponent("backup.enc")
        )
        
        let originalMaster = "OriginalMasterKey#2026"
        vault.setMasterPassword(originalMaster)
        let initialCount = vault.getEntries().count
        
        vault.addEntry(label: "UnitTest Vault Key", password: "SecretPassword#2026", category: "Testing")
        XCTAssertEqual(vault.getEntries().count, initialCount + 1)
        
        // Reopen vault from persistent disk storage
        let reopenedVault = PasswordVaultManager(
            vaultURL: tempDir.appendingPathComponent("vault.enc"),
            configURL: tempDir.appendingPathComponent("config.json"),
            backupURL: tempDir.appendingPathComponent("backup.enc")
        )
        XCTAssertTrue(reopenedVault.isMasterPasswordSet)
        XCTAssertFalse(reopenedVault.isUnlocked)
        
        let unlockSuccess = reopenedVault.unlockVault(with: originalMaster)
        XCTAssertTrue(unlockSuccess)
        XCTAssertEqual(reopenedVault.getEntries().count, initialCount + 1, "Password vault entries failed to recover from disk after reopening and unlocking")
        
        // Reset master password creating backup vault
        vault.resetMasterPassword(newMasterPassword: "NewMasterKey#2026")
        XCTAssertTrue(vault.hasBackupVault)
        XCTAssertEqual(vault.getEntries().count, 0) // Vault is cleared after master password reset
        
        // Recover from backup vault
        let recoverySuccess = vault.recoverBackupVault(withOriginalMasterPassword: originalMaster)
        XCTAssertTrue(recoverySuccess)
        XCTAssertGreaterThanOrEqual(vault.getEntries().count, 1)
        
        let randomPwd = vault.generateRandomPassword(length: 20)
        XCTAssertEqual(randomPwd.count, 20)
        
        let strength = vault.evaluatePasswordStrength(randomPwd)
        XCTAssertGreaterThanOrEqual(strength.score, 3)
        
        vault.resetToFirstRunState()
    }
    
    /// Tests FinderSyncHelper context menu items generation for files and directories.
    func testFinderSyncHelperContextMenu() {
        let helper = FinderSyncHelper.shared
        
        let zipURL = URL(fileURLWithPath: "/tmp/demo.zip")
        let itemsZip = helper.getContextMenuItems(selectedURLs: [zipURL])
        XCTAssertEqual(itemsZip.count, 5)
        XCTAssertTrue(itemsZip.first?.title.contains("解压") == true || itemsZip.first?.title.contains("Extract") == true)
        
        let folderURL = URL(fileURLWithPath: "/tmp/my_folder")
        let itemsFolder = helper.getContextMenuItems(selectedURLs: [folderURL])
        XCTAssertEqual(itemsFolder.count, 5)
        XCTAssertTrue(itemsFolder.first?.title.contains("7z") == true)
    }
    
    /// Tests recursive directory archiving with nested folder structures.
    func testDirectoryRecursiveArchiveCreation() async throws {
        let writer = ArchiveWriter()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TestDir_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let subDir = tempDir.appendingPathComponent("SubFolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let file1 = tempDir.appendingPathComponent("root_file.txt")
        let file2 = subDir.appendingPathComponent("sub_file.txt")
        try "Hello Root".write(to: file1, atomically: true, encoding: .utf8)
        try "Hello Sub".write(to: file2, atomically: true, encoding: .utf8)
        
        let outputZip = tempDir.appendingPathComponent("output.7z").path
        try await writer.createArchive(outputPath: outputZip, format: .sevenZip, level: .normal, inputPaths: [tempDir.path])
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputZip)
        XCTAssertGreaterThanOrEqual(entries.count, 2)
    }
}
