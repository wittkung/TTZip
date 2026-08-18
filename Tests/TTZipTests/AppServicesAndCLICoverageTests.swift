// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class AppServicesAndCLICoverageTests: XCTestCase {
    
    var tempDirURL: URL!
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("AppServicesTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        tempDirPath = tempDirURL.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // 1. Test DeepFileMetadataReader POSIX permissions and APFS Inode inspection
    func testDeepFileMetadataReader() async throws {
        let sampleFile = tempDirURL.appendingPathComponent("metadata_sample.txt")
        try "Metadata Reader Test Data 2026".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let metadata = await DeepFileMetadataReader.readMetadata(for: sampleFile)
        XCTAssertFalse(metadata.isEmpty)
        XCTAssertNotNil(metadata["POSIX Permissions"])
        XCTAssertNotNil(metadata["Owner : Group"])
        XCTAssertNotNil(metadata["APFS Inode"])
    }
    
    // 2. Test FolderStatsCalculator directory sizing and distribution
    func testFolderStatsCalculator() async throws {
        let subDir = tempDirURL.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let docFile = subDir.appendingPathComponent("doc.txt")
        try "Text Document Content".write(to: docFile, atomically: true, encoding: .utf8)
        
        let mediaFile = subDir.appendingPathComponent("video.mp4")
        try Data([0x00, 0x00, 0x00, 0x18]).write(to: mediaFile)
        
        let stats = await FolderStatsCalculator.calculateStats(for: tempDirPath)
        XCTAssertGreaterThan(stats.size, 0)
        XCTAssertEqual(stats.subfolders, 1)
        XCTAssertEqual(stats.files, 2)
        XCTAssertFalse(stats.dist.isEmpty)
    }
    
    // 3. Test FileClipboardStore copy / cut / paste operations
    @MainActor
    func testFileClipboardStore() throws {
        let store = FileClipboardStore.shared
        let file1 = tempDirURL.appendingPathComponent("clip_1.txt")
        try "Clip 1".write(to: file1, atomically: true, encoding: .utf8)
        
        store.copy(urls: [file1])
        XCTAssertTrue(store.canPaste)
        XCTAssertFalse(store.isCutOperation)
        
        let pasteTargetDir = tempDirURL.appendingPathComponent("pasted_target")
        try FileManager.default.createDirectory(at: pasteTargetDir, withIntermediateDirectories: true)
        
        store.paste(to: pasteTargetDir)
        let pastedFile = pasteTargetDir.appendingPathComponent("clip_1.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pastedFile.path))
    }
    
    // 4. Test DateFormatterCache and ByteCountFormatterCache thread-safe formatting
    func testFormattersCache() {
        let sizeString = ByteCountFormatterCache.string(fromByteCount: 1024 * 1024 * 50)
        XCTAssertFalse(sizeString.isEmpty)
        
        let dateString = DateFormatterCache.shared.string(fromShortDateTime: Date())
        XCTAssertFalse(dateString.isEmpty)
    }
}
