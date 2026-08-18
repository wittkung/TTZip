// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SmartExtractionTests: XCTestCase {
    
    func testSingleRootDirectoryResolvesToDirectExtract() {
        let entries = [
            "MyProject/README.md",
            "MyProject/src/main.c",
            "MyProject/src/utils.c",
            "MyProject/include/utils.h"
        ]
        let destParent = URL(fileURLWithPath: "/tmp/test_extract_parent")
        let result = SmartExtractResolver.resolve(
            entryPaths: entries,
            destinationParentURL: destParent,
            archiveStemName: "MyProjectArchive"
        )
        
        XCTAssertEqual(result.resolutionMode, .directExtract)
        XCTAssertEqual(result.effectiveRootCount, 1)
        XCTAssertEqual(result.singleRootName, "MyProject")
        XCTAssertEqual(result.finalExtractionURL, destParent)
    }
    
    func testSingleRootWithAppleMetadataJunkResolvesToDirectExtract() {
        let entries = [
            "__MACOSX/MyProject/._README.md",
            ".DS_Store",
            "MyProject/README.md",
            "MyProject/src/main.c",
            "__MACOSX/._.DS_Store",
            "Thumbs.db"
        ]
        let destParent = URL(fileURLWithPath: "/tmp/test_extract_parent")
        let result = SmartExtractResolver.resolve(
            entryPaths: entries,
            destinationParentURL: destParent,
            archiveStemName: "MyProjectArchive"
        )
        
        XCTAssertEqual(result.resolutionMode, .directExtract)
        XCTAssertEqual(result.effectiveRootCount, 1)
        XCTAssertEqual(result.singleRootName, "MyProject")
        XCTAssertEqual(result.finalExtractionURL, destParent)
    }
    
    func testMultipleLooseRootsResolvesToWrapInFolder() {
        let entries = [
            "file1.txt",
            "file2.txt",
            "images/banner.png",
            "docs/manual.pdf"
        ]
        let destParent = URL(fileURLWithPath: "/tmp/test_extract_parent")
        let result = SmartExtractResolver.resolve(
            entryPaths: entries,
            destinationParentURL: destParent,
            archiveStemName: "LooseFilesArchive"
        )
        
        XCTAssertEqual(result.resolutionMode, .wrapInFolder)
        XCTAssertEqual(result.effectiveRootCount, 4)
        XCTAssertNil(result.singleRootName)
        XCTAssertEqual(result.finalExtractionURL.lastPathComponent, "LooseFilesArchive")
    }
    
    func testMacOSAppBundleResolvesToDirectExtract() {
        let entries = [
            "TTZip.app/Contents/Info.plist",
            "TTZip.app/Contents/MacOS/TTZip",
            "TTZip.app/Contents/Resources/AppIcon.icns",
            ".DS_Store"
        ]
        let destParent = URL(fileURLWithPath: "/tmp/test_extract_parent")
        let result = SmartExtractResolver.resolve(
            entryPaths: entries,
            destinationParentURL: destParent,
            archiveStemName: "TTZip_v1.0"
        )
        
        XCTAssertEqual(result.resolutionMode, .directExtract)
        XCTAssertEqual(result.effectiveRootCount, 1)
        XCTAssertEqual(result.singleRootName, "TTZip.app")
        XCTAssertEqual(result.finalExtractionURL, destParent)
    }
    
    func testEmptyArchiveResolvesToEmptyArchive() {
        let entries: [String] = [
            ".DS_Store",
            "__MACOSX/._dummy"
        ]
        let destParent = URL(fileURLWithPath: "/tmp/test_extract_parent")
        let result = SmartExtractResolver.resolve(
            entryPaths: entries,
            destinationParentURL: destParent,
            archiveStemName: "EmptyArchive"
        )
        
        XCTAssertEqual(result.resolutionMode, .emptyArchive)
        XCTAssertEqual(result.effectiveRootCount, 0)
        XCTAssertNil(result.singleRootName)
        XCTAssertEqual(result.finalExtractionURL, destParent)
    }
}
