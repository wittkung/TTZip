// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//
//  PathPatternFilterEngineTests.swift
//  TTZipTests
//
//  Created by TTZip on 2026-08-17.
//  Copyright © 2026 TTZip. All rights reserved.
//

import XCTest
@testable import TTZipCore

final class PathPatternFilterEngineTests: XCTestCase {
    
    // MARK: - Glob Matching Tests
    
    func testFastPathExtensionMatching() {
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "*.txt", path: "document.txt"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "*.txt", path: "nested/folder/document.txt"))
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "*.txt", path: "document.pdf"))
        
        // Case sensitivity
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "*.txt", path: "document.TXT", caseSensitive: true))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "*.txt", path: "document.TXT", caseSensitive: false))
    }
    
    func testRootAnchoredPatterns() {
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "/build/*", path: "/build/output.bin"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "/build/*", path: "build/output.bin"))
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "/build/*", path: "src/build/output.bin"))
    }
    
    func testHierarchicalPathPatterns() {
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "src/*.swift", path: "src/main.swift"))
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "src/*.swift", path: "src/sub/main.swift"))
        
        // Double-star patterns
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "**/*.log", path: "app.log"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "**/*.log", path: "logs/2026/08/app.log"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "build/**", path: "build/debug/obj/main.o"))
    }
    
    func testBasenameAndComponentMatching() {
        // Pattern without slash matches basename
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "*.o", path: "foo/bar/baz.o"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "node_modules", path: "web/frontend/node_modules/react/index.js"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "node_modules", path: "node_modules"))
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "node_modules", path: "src/modules/index.js"))
    }
    
    // MARK: - Metadata Detection Tests
    
    func testVCSMetadataDetection() {
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata(".git"))
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata(".git/config"))
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata("project/.git/HEAD"))
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata(".gitignore"))
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata("subfolder/.gitignore"))
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata(".svn/entries"))
        XCTAssertTrue(PathPatternFilterEngine.isVCSMetadata(".hg/dirstate"))
        
        XCTAssertFalse(PathPatternFilterEngine.isVCSMetadata("src/git_helper.swift"))
        XCTAssertFalse(PathPatternFilterEngine.isVCSMetadata("my_project/main.c"))
    }
    
    func testMacMetadataDetection() {
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata(".DS_Store"))
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata("folder/.DS_Store"))
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata("__MACOSX/._image.png"))
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata("._file.txt"))
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata("sub/._file.txt"))
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata(".Spotlight-V100/Store.db"))
        XCTAssertTrue(PathPatternFilterEngine.isMacMetadata(".Trashes/501/old.zip"))
        
        XCTAssertFalse(PathPatternFilterEngine.isMacMetadata("document.pdf"))
        XCTAssertFalse(PathPatternFilterEngine.isMacMetadata("Images/photo.jpg"))
    }
    
    // MARK: - ShouldInclude & ShouldExclude Decision Tests
    
    func testShouldIncludeAndExcludeRules() {
        // Exclude VCS
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: ".git/index", excludeVCS: true))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: ".git/index", excludeVCS: true))
        
        // Exclude Mac metadata
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: "folder/.DS_Store", noMacMetadata: true))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: "folder/.DS_Store", noMacMetadata: true))
        
        // Custom exclude patterns
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: "logs/error.log", excludePatterns: ["*.log"]))
        XCTAssertTrue(PathPatternFilterEngine.shouldInclude(path: "src/main.swift", excludePatterns: ["*.log"]))
        
        // Include patterns override / constrain
        XCTAssertTrue(PathPatternFilterEngine.shouldInclude(path: "src/main.swift", includePatterns: ["*.swift"]))
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: "src/main.c", includePatterns: ["*.swift"]))
        
        // Combined options
        var options = ArchiveFilterOptions.defaultClean
        options.excludePatterns = ["*.tmp", "build/*"]
        options.excludeVCS = true
        
        XCTAssertTrue(PathPatternFilterEngine.shouldInclude(path: "Sources/Core/Engine.swift", options: options))
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: "Sources/Core/.git/config", options: options))
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: "temp.tmp", options: options))
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: "build/out.bin", options: options))
        XCTAssertFalse(PathPatternFilterEngine.shouldInclude(path: ".DS_Store", options: options))
    }
    
    // MARK: - Component Stripping Tests
    
    func testStripLeadingComponents() {
        // Normal stripping
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("a/b/c/d.txt", count: 1), "b/c/d.txt")
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("a/b/c/d.txt", count: 2), "c/d.txt")
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("a/b/c/d.txt", count: 3), "d.txt")
        
        // Exhausted components -> nil
        XCTAssertNil(PathPatternFilterEngine.stripLeadingComponents("a/b/c/d.txt", count: 4))
        XCTAssertNil(PathPatternFilterEngine.stripLeadingComponents("a/b/c/d.txt", count: 5))
        XCTAssertNil(PathPatternFilterEngine.stripLeadingComponents("single_file.txt", count: 1))
        
        // Count <= 0 returns original
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("a/b/c", count: 0), "a/b/c")
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("a/b/c", count: -1), "a/b/c")
        
        // Leading slashes and relative prefixes
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("/var/log/app.log", count: 2), "app.log")
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("./src/models/item.swift", count: 1), "models/item.swift")
        XCTAssertEqual(PathPatternFilterEngine.stripLeadingComponents("a///b///c.txt", count: 1), "b///c.txt")
    }
}
