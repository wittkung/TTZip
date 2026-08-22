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
    
    func testCleanCompressionExcludesMacJunkInZip() {
        let validFile = "document.pdf"
        let dsStore = ".DS_Store"
        let appleDouble = "._document.pdf"
        
        XCTAssertFalse(PathPatternFilterEngine.shouldExclude(path: validFile, noMacMetadata: true))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: dsStore, noMacMetadata: true))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: appleDouble, noMacMetadata: true))
    }
    
    func testPreserveAllModeIncludesMetadata() {
        let validFile = "document.pdf"
        let dsStore = ".DS_Store"
        
        XCTAssertFalse(PathPatternFilterEngine.shouldExclude(path: validFile, noMacMetadata: false))
        XCTAssertFalse(PathPatternFilterEngine.shouldExclude(path: dsStore, noMacMetadata: false))
    }
}
