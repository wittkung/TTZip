// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class Phase3IntegrationTests: XCTestCase {
    var tempDir: URL!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("phase3_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testQuickLookPreviewEngineAndSelectiveExtraction() async throws {
        let out7z = tempDir.appendingPathComponent("archive_7z_test.7z").path
        let file1 = tempDir.appendingPathComponent("quicklook_sample.txt")
        let file2 = tempDir.appendingPathComponent("notes.md")
        
        let content1 = "QuickLook Preview In-Memory Content 2026"
        let content2 = "# Markdown Header\nSelective Extraction Sample."
        
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out7z,
            format: .sevenZip,
            level: .normal,
            inputPaths: [file1.path, file2.path]
        )
        
        // 1. Test ArchiveReader inspection
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out7z)
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        
        // 2. Test QuickLookPreviewEngine extractSingleFileMemoryStream
        let qlData = try await QuickLookPreviewEngine.extractSingleFileMemoryStream(archivePath: out7z, entryPath: "notes.md")
        XCTAssertNotNil(qlData)
        if let data = qlData, let str = String(data: data, encoding: .utf8) {
            XCTAssertEqual(str, content2)
        }
        
        // 3. Test ArchiveSelectiveExtractor to destination directory
        let targetExtractDir = tempDir.appendingPathComponent("extracted_out").path
        let extractedCount = try await ArchiveSelectiveExtractor.shared.extractSelected(
            archivePath: out7z,
            targetEntryPaths: ["quicklook_sample.txt"],
            destinationDir: targetExtractDir
        )
        XCTAssertEqual(extractedCount, 1)
        let extractedFile = URL(fileURLWithPath: targetExtractDir).appendingPathComponent("quicklook_sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
    }
}
