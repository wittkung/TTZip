// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CLIFilterAndPipingTests: XCTestCase {
    
    // MARK: - 1. PathPatternFilterEngine Tests
    
    func testGlobPatternMatching() {
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "*.txt", path: "document.txt"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "*.txt", path: "nested/folder/document.txt"))
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "*.txt", path: "document.pdf"))
        
        // Exact directory prefix
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "build/*", path: "build/out.bin"))
        XCTAssertTrue(PathPatternFilterEngine.matches(pattern: "build/**", path: "build/nested/out.bin"))
        XCTAssertFalse(PathPatternFilterEngine.matches(pattern: "build/*", path: "src/build/out.bin"))
    }
    
    func testExclusionRules() {
        let opts = ArchiveFilterOptions(
            excludePatterns: ["*.tmp", "cache/*"],
            includePatterns: [],
            stripComponents: 0,
            excludeVCS: true,
            noMacMetadata: true
        )
        
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: "test.tmp", options: opts))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: "cache/data.db", options: opts))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: ".git/HEAD", options: opts))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: "__MACOSX/._file", options: opts))
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: ".DS_Store", options: opts))
        
        XCTAssertFalse(PathPatternFilterEngine.shouldExclude(path: "src/main.swift", options: opts))
    }
    
    func testInclusionRuleOverrides() {
        let opts = ArchiveFilterOptions(
            excludePatterns: ["*.txt"],
            includePatterns: ["important.txt"],
            stripComponents: 0,
            excludeVCS: false,
            noMacMetadata: false
        )
        
        // important.txt matches include, so it is NOT excluded
        XCTAssertFalse(PathPatternFilterEngine.shouldExclude(path: "important.txt", options: opts))
        // other.txt matches exclude and does not match include -> excluded
        XCTAssertTrue(PathPatternFilterEngine.shouldExclude(path: "other.txt", options: opts))
    }
    
    func testStripComponents() {
        XCTAssertEqual(
            PathPatternFilterEngine.stripLeadingComponents("a/b/c/file.txt", count: 1),
            "b/c/file.txt"
        )
        XCTAssertEqual(
            PathPatternFilterEngine.stripLeadingComponents("a/b/c/file.txt", count: 2),
            "c/file.txt"
        )
        XCTAssertEqual(
            PathPatternFilterEngine.stripLeadingComponents("a/b/c/file.txt", count: 3),
            "file.txt"
        )
        XCTAssertNil(
            PathPatternFilterEngine.stripLeadingComponents("a/b/c/file.txt", count: 4)
        )
        XCTAssertNil(
            PathPatternFilterEngine.stripLeadingComponents("a/b/c/file.txt", count: 5)
        )
    }
    
    // MARK: - 2. FileFilterListLoader Tests
    
    func testFileFilterListLoader() async throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_manifest_\(UUID().uuidString).txt").path
        let sampleContent = """
        # Comment line
        src/App.swift
        
        # Another comment
        src/Views/MainView.swift
        README.md
        """
        try sampleContent.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }
        
        let loaded = try await FileFilterListLoader.loadPaths(from: tmpFile)
        XCTAssertEqual(loaded, ["src/App.swift", "src/Views/MainView.swift", "README.md"])
    }
    
    func testFileFilterListLoaderNullDelimited() async throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_null_manifest_\(UUID().uuidString).txt").path
        var data = Data()
        data.append(contentsOf: "file1.txt\0file2.txt\0folder/file3.txt\0".utf8)
        try data.write(to: URL(fileURLWithPath: tmpFile))
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }
        
        let loaded = try await FileFilterListLoader.loadPaths(from: tmpFile, nullDelimiter: true)
        XCTAssertEqual(loaded, ["file1.txt", "file2.txt", "folder/file3.txt"])
    }
}
