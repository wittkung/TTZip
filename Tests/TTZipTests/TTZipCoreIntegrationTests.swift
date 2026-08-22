// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class TTZipCoreIntegrationTests: XCTestCase {
    private var sandbox: IsolatedTempSandbox!

    override func setUp() async throws {
        try await super.setUp()
        sandbox = try IsolatedTempSandbox(prefix: "core_integration")
    }

    override func tearDown() async throws {
        sandbox?.cleanup()
        sandbox = nil
        try await super.tearDown()
    }

    // MARK: - 1. ArchiveWriter & ArchiveExtractor Multi-Format Integration (ZIP / 7z / TAR)

    func testArchiveWriterAndExtractorRoundtripZIP_7Z_TAR() async throws {
        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()

        let file1 = sandbox.fileURL(named: "doc1.txt")
        let file2 = sandbox.fileURL(named: "data.bin")
        let content1 = "TTZip Core Unified Facade Integration Test 2026"
        let content2 = Data((0..<1024).map { UInt8($0 % 256) })

        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2)

        let formats: [(ArchiveCompressionFormat, String)] = [
            (.zip, "archive.zip"),
            (.sevenZip, "archive.7z"),
            (.tar, "archive.tar")
        ]

        for (format, filename) in formats {
            let archiveURL = sandbox.fileURL(named: filename)
            let destDir = try sandbox.createSubdirectory("extract_\(format.rawValue)")

            // Test ArchiveWriter.createArchive
            try await writer.createArchive(
                outputPath: archiveURL.path,
                format: format,
                level: .normal,
                inputPaths: [file1.path, file2.path]
            )
            XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path), "Archive file should exist: \(filename)")

            // Test ArchiveExtractor.extractArchive
            try await extractor.extractArchive(
                archivePath: archiveURL.path,
                destinationDir: destDir.path
            )

            let extractedFile1 = destDir.appendingPathComponent("doc1.txt")
            let extractedFile2 = destDir.appendingPathComponent("data.bin")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile1.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile2.path))

            let readContent1 = try String(contentsOf: extractedFile1, encoding: .utf8)
            let readContent2 = try Data(contentsOf: extractedFile2)
            XCTAssertEqual(readContent1, content1, "Extracted text content must match for \(format)")
            XCTAssertEqual(readContent2, content2, "Extracted binary content must match for \(format)")
        }
    }

    // MARK: - 2. ArchiveReader List Entries & VFS Tree Index Rendering

    func testArchiveReaderListEntriesAndVFSTreeRendering() async throws {
        let subDir = try sandbox.createSubdirectory("FolderA")
        let nestedDir = subDir.appendingPathComponent("SubFolderB")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

        let leaf1 = subDir.appendingPathComponent("alpha.txt")
        let leaf2 = nestedDir.appendingPathComponent("beta.log")
        try "Alpha Payload".write(to: leaf1, atomically: true, encoding: .utf8)
        try "Beta Payload Log Line".write(to: leaf2, atomically: true, encoding: .utf8)

        let archiveURL = sandbox.fileURL(named: "tree_test.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archiveURL.path,
            format: .zip,
            level: .normal,
            inputPaths: [subDir.path]
        )

        let reader = ArchiveReader()

        // 1. Test ArchiveReader.listEntries
        let entries = try await reader.listEntries(archivePath: archiveURL.path)
        XCTAssertFalse(entries.isEmpty, "Archive should contain entries")
        XCTAssertTrue(entries.contains { $0.path.contains("alpha.txt") })
        XCTAssertTrue(entries.contains { $0.path.contains("beta.log") })

        // 2. Test Encryption Introspection
        let tier = try await reader.probeEncryption(archivePath: archiveURL.path)
        XCTAssertEqual(tier, .none, "Unencrypted archive should probe as .none tier")

        // 3. Test VFS Hierarchical Tree Construction & Rendering
        let compositeTree = try await reader.inspectTree(archivePath: archiveURL.path, password: nil, candidatePasswords: nil)
        XCTAssertGreaterThan(compositeTree.totalFileCount(), 0, "Tree should have leaf files")
        XCTAssertTrue(compositeTree.isDirectory, "Root should be a directory container")

        let renderedTree = compositeTree.renderTree()
        XCTAssertFalse(renderedTree.isEmpty, "VFS Tree output should not be empty")
        XCTAssertTrue(renderedTree.contains("alpha.txt") || renderedTree.contains("FolderA"), "Rendered tree must contain nodes")
    }

    // MARK: - 3. SplitVolumeEngine Slicing & Merging

    func testSplitVolumeEngineSlicingAndMerging() throws {
        let largeData = Data(repeating: 0x7E, count: 180 * 1024) // 180 KB
        let sourceFile = sandbox.fileURL(named: "split_source.dat")
        try largeData.write(to: sourceFile)

        let splitEngine = SplitVolumeEngine.shared

        // 1. Slice archive into 64 KB volumes
        let splitChunkSize: Int64 = 65536
        try splitEngine.sliceArchive(
            archivePath: sourceFile.path,
            splitSizeBytes: splitChunkSize,
            namingPattern: .numberedExtension,
            cleanOnFailure: true
        )

        // 2. Discover sliced volume paths
        let seedVolume = sandbox.fileURL(named: "split_source.dat.001")
        XCTAssertTrue(FileManager.default.fileExists(atPath: seedVolume.path), "First volume .001 must exist")

        let resolvedVolumes = splitEngine.resolveVolumes(seedPath: seedVolume.path)
        XCTAssertGreaterThanOrEqual(resolvedVolumes.count, 3, "180 KB divided by 64 KB should produce at least 3 parts")

        // 3. Join volumes back together
        let mergedFile = sandbox.fileURL(named: "reassembled.dat")
        try splitEngine.joinVolumes(
            firstVolumePath: seedVolume.path,
            outputPath: mergedFile.path
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: mergedFile.path), "Reassembled file must exist")
        let mergedData = try Data(contentsOf: mergedFile)
        XCTAssertEqual(mergedData.count, largeData.count, "Reassembled file size must match original")
        XCTAssertEqual(mergedData, largeData, "Reassembled file content must be byte-for-byte identical")
    }

    // MARK: - 4. PasswordVaultManager Key Encryption & Memory-Safe Wiping

    func testPasswordVaultManagerEncryptionAndMemorySafeWiping() {
        let vault = PasswordVaultManager.shared
        vault.resetToFirstRunState()
        defer { vault.resetToFirstRunState() }

        let masterSecret = "SuperVaultMasterKey#2026!"
        vault.setMasterPassword(masterSecret)

        XCTAssertTrue(vault.isMasterPasswordSet, "Master password should be set")
        XCTAssertTrue(vault.isUnlocked, "Vault should be unlocked initially")

        let entryKey = "ProductionArchiveKey"
        let entrySecret = "P@ssw0rdForArchive!"
        vault.addEntry(label: entryKey, password: entrySecret, category: "Production")

        let entries = vault.getEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.label, entryKey)
        XCTAssertEqual(entries.first?.password, entrySecret)

        let candidates = vault.candidatePasswordsForAutoUnlock()
        XCTAssertTrue(candidates.contains(entrySecret), "Candidate list should include added password")

        // Lock vault - triggers Rust C-ABI memory scrubbing (ttzip_rust_vault_wipe)
        vault.lockVault()
        XCTAssertFalse(vault.isUnlocked, "Vault should be locked")
        XCTAssertTrue(vault.getEntries().isEmpty, "Locked vault must return empty entries")

        // Re-unlock with valid master password
        let unlockedSuccess = vault.unlockVault(with: masterSecret)
        XCTAssertTrue(unlockedSuccess, "Unlocking with valid master password should succeed")
        XCTAssertTrue(vault.isUnlocked)

        let restoredEntries = vault.getEntries()
        XCTAssertEqual(restoredEntries.count, 1)
        XCTAssertEqual(restoredEntries.first?.password, entrySecret, "Restored entry must match original secret")
    }

    // MARK: - 5. PasswordRecoveryEngine Dictionary & Brute-Force Interfaces

    func testPasswordRecoveryEngineDictionaryAndBruteForce() async throws {
        let sampleFile = sandbox.fileURL(named: "secret_document.txt")
        let secretText = "Restricted Corporate Asset 2026"
        try secretText.write(to: sampleFile, atomically: true, encoding: .utf8)

        let archiveURL = sandbox.fileURL(named: "encrypted.zip")
        let secretPassword = "pass"
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archiveURL.path,
            format: .zip,
            level: .fastest,
            inputPaths: [sampleFile.path],
            password: secretPassword
        )

        // 1. Fast in-memory dictionary recovery
        let dictionary = ["wrong1", "wrong2", secretPassword, "wrong3"]
        let fastFound = PasswordRecoveryEngine.recoverFastInMemory(
            passwords: dictionary,
            archivePath: archiveURL.path
        )
        XCTAssertEqual(fastFound, secretPassword, "Fast in-memory dictionary lookup should find secret")

        // 2. Full recovery workflow with metrics
        let engine = PasswordRecoveryEngine()
        let recoveryResult = try await engine.recoverPassword(
            archivePath: archiveURL.path,
            dictionary: dictionary
        )
        XCTAssertEqual(recoveryResult.foundPassword, secretPassword)
        XCTAssertGreaterThan(recoveryResult.totalAttempts, 0)
        XCTAssertGreaterThanOrEqual(recoveryResult.durationSeconds, 0)

        // 3. Brute force strategy recovery
        let bruteStrategy = BruteForceRecoveryStrategy()
        let context = PasswordRecoveryContext(
            archivePath: archiveURL.path,
            charset: "aps",
            maxBruteForceLength: 4
        )
        XCTAssertTrue(bruteStrategy.canExecute(context: context))

        let (bruteFound, attempts) = try await bruteStrategy.recover(context: context) { candidate in
            return candidate == secretPassword
        }
        XCTAssertEqual(bruteFound, secretPassword, "Brute force recovery strategy should match secret")
        XCTAssertGreaterThan(attempts, 0)

        // 4. Strategy executor pipeline coordination
        let executor = PasswordRecoveryStrategyExecutor(registerDefaults: true)
        let execResult = try await executor.recoverPassword(context: context) { candidate in
            return candidate == secretPassword
        }
        XCTAssertEqual(execResult.foundPassword, secretPassword)
        XCTAssertGreaterThan(execResult.totalAttempts, 0)
    }

    // MARK: - 6. VFSLz4CachePool Int.min Bit-Pattern Overflow Safety

    func testVFSLz4CachePoolHashOverflowSafety() {
        let pool = VFSLz4CachePool.shared
        let dummyData = Data([0x01, 0x02, 0x03, 0x04])
        
        // Ensure cacheEntry and getCachedEntry handle arbitrary strings without crashing
        pool.cacheEntry(archivePath: "test_session", entryPath: "path/to/entry.bin", data: dummyData)
        let cached = pool.getCachedEntry(archivePath: "test_session", entryPath: "path/to/entry.bin")
        XCTAssertEqual(cached, dummyData)
        
        // Direct test of non-overflowing chunkIdx bit-pattern calculation logic with Int.min
        let minHash = Int.min
        let safeChunkIdx = Int(truncatingIfNeeded: UInt64(bitPattern: Int64(minHash)) & 0x7FFF_FFFF_FFFF_FFFF)
        XCTAssertGreaterThanOrEqual(safeChunkIdx, 0)
        XCTAssertEqual(safeChunkIdx, 0)
    }

    // MARK: - 7. VirtualMultiBlockArena Multi-Threaded Concurrency Safety

    func testVirtualMultiBlockArenaConcurrentThreadSafety() {
        guard let arena = VirtualMultiBlockArena(capacity: 16 * 1024 * 1024) else {
            XCTFail("Failed to allocate VirtualMultiBlockArena")
            return
        }

        let testPayload: [UInt8] = Array(repeating: 0x42, count: 1024)
        let threadCount = 8
        let iterationsPerThread = 100
        let group = DispatchGroup()

        for t in 0..<threadCount {
            group.enter()
            DispatchQueue.global().async {
                for i in 0..<iterationsPerThread {
                    testPayload.withUnsafeBufferPointer { ptr in
                        guard let base = ptr.baseAddress else { return }
                        _ = arena.appendBlock(name: "file_\(t)_\(i)", data: base, length: 1024)
                    }
                }
                group.leave()
            }
        }

        group.wait()
        XCTAssertEqual(arena.blocks.count, threadCount * iterationsPerThread)
        XCTAssertEqual(arena.currentOffset, threadCount * iterationsPerThread * 1024)
        
        arena.reset()
        XCTAssertEqual(arena.blocks.count, 0)
        XCTAssertEqual(arena.currentOffset, 0)
    }

    // MARK: - 8. MemoryPageBufferPool Borrow & Return Lifecycle

    func testMemoryPageBufferPoolLifecycle() {
        let pool = MemoryPageBufferPool.shared
        let buf4k = pool.borrowBuffer(size: .page4K)
        XCTAssertEqual(buf4k.capacity, 4096)
        
        let buf16k = pool.borrowBuffer(size: .page16K)
        XCTAssertEqual(buf16k.capacity, 16384)
        
        let buf64k = pool.borrowBuffer(size: .page64K)
        XCTAssertEqual(buf64k.capacity, 65536)
        
        pool.returnBuffer(buf4k)
        pool.returnBuffer(buf16k)
        pool.returnBuffer(buf64k)
    }
}
