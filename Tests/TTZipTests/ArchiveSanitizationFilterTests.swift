// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveSanitizationFilterTests: XCTestCase {
    
    func testMacMetadataExclusionRule() {
        let macJunkFiles = [
            ".DS_Store",
            "folder/.DS_Store",
            "__MACOSX/file.txt",
            "._file.txt",
            "folder/._subfile.png",
            ".Spotlight-V100",
            ".Trashes/501/trash.txt",
            "Thumbs.db",
            "Desktop.ini"
        ]
        
        for file in macJunkFiles {
            let excluded = PathPatternFilterEngine.shouldExclude(
                path: file,
                excludePatterns: [],
                includePatterns: [],
                excludeVCS: false,
                noMacMetadata: true
            )
            XCTAssertTrue(excluded, "Path '\(file)' must be excluded when noMacMetadata is true")
        }
    }
    
    func testVCSMetadataExclusionRule() {
        let vcsFiles = [
            ".git/config",
            ".git/HEAD",
            "submodule/.git",
            ".gitignore",
            ".svn/entries",
            ".hg/dirstate"
        ]
        
        for file in vcsFiles {
            let excluded = PathPatternFilterEngine.shouldExclude(
                path: file,
                excludePatterns: [],
                includePatterns: [],
                excludeVCS: true,
                noMacMetadata: false
            )
            XCTAssertTrue(excluded, "Path '\(file)' must be excluded when excludeVCS is true")
        }
    }
    
    func testCleanCompressionExcludesMacJunkInZip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TTZipCleanTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let validFile = tempDir.appendingPathComponent("document.pdf")
        let dsStore = tempDir.appendingPathComponent(".DS_Store")
        let appleDouble = tempDir.appendingPathComponent("._document.pdf")
        
        try "Real Document Data".write(to: validFile, atomically: true, encoding: .utf8)
        try "DS_Store binary junk".write(to: dsStore, atomically: true, encoding: .utf8)
        try "AppleDouble resource fork".write(to: appleDouble, atomically: true, encoding: .utf8)
        
        let scanned = ZipDirectoryScanner.scan(
            inputPaths: [validFile.path, dsStore.path, appleDouble.path],
            skipMacJunk: true
        )
        
        XCTAssertEqual(scanned.count, 1)
        XCTAssertEqual(scanned.first?.relPath, "document.pdf")
    }
    
    func testPreserveAllModeIncludesMetadata() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TTZipPreserveTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let validFile = tempDir.appendingPathComponent("document.pdf")
        let dsStore = tempDir.appendingPathComponent(".DS_Store")
        
        try "Real Document Data".write(to: validFile, atomically: true, encoding: .utf8)
        try "DS_Store binary junk".write(to: dsStore, atomically: true, encoding: .utf8)
        
        let scanned = ZipDirectoryScanner.scan(
            inputPaths: [validFile.path, dsStore.path],
            filterOptions: .preserveAll
        )
        
        XCTAssertEqual(scanned.count, 2)
    }
}
