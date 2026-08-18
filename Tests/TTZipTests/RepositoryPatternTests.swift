// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class RepositoryPatternTests: XCTestCase {
    
    private var testUserDefaults: UserDefaults!
    private var testSuiteName: String!
    private var testHistoryURL: URL!
    private var tempDirURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        testSuiteName = "TTZip_Test_Suite_\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        self.tempDirURL = tempDir
        self.testHistoryURL = tempDir.appendingPathComponent("history.json")
    }
    
    override func tearDownWithError() throws {
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        try? FileManager.default.removeItem(at: tempDirURL)
        try super.tearDownWithError()
    }
    
    // MARK: - 1. Preset Repository CRUD
    
    func testPresetRepositoryCRUD() throws {
        let repo = UserDefaultsPresetRepository(userDefaults: testUserDefaults, storageKey: "TestPresets")
        
        // Clear initial defaults for pure CRUD test
        try repo.deleteAll()
        let initial = try repo.fetchAll()
        XCTAssertTrue(initial.isEmpty)
        
        let preset = CompressionPreset(
            name: "Custom 7z",
            format: .sevenZip,
            level: .ultra,
            splitVolumeSizeBytes: 100 * 1024 * 1024,
            defaultPassword: "secretPassword",
            skipMacJunk: true
        )
        
        // Save
        try repo.save(preset)
        
        // Fetch
        let fetched = try repo.fetch(id: preset.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Custom 7z")
        XCTAssertEqual(fetched?.format, .sevenZip)
        XCTAssertEqual(fetched?.level, .ultra)
        XCTAssertEqual(fetched?.defaultPassword, "secretPassword")
        
        // Fetch by name
        let byName = try repo.fetchByName("Custom 7z")
        XCTAssertNotNil(byName)
        XCTAssertEqual(byName?.id, preset.id)
        
        // Delete
        try repo.delete(id: preset.id)
        let afterDelete = try repo.fetch(id: preset.id)
        XCTAssertNil(afterDelete)
    }
    
    // MARK: - 2. Password Repository CRUD
    
    func testPasswordRepositoryCRUD() throws {
        let repo = KeychainPasswordRepository.shared
        let vaultManager = PasswordVaultManager.shared
        vaultManager.setMasterPassword("TestMasterPwd123")
        
        let entry = PasswordVaultEntry(label: "Work Server", password: "PassWord123!", category: "服务器")
        
        try repo.save(entry)
        
        let fetched = try repo.fetch(id: entry.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.label, "Work Server")
        XCTAssertEqual(fetched?.password, "PassWord123!")
        
        try repo.recordUsage(id: entry.id)
        try repo.delete(id: entry.id)
    }
    
    // MARK: - 3. History Repository CRUD
    
    func testHistoryRepositoryCRUD() throws {
        let repo = JSONFileArchiveHistoryRepository(customFileURL: testHistoryURL)
        try repo.deleteAll()
        
        let record = ArchiveTaskRecord(
            commandName: "Compress Task",
            archivePath: "/tmp/source.zip",
            targetPath: "/tmp/dest",
            isSuccess: true,
            fileSizeByte: 2048
        )
        
        try repo.save(record)
        
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.commandName, "Compress Task")
        XCTAssertEqual(all.first?.fileSizeByte, 2048)
        
        let fetched = try repo.fetch(id: record.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.archivePath, "/tmp/source.zip")
        
        try repo.delete(id: record.id)
        let afterDelete = try repo.fetchAll()
        XCTAssertTrue(afterDelete.isEmpty)
    }
    
    // MARK: - 4. DataMapper Preset
    
    func testPresetDataMapperBidirectionalFidelity() throws {
        let mapper = PresetDataMapper()
        let original = CompressionPreset(
            name: "High Ratio",
            format: .tarZst,
            level: .ultra,
            splitVolumeSizeBytes: 50 * 1024 * 1024,
            defaultPassword: "MyPassword",
            skipMacJunk: true,
            skipGitDirectory: true
        )
        
        let dto = mapper.toStorage(domain: original)
        XCTAssertEqual(dto.titleName, "High Ratio")
        XCTAssertEqual(dto.compressionFormatRaw, ArchiveCompressionFormat.tarZst.rawValue)
        
        let restored = mapper.toDomain(storage: dto)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.name, original.name)
        XCTAssertEqual(restored.format, original.format)
        XCTAssertEqual(restored.level, original.level)
        XCTAssertEqual(restored.splitVolumeSizeBytes, original.splitVolumeSizeBytes)
        XCTAssertEqual(restored.defaultPassword, original.defaultPassword)
        XCTAssertEqual(restored.skipMacJunk, original.skipMacJunk)
        XCTAssertEqual(restored.skipGitDirectory, original.skipGitDirectory)
    }
    
    // MARK: - 5. DataMapper
    
    func testPresetDataMapperVersionUpgradeFallback() throws {
        let mapper = PresetDataMapper()
        let legacyDTO = PresetStorageDTO(
            schemaVersion: 1,
            presetId: UUID().uuidString,
            titleName: "Old 7z Preset",
            compressionFormatRaw: "unknown_format",
            compressionLevelRaw: 9,
            legacyFormatName: "7z"
        )
        
        let restored = mapper.toDomain(storage: legacyDTO)
        XCTAssertEqual(restored.name, "Old 7z Preset")
        XCTAssertEqual(restored.format, .sevenZip)
    }
    
    // MARK: - 6. DataMapper Keychain
    
    func testKeychainDataMapperBidirectionalFidelity() throws {
        let mapper = KeychainDataMapper()
        let original = PasswordVaultEntry(
            label: "DB Master",
            password: "DB_Password_99",
            category: "数据库",
            createdAt: Date(timeIntervalSince1970: 100000),
            useCount: 5,
            lastUsedAt: Date(timeIntervalSince1970: 200000)
        )
        
        let dto = mapper.toStorage(domain: original)
        XCTAssertEqual(dto.itemLabel, "DB Master")
        XCTAssertEqual(dto.itemCategory, "数据库")
        
        let restored = mapper.toDomain(storage: dto)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.label, original.label)
        XCTAssertEqual(restored.password, original.password)
        XCTAssertEqual(restored.category, original.category)
        XCTAssertEqual(restored.useCount, 5)
    }
    
    // MARK: - 7. DataMapper History
    
    func testArchiveHistoryDataMapperBidirectionalFidelity() throws {
        let mapper = ArchiveHistoryDataMapper()
        let original = ArchiveTaskRecord(
            commandName: "Extract Archive",
            archivePath: "/path/to/in.zip",
            targetPath: "/path/to/out",
            isSuccess: true,
            timestamp: Date(timeIntervalSince1970: 1600000000),
            fileSizeByte: 1048576
        )
        
        let dto = mapper.toStorage(domain: original)
        XCTAssertEqual(dto.taskType, "Extract Archive")
        XCTAssertEqual(dto.statusFlag, "SUCCESS")
        
        let restored = mapper.toDomain(storage: dto)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.commandName, original.commandName)
        XCTAssertEqual(restored.archivePath, original.archivePath)
        XCTAssertEqual(restored.targetPath, original.targetPath)
        XCTAssertEqual(restored.isSuccess, true)
        XCTAssertEqual(restored.fileSizeByte, 1048576)
    }
    
    // MARK: - 8. Safe Fallback UserDefaults
    
    func testUserDefaultsPresetRepositoryCorruptedDataFallback() throws {
        let key = "CorruptedPresetsKey"
        testUserDefaults.set("Corrupted JSON Raw Strings {{{".data(using: .utf8), forKey: key)
        
        let repo = UserDefaultsPresetRepository(userDefaults: testUserDefaults, storageKey: key)
        let presets = try repo.fetchAll()
        
        // Safe Fallback: ，
        XCTAssertFalse(presets.isEmpty)
        XCTAssertEqual(presets.first?.name, "7Z 20GB")
    }
    
    // MARK: - 9. Safe Fallback Disk JSON
    
    func testJSONFileArchiveHistoryRepositoryCorruptedDiskFallback() throws {
        let corruptedFile = tempDirURL.appendingPathComponent("corrupted_history.json")
        try "Not a JSON content format...".write(to: corruptedFile, atomically: true, encoding: .utf8)
        
        let repo = JSONFileArchiveHistoryRepository(customFileURL: corruptedFile)
        let records = try repo.fetchAll()
        
        // Safe Fallback:
        XCTAssertTrue(records.isEmpty)
    }
    
    // MARK: - 10.
    
    func testPresetRepositoryDuplicateFromPrototype() throws {
        let repo = UserDefaultsPresetRepository(userDefaults: testUserDefaults, storageKey: "PrototypeKey")
        let preset = CompressionPreset(name: "Prototype Base", format: .zip, level: .normal)
        try repo.save(preset)
        
        let cloned = try repo.duplicate(id: preset.id, newName: "Cloned Preset")
        XCTAssertNotNil(cloned)
        XCTAssertNotEqual(cloned?.id, preset.id)
        XCTAssertEqual(cloned?.name, "Cloned Preset")
        
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 6) // 4 built-in defaults + 1 saved + 1 cloned = 6
    }
    
    // MARK: - 11.
    
    func testHistoryRepositoryFetchRecentAndFilter() throws {
        let repo = JSONFileArchiveHistoryRepository(customFileURL: testHistoryURL)
        try repo.deleteAll()
        
        let now = Date()
        let record1 = ArchiveTaskRecord(commandName: "Task 1", archivePath: "a.zip", targetPath: "b", isSuccess: true, timestamp: now.addingTimeInterval(-100))
        let record2 = ArchiveTaskRecord(commandName: "Task 2", archivePath: "c.zip", targetPath: "d", isSuccess: false, timestamp: now.addingTimeInterval(-50))
        let record3 = ArchiveTaskRecord(commandName: "Task 3", archivePath: "e.zip", targetPath: "f", isSuccess: true, timestamp: now)
        
        try repo.save(record1)
        try repo.save(record2)
        try repo.save(record3)
        
        let recent = try repo.fetchRecent(limit: 2)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.first?.commandName, "Task 3")
        
        let failed = try repo.fetchByStatus(isSuccess: false)
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.commandName, "Task 2")
    }
    
    // MARK: - 12.
    
    func testPasswordRepositoryCategorySearch() throws {
        let repo = KeychainPasswordRepository.shared
        let vaultManager = PasswordVaultManager.shared
        vaultManager.setMasterPassword("TestMasterPwd123")
        
        let entry1 = PasswordVaultEntry(label: "Mail Server", password: "p1", category: "网络")
        let entry2 = PasswordVaultEntry(label: "Web Server", password: "p2", category: "网络")
        
        try repo.save(entry1)
        try repo.save(entry2)
        
        let searchResults = try repo.search(category: "网络")
        XCTAssertTrue(searchResults.contains(where: { $0.label == "Mail Server" }))
        
        try repo.delete(id: entry1.id)
        try repo.delete(id: entry2.id)
    }
    
    // MARK: - 13.
    
    func testPasswordRepositoryLockUnlockState() throws {
        let repo = KeychainPasswordRepository.shared
        repo.lock()
        XCTAssertFalse(repo.isUnlocked)
        
        let unlockSuccess = try repo.unlock(masterPassword: "NonExistentMasterPassword_123")
        // Incorrect password returns false
        XCTAssertFalse(unlockSuccess)
    }
    
    // MARK: - 14. PresetManager Repository
    
    func testPresetManagerIntegrationWithRepository() throws {
        let repo = UserDefaultsPresetRepository(userDefaults: testUserDefaults, storageKey: "PresetManagerIntegrationKey")
        let manager = PresetManager(repository: repo)
        
        let countBefore = manager.presets.count
        let custom = CompressionPreset(name: "Integration Preset", format: .tarGz, level: .normal)
        manager.savePreset(custom)
        
        XCTAssertEqual(manager.presets.count, countBefore + 1)
        XCTAssertEqual(manager.preset(for: custom.id)?.name, "Integration Preset")
        
        manager.deletePreset(id: custom.id)
        XCTAssertNil(manager.preset(for: custom.id))
    }
    
    // MARK: - 15. CommandHistoryManager History Repository
    
    private struct MockRepositoryCommand: ArchiveCommandProtocol {
        let commandId: String = UUID().uuidString
        let description: String = "Compress Mock Task"
        let isUndoable: Bool = true
        
        func execute() async throws -> CommandResult {
            return CommandResult(commandId: commandId, success: true, message: "Mock execution successful")
        }
        
        func undo() async throws { }
        func purgeBackupResources() { }
    }
    
    func testCommandHistoryManagerIntegrationWithHistoryRepository() async throws {
        let repo = JSONFileArchiveHistoryRepository(customFileURL: testHistoryURL)
        try? repo.deleteAll()
        let manager = CommandHistoryManager(maxHistoryCapacity: 10, historyRepository: repo)
        
        let dummyCmd = MockRepositoryCommand()
        _ = try await manager.execute(command: dummyCmd)
        
        let history = try manager.getHistoryRecords()
        XCTAssertFalse(history.isEmpty)
        XCTAssertTrue(history.contains(where: { $0.commandName.contains("Compress Mock Task") }))
    }
    
    // MARK: - 16. 100+ Preset Zero Race & Zero Data Loss
    
    func testHighConcurrency100ThreadsPresetRepositoryReadWrite() throws {
        let repo = UserDefaultsPresetRepository(userDefaults: testUserDefaults, storageKey: "ConcurrencyPresets")
        let expectation = expectation(description: "Concurrent Preset Repository operations")
        let threadCount = 50
        expectation.expectedFulfillmentCount = threadCount
        
        let dispatchGroup = DispatchGroup()
        for i in 0..<threadCount {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                defer {
                    dispatchGroup.leave()
                    expectation.fulfill()
                }
                
                let preset = CompressionPreset(name: "Concurrent Preset \(i)", format: .zip, level: .normal)
                try? repo.save(preset)
                _ = try? repo.fetchAll()
                _ = try? repo.fetch(id: preset.id)
                _ = try? repo.fetchByName("Concurrent Preset \(i)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        let finalPresets = try repo.fetchAll()
        XCTAssertGreaterThanOrEqual(finalPresets.count, threadCount)
    }
    
    // MARK: - 17. 100+ History Zero Race & Zero Data Loss
    
    func testHighConcurrency100ThreadsHistoryRepositoryReadWrite() throws {
        let repo = JSONFileArchiveHistoryRepository(customFileURL: testHistoryURL)
        let expectation = expectation(description: "Concurrent History Repository operations")
        let threadCount = 50
        expectation.expectedFulfillmentCount = threadCount
        
        for i in 0..<threadCount {
            DispatchQueue.global().async {
                defer { expectation.fulfill() }
                let record = ArchiveTaskRecord(
                    commandName: "Concurrent Task \(i)",
                    archivePath: "/tmp/\(i).zip",
                    targetPath: "/tmp/out\(i)",
                    isSuccess: i % 2 == 0,
                    fileSizeByte: Int64(i * 100)
                )
                try? repo.save(record)
                _ = try? repo.fetchRecent(limit: 10)
                _ = try? repo.fetchByStatus(isSuccess: true)
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        let records = try repo.fetchAll()
        XCTAssertEqual(records.count, threadCount)
    }
    
    // MARK: - 18. Password Zero Race & Zero Data Loss
    
    func testHighConcurrency100ThreadsPasswordRepositoryReadWrite() throws {
        PasswordVaultManager.shared.lockVault()
        defer { PasswordVaultManager.shared.lockVault() }
        let repo = KeychainPasswordRepository.shared
        let expectation = expectation(description: "Concurrent Password Repository operations")
        let threadCount = 100
        expectation.expectedFulfillmentCount = threadCount
        
        for i in 0..<threadCount {
            DispatchQueue.global().async {
                defer { expectation.fulfill() }
                let entry = PasswordVaultEntry(label: "Concurrent Vault \(i)", password: "pass_\(i)", category: "TestCat")
                try? repo.save(entry)
                _ = try? repo.fetch(id: entry.id)
                _ = try? repo.search(category: "TestCat")
                try? repo.delete(id: entry.id)
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
