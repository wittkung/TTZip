// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class InPlaceArchiveEditSyncTests: XCTestCase {
    
    private var tempWorkDir: URL!
    
    override func setUp() {
        super.setUp()
        tempWorkDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TTZipInPlaceTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempWorkDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let dir = tempWorkDir {
            try? FileManager.default.removeItem(at: dir)
        }
        FileWatcherEngine.shared.stopAllWatching()
        super.tearDown()
    }
    
    func testInPlaceEditSessionInitializationAndDefaults() {
        let session = InPlaceEditSession(
            archivePath: "/path/to/archive.zip",
            entryPath: "documents/readme.txt",
            stagedFilePath: "/tmp/ttzip_edit_123/readme.txt",
            stagedDirectoryPath: "/tmp/ttzip_edit_123",
            initialHash: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        
        XCTAssertFalse(session.sessionId.isEmpty)
        XCTAssertEqual(session.id, session.sessionId)
        XCTAssertEqual(session.archivePath, "/path/to/archive.zip")
        XCTAssertEqual(session.entryPath, "documents/readme.txt")
        XCTAssertEqual(session.stagedFilePath, "/tmp/ttzip_edit_123/readme.txt")
        XCTAssertEqual(session.stagedDirectoryPath, "/tmp/ttzip_edit_123")
        XCTAssertEqual(session.state, .staged)
        XCTAssertEqual(session.initialHash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertGreaterThan(session.lastKnownMtime, 0)
        XCTAssertFalse(session.hasUnsavedChanges)
        XCTAssertNil(session.errorMessage)
    }
    
    func testInPlaceEditSessionStates() {
        let states: [InPlaceEditSessionState] = [.staged, .listening, .syncing, .saved, .closed, .error]
        let rawValues = states.map(\.rawValue)
        XCTAssertEqual(rawValues, ["staged", "listening", "syncing", "saved", "closed", "error"])
    }
    
    func testInPlaceEditSessionCodableJSONSchemaConformance() throws {
        let session = InPlaceEditSession(
            sessionId: "550e8400-e29b-41d4-a716-446655440000",
            archivePath: "/Users/test/archive.zip",
            entryPath: "data/config.json",
            stagedFilePath: "/tmp/stage/config.json",
            stagedDirectoryPath: "/tmp/stage",
            state: .listening,
            initialHash: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            lastKnownMtime: 1723968000.0,
            hasUnsavedChanges: true,
            errorMessage: "Sample warning"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(session)
        
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to deserialize JSON object")
            return
        }
        
        XCTAssertEqual(jsonObject["sessionId"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(jsonObject["archivePath"] as? String, "/Users/test/archive.zip")
        XCTAssertEqual(jsonObject["entryPath"] as? String, "data/config.json")
        XCTAssertEqual(jsonObject["stagedFilePath"] as? String, "/tmp/stage/config.json")
        XCTAssertEqual(jsonObject["stagedDirectoryPath"] as? String, "/tmp/stage")
        XCTAssertEqual(jsonObject["state"] as? String, "listening")
        XCTAssertEqual(jsonObject["initialHash"] as? String, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(jsonObject["lastKnownMtime"] as? Double, 1723968000.0)
        XCTAssertEqual(jsonObject["hasUnsavedChanges"] as? Bool, true)
        XCTAssertEqual(jsonObject["errorMessage"] as? String, "Sample warning")
        
        let decoder = JSONDecoder()
        let decodedSession = try decoder.decode(InPlaceEditSession.self, from: data)
        XCTAssertEqual(decodedSession, session)
    }
    
    func testInPlaceArchiveMutationEngineEndToEnd() async throws {
        // 1. Create a source test folder with two files
        let srcDir = tempWorkDir.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        
        let fileA = srcDir.appendingPathComponent("fileA.txt")
        let fileB = srcDir.appendingPathComponent("fileB.txt")
        try "Original File A Content".write(to: fileA, atomically: true, encoding: .utf8)
        try "Original File B Content".write(to: fileB, atomically: true, encoding: .utf8)
        
        // 2. Compress into a ZIP archive
        let archiveURL = tempWorkDir.appendingPathComponent("test_bundle.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archiveURL.path,
            format: .zip,
            inputPaths: [fileA.path, fileB.path]
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        
        // 3. Begin In-Place Editing Session for fileA.txt
        let mutationEngine = InPlaceEditEngine.shared
        let session = try await mutationEngine.beginEditingSession(
            archivePath: archiveURL.path,
            entryPath: "fileA.txt"
        )
        
        XCTAssertEqual(session.entryPath, "fileA.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: session.stagedFilePath))
        
        // 4. Simulate external editor writing updated content
        let updatedText = "UPDATED CONTENT FROM VS CODE"
        try updatedText.write(toFile: session.stagedFilePath, atomically: true, encoding: .utf8)
        
        // 5. Synchronize back
        try await mutationEngine.synchronizeEntryBackToArchive(
            archivePath: session.archivePath,
            entryPath: session.entryPath,
            stagedFilePath: session.stagedFilePath
        )
        
        // 6. Verify by reading back from archive
        let extractDest = tempWorkDir.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDest, withIntermediateDirectories: true)
        
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: archiveURL.path, destinationDir: extractDest.path)
        
        let extractedFileA = extractDest.appendingPathComponent("fileA.txt")
        let readBackA = try String(contentsOf: extractedFileA, encoding: .utf8)
        XCTAssertEqual(readBackA, updatedText)
        
        let extractedFileB = extractDest.appendingPathComponent("fileB.txt")
        let readBackB = try String(contentsOf: extractedFileB, encoding: .utf8)
        XCTAssertEqual(readBackB, "Original File B Content")
        
        // 7. Clean up session
        mutationEngine.closeEditingSession(session: session)
    }
    
    func testInPlaceAddAndMultipleDeleteOperations() async throws {
        // 1. Create initial files and ZIP
        let srcDir = tempWorkDir.appendingPathComponent("src_add_del", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        
        let file1 = srcDir.appendingPathComponent("keep1.txt")
        let file2 = srcDir.appendingPathComponent("delete_me.txt")
        try "Keep 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Delete Me".write(to: file2, atomically: true, encoding: .utf8)
        
        let archiveURL = tempWorkDir.appendingPathComponent("add_del_test.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: archiveURL.path, format: .zip, inputPaths: [file1.path, file2.path])
        
        // 2. Add a new file in-place
        let newFile = tempWorkDir.appendingPathComponent("appended_doc.txt")
        try "Appended Payload".write(to: newFile, atomically: true, encoding: .utf8)
        
        let engine = InPlaceEditEngine.shared
        try await engine.addFilesToArchive(
            archivePath: archiveURL.path,
            sourceFilePaths: [newFile.path],
            destinationVirtualFolder: "docs"
        )
        
        // 3. Delete file2 from archive
        try await engine.deleteEntriesFromArchive(
            archivePath: archiveURL.path,
            entryPathsToDelete: ["delete_me.txt"]
        )
        
        // 4. Verify contents
        let extractDest = tempWorkDir.appendingPathComponent("extracted_add_del", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDest, withIntermediateDirectories: true)
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: archiveURL.path, destinationDir: extractDest.path)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDest.appendingPathComponent("keep1.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: extractDest.appendingPathComponent("delete_me.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDest.appendingPathComponent("docs/appended_doc.txt").path))
    }
    
    func testInPlace7zAppendReplaceAndVerify() async throws {
        let srcDir = tempWorkDir.appendingPathComponent("src_7z", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        
        let fileA = srcDir.appendingPathComponent("alpha.txt")
        let fileB = srcDir.appendingPathComponent("beta.txt")
        try "Alpha Original".write(to: fileA, atomically: true, encoding: .utf8)
        try "Beta Original".write(to: fileB, atomically: true, encoding: .utf8)
        
        let archiveURL = tempWorkDir.appendingPathComponent("test_7z.7z")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: archiveURL.path, format: .sevenZip, inputPaths: [fileA.path, fileB.path])
        
        let engine = InPlaceEditEngine.shared
        
        // Replace alpha.txt
        let repFile = tempWorkDir.appendingPathComponent("alpha_new.txt")
        try "Alpha Replaced Content".write(to: repFile, atomically: true, encoding: .utf8)
        
        try await engine.synchronizeEntryBackToArchive(
            archivePath: archiveURL.path,
            entryPath: "alpha.txt",
            stagedFilePath: repFile.path
        )
        
        // Extract and verify
        let extractDest = tempWorkDir.appendingPathComponent("extracted_7z", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDest, withIntermediateDirectories: true)
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: archiveURL.path, destinationDir: extractDest.path)
        let readBack = try String(contentsOf: extractDest.appendingPathComponent("alpha.txt"), encoding: .utf8)
        XCTAssertEqual(readBack, "Alpha Replaced Content")
    }
    
    func testInPlaceTransactionalRollbackOnUnsavedClose() async throws {
        let srcDir = tempWorkDir.appendingPathComponent("src_rollback", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        
        let fileA = srcDir.appendingPathComponent("sample.txt")
        try "Initial Rollback Content".write(to: fileA, atomically: true, encoding: .utf8)
        
        let archiveURL = tempWorkDir.appendingPathComponent("rollback_bundle.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: archiveURL.path, format: .zip, inputPaths: [fileA.path])
        
        let engine = InPlaceEditEngine.shared
        let session = try await engine.beginEditingSession(archivePath: archiveURL.path, entryPath: "sample.txt")
        
        // Modify staged file
        try "Corrupted Unsaved".write(toFile: session.stagedFilePath, atomically: true, encoding: .utf8)
        
        // Discard without sync
        engine.closeEditingSession(session: session, discardUnsaved: true)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.stagedDirectoryPath))
        
        // Verify original archive intact
        let extractDest = tempWorkDir.appendingPathComponent("extracted_rollback", isDirectory: true)
        let extractor = ArchiveExtractor()
        _ = try await extractor.extract(archivePath: archiveURL.path, destinationDir: extractDest.path)
        let readBack = try String(contentsOf: extractDest.appendingPathComponent("sample.txt"), encoding: .utf8)
        XCTAssertEqual(readBack, "Initial Rollback Content")
    }
}

