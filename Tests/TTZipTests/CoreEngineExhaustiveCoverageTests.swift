// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CoreEngineExhaustiveCoverageTests: XCTestCase {

    var tempDirURL: URL!
    var tempDirPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("CoreExhaustiveTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        tempDirPath = tempDirURL.path
    }

    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }

    // 1. ArchiveEngineFactory Repository
    func testArchiveEngineFactoryAndRepositories() {
        let writer: ArchiveWriting = ArchiveEngineFactory.makeWriter(for: .sevenZip)
        XCTAssertNotNil(writer)

        let extractor: ArchiveExtracting = ArchiveEngineFactory.makeExtractor(for: .zip)
        XCTAssertNotNil(extractor)

        let reader: ArchiveReading = ArchiveEngineFactory.makeReader(for: .tar)
        XCTAssertNotNil(reader)

        // Verify expected invariant
        let zipStrategy = ArchiveEngineFactory.makeStrategy(for: .zip)
        XCTAssertEqual(zipStrategy.format, .zip)
        XCTAssertTrue(zipStrategy.canHandle(path: "sample.zip"))

        let sevenZipStrategy = ArchiveEngineFactory.makeStrategy(for: .sevenZip)
        XCTAssertEqual(sevenZipStrategy.format, .sevenZip)
        XCTAssertTrue(sevenZipStrategy.canHandle(path: "archive.7z"))

        let tarStrategy = ArchiveEngineFactory.makeStrategy(for: .tarGz)
        XCTAssertEqual(tarStrategy.format, .tarGz)
        XCTAssertTrue(tarStrategy.canHandle(path: "bundle.tar.gz"))

        let zstdStrategy = ArchiveEngineFactory.makeStrategy(for: .zst)
        XCTAssertEqual(zstdStrategy.format, .zst)
        XCTAssertTrue(zstdStrategy.canHandle(path: "data.zst"))

        // Verify expected invariant
        let autoZipStrategy = ArchiveEngineFactory.makeStrategy(for: "document.zip")
        XCTAssertNotNil(autoZipStrategy)
        XCTAssertTrue(autoZipStrategy?.canHandle(path: "document.zip") ?? false)

        let auto7zStrategy = ArchiveEngineFactory.makeStrategy(for: "backup.7z")
        XCTAssertNotNil(auto7zStrategy)
        XCTAssertTrue(auto7zStrategy?.canHandle(path: "backup.7z") ?? false)

        // Verify expected invariant
        let integrityChecker: ArchiveIntegrityChecking = ArchiveEngineFactory.makeIntegrityChecker()
        XCTAssertNotNil(integrityChecker)

        let hashCalculator: HashCalculating = ArchiveEngineFactory.makeHashCalculator()
        XCTAssertNotNil(hashCalculator)

        let vaultRepo: any PasswordVaultRepositoryProtocol = PasswordVaultManager.shared
        XCTAssertNotNil(vaultRepo)

        let presetRepo: any ArchivePresetRepositoryProtocol = PresetManager.shared
        XCTAssertFalse((try? presetRepo.fetchAll())?.isEmpty ?? true)
    }

    // 2. FileWatcherEngine
    func testFileWatcherEngine() throws {
        let watchFile = (tempDirPath as NSString).appendingPathComponent("watch_me.txt")
        try "Original Watch Content".write(toFile: watchFile, atomically: true, encoding: .utf8)

        let watcher = FileWatcherEngine.shared
        let expectation = expectation(description: "FileWatcher detects file modification")

        watcher.watchFileForChanges(filePath: watchFile, targetArchivePath: "test.zip") { path, targetArchive in
            XCTAssertEqual(path, watchFile)
            XCTAssertEqual(targetArchive, "test.zip")
            expectation.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            let handle = FileHandle(forWritingAtPath: watchFile)
            handle?.seekToEndOfFile()
            handle?.write(" - Modified Content 2026".data(using: .utf8)!)
            handle?.closeFile()
        }

        wait(for: [expectation], timeout: 2.0)
        watcher.stopWatching(filePath: watchFile)
    }

    // 3. FinderSyncHelper
    func testFinderSyncHelperMenuItems() {
        let helper = FinderSyncHelper.shared

        let zipURL = URL(fileURLWithPath: "/tmp/sample.zip")
        let archiveItems = helper.getContextMenuItems(selectedURLs: [zipURL])
        XCTAssertEqual(archiveItems.count, 5)
        XCTAssertTrue(archiveItems.contains(where: { $0.actionIdentifier == "extract_here" }))
        XCTAssertTrue(archiveItems.contains(where: { $0.actionIdentifier == "autofill_password" }))

        let fileURL = URL(fileURLWithPath: "/tmp/document.pdf")
        let normalItems = helper.getContextMenuItems(selectedURLs: [fileURL])
        XCTAssertEqual(normalItems.count, 5)
        XCTAssertTrue(normalItems.contains(where: { $0.actionIdentifier == "compress_quick_7z" }))
        XCTAssertTrue(normalItems.contains(where: { $0.actionIdentifier == "compress_modal_advanced" }))
    }

    // 4. LicenseManager
    func testLicenseManagerActivationAndGatekeeping() {
        LicenseManager.simulateFreeTierInTests = true
        defer { LicenseManager.simulateFreeTierInTests = false }
        let license = LicenseManager.shared
        license.deactivate()
        XCTAssertFalse(license.isPro)
        XCTAssertEqual(license.currentType, .free)

        XCTAssertTrue(license.canUseFeature(.basicExtract))
        XCTAssertTrue(license.canUseFeature(.zipCompression))
        XCTAssertFalse(license.canUseFeature(.aes256Encryption))
        XCTAssertFalse(license.canUseFeature(.ultraCompression))
        XCTAssertFalse(license.canUseFeature(.volumeSplit))

        XCTAssertFalse(license.activate(key: "INVALID-KEY-1234"))

        LicenseManager.simulateFreeTierInTests = false
        let validBizKey = "AURA-BIZ1-2026-KEY1"
        XCTAssertTrue(license.activate(key: validBizKey, registeredTo: "Enterprise User"))
        XCTAssertTrue(license.isPro)
        XCTAssertEqual(license.currentType, .proBusiness)
        XCTAssertTrue(license.canUseFeature(.aes256Encryption))
        XCTAssertTrue(license.canUseFeature(.volumeSplit))

        LicenseManager.simulateFreeTierInTests = true
        license.deactivate()
        XCTAssertFalse(license.isPro)
    }

    // 5. SecurityScanner
    func testSecurityScanner() {
        let safeEntry = ArchiveEntry(path: "documents/readme.txt", uncompressedSize: 100, isDirectory: false)
        let traversalEntry = ArchiveEntry(path: "../../../etc/passwd", uncompressedSize: 500, isDirectory: false)
        let exeEntry = ArchiveEntry(path: "payload.exe", uncompressedSize: 1024, isDirectory: false)

        let scanner = SecurityScanner.shared
        let result = scanner.scanArchiveEntries([safeEntry, traversalEntry, exeEntry])

        XCTAssertFalse(result.isSafe, "存在危险条目时应判定 isSafe 为 false")
        XCTAssertEqual(result.suspiciousFileNames.count, 2)
        XCTAssertTrue(result.suspiciousFileNames.contains("../../../etc/passwd"))
        XCTAssertTrue(result.suspiciousFileNames.contains("payload.exe"))
    }

    // 6. ArchiveRepairEngine
    func testArchiveRepairEngineFlow() async throws {
        let dummyFile = (tempDirPath as NSString).appendingPathComponent("repair_test.txt")
        try "Repair test string data".write(toFile: dummyFile, atomically: true, encoding: .utf8)

        let validArchivePath = (tempDirPath as NSString).appendingPathComponent("valid.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: validArchivePath, format: .zip, inputPaths: [dummyFile])

        let repairedOutputPath = (tempDirPath as NSString).appendingPathComponent("repaired_out.zip")
        let repairEngine = ArchiveRepairEngine()
        let recoveredCount = try await repairEngine.repairArchive(damagedArchivePath: validArchivePath, repairedOutputPath: repairedOutputPath)

        XCTAssertGreaterThanOrEqual(recoveredCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedOutputPath))
    }

    // 7. PresetManager
    func testPresetManagerCRUD() {
        let manager = PresetManager.shared
        let initialCount = manager.presets.count

        let customPreset = CompressionPreset(
            name: "极致代码打包预设",
            format: .sevenZip,
            level: .ultra,
            splitVolumeSizeBytes: 50 * 1024 * 1024,
            defaultPassword: "preset_pwd"
        )

        manager.savePreset(customPreset)
        XCTAssertEqual(manager.presets.count, initialCount + 1)
        XCTAssertTrue(manager.presets.contains(where: { $0.id == customPreset.id }))

        manager.deletePreset(id: customPreset.id)
        XCTAssertEqual(manager.presets.count, initialCount)

        manager.resetToDefaults()
        XCTAssertFalse(manager.presets.isEmpty)
    }
}
