// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class QuickLookPreviewTests: XCTestCase {
    
    func testQuickLookPreviewDataExtraction() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sampleFile1 = tempDir.appendingPathComponent("document.txt")
        let sampleFile2 = tempDir.appendingPathComponent("image.png")
        try "Document Text Content".write(to: sampleFile1, atomically: true, encoding: .utf8)
        try "Fake PNG Image Bytes Data Content".write(to: sampleFile2, atomically: true, encoding: .utf8)
        
        let outArchive = tempDir.appendingPathComponent("preview_test.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outArchive,
            format: .zip,
            level: .fast,
            inputPaths: [sampleFile1.path, sampleFile2.path]
        )
        
        let previewData = try await QuickLookPreviewEngine.inspectForPreview(archivePath: outArchive)
        XCTAssertEqual(previewData.archiveName, "preview_test.zip")
        XCTAssertEqual(previewData.format, .zip)
        XCTAssertEqual(previewData.totalEntriesCount, 2)
        XCTAssertGreaterThan(previewData.uncompressedSizeBytes, 0)
        XCTAssertFalse(previewData.isEncrypted)
        XCTAssertEqual(previewData.rootNodes.count, 2)
    }
    
    func testQuickLookHTMLGeneration() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sampleFile = tempDir.appendingPathComponent("readme.md")
        try "# TTZip QuickLook\nHigh performance".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let outArchive = tempDir.appendingPathComponent("html_test.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outArchive,
            format: .zip,
            level: .fast,
            inputPaths: [sampleFile.path]
        )
        
        let html = try await QuickLookPreviewEngine.generateHTMLPreview(for: outArchive)
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("html_test.zip"))
        XCTAssertTrue(html.contains("readme.md"))
        XCTAssertTrue(html.contains("TTZip ⚡️"))
    }
    
    func testFinderSyncContextMenuForArchivesAndFiles() {
        let archiveURL = URL(fileURLWithPath: "/tmp/sample.7z")
        let itemsForArchive = FinderSyncHelper.shared.getContextMenuItems(selectedURLs: [archiveURL])
        XCTAssertFalse(itemsForArchive.isEmpty)
        XCTAssertTrue(itemsForArchive.contains { $0.actionIdentifier == "extract_here" })
        XCTAssertTrue(itemsForArchive.contains { $0.actionIdentifier == "inspect_archive" })
        
        let plainFolderURL = URL(fileURLWithPath: "/Users/dev/Documents")
        let itemsForFolder = FinderSyncHelper.shared.getContextMenuItems(selectedURLs: [plainFolderURL])
        XCTAssertFalse(itemsForFolder.isEmpty)
        XCTAssertTrue(itemsForFolder.contains { $0.actionIdentifier == "compress_quick_7z" })
        XCTAssertTrue(itemsForFolder.contains { $0.actionIdentifier == "compress_quick_zip" })
    }
    
    func testFinderSyncAll16SupportedExtensions() {
        let allExtensions = [
            "zip", "7z", "tar", "gz", "bz2", "xz", "zst", "lz4",
            "lz", "lrz", "aar", "sz", "wim", "dmg", "iso", "rar"
        ]
        for ext in allExtensions {
            XCTAssertTrue(
                FinderSyncHelper.supportedArchiveExtensions.contains(ext),
                "FinderSyncHelper 必须识别 .\(ext) 为归档格式"
            )
        }
    }
}
