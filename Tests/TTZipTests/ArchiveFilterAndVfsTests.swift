// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class ArchiveFilterAndVfsTests: XCTestCase {
    
    // MARK: - 1. ArchiveFilter Rust C-ABI Direct Evaluator Tests
    
    func testArchiveFilterDSLDirectEvaluation() {
        let entry1 = ArchiveEntry(
            path: "images/photo.jpg",
            uncompressedSize: 5000,
            isDirectory: false,
            modificationDate: Date(timeIntervalSince1970: 10000)
        )
        let entry2 = ArchiveEntry(
            path: "docs/manual.pdf",
            uncompressedSize: 200,
            isDirectory: false,
            modificationDate: Date(timeIntervalSince1970: 10000)
        )
        
        let filterJpg = ArchiveFilter(expression: "ext:jpg")
        XCTAssertTrue(filterJpg.evaluate(entry: entry1))
        XCTAssertFalse(filterJpg.evaluate(entry: entry2))
        
        let filterSize = ArchiveFilter(expression: "size:>1000")
        XCTAssertTrue(filterSize.evaluate(entry: entry1))
        XCTAssertFalse(filterSize.evaluate(entry: entry2))
        
        let filterCompound = ArchiveFilter(expression: "ext:jpg AND size:>1000")
        XCTAssertTrue(filterCompound.evaluate(entry: entry1))
        XCTAssertFalse(filterCompound.evaluate(entry: entry2))
    }
    
    func testArchiveFilterStaticHelpersAndBatchFiltering() {
        let entry1 = ArchiveEntry(path: "src/main.rs", uncompressedSize: 1024, isDirectory: false)
        let entry2 = ArchiveEntry(path: "src/lib.swift", uncompressedSize: 2048, isDirectory: false)
        let entry3 = ArchiveEntry(path: "README.md", uncompressedSize: 512, isDirectory: false)
        let entries = [entry1, entry2, entry3]
        
        XCTAssertTrue(ArchiveFilter.evaluate(expression: "ext:rs", entry: entry1))
        XCTAssertFalse(ArchiveFilter.evaluate(expression: "ext:rs", entry: entry2))
        XCTAssertTrue(ArchiveFilter.evaluate(entry: entry2, query: "ext:swift"))
        
        let filtered = ArchiveFilter.filter(entries: entries, expression: "ext:rs OR ext:swift")
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.path == "src/main.rs" })
        XCTAssertTrue(filtered.contains { $0.path == "src/lib.swift" })
        
        // Empty expression matches all
        let all = ArchiveFilter.filter(entries: entries, expression: "")
        XCTAssertEqual(all.count, 3)
    }
    
    func testArchiveFilterDSLInterpreterFacadeAndOptionsIntegration() {
        let entry = ArchiveEntry(path: "test/unit.log", uncompressedSize: 300, isDirectory: false)
        
        XCTAssertTrue(ArchiveFilter.evaluate(entry: entry, query: "ext:log"))
        XCTAssertFalse(ArchiveFilter.evaluate(entry: entry, query: "ext:txt"))
        
        let options = ArchiveFilterOptions(skipMacJunk: true)
        XCTAssertTrue(options.matches(entry: entry, dslQuery: "ext:log"))
        XCTAssertFalse(options.matches(entry: entry, dslQuery: "ext:txt"))
        
        let macJunkEntry = ArchiveEntry(path: "__MACOSX/._test.log", uncompressedSize: 100, isDirectory: false)
        XCTAssertFalse(options.matches(entry: macJunkEntry, dslQuery: "ext:log"))
    }
    
    // MARK: - 2. RustVfsBridge & ArchiveReader VFS Integration Tests
    
    func testRustVfsBridgeRenderTreeAndFuzzySearch() {
        let entry1 = ArchiveEntry(path: "src/engine/core.rs", uncompressedSize: 4096, isDirectory: false)
        let entry2 = ArchiveEntry(path: "src/engine/vfs.rs", uncompressedSize: 2048, isDirectory: false)
        let entry3 = ArchiveEntry(path: "docs/architecture.md", uncompressedSize: 1024, isDirectory: false)
        let entries = [entry1, entry2, entry3]
        
        let rendered = RustVfsBridge.renderTree(from: entries, rootName: "my_project")
        XCTAssertFalse(rendered.isEmpty)
        XCTAssertTrue(rendered.contains("core.rs") || rendered.contains("src"))
        
        let searchResults = RustVfsBridge.fuzzySearch(in: entries, query: "core")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.path, "src/engine/core.rs")
        
        let stats = RustVfsBridge.getStats(from: entries, rootName: "my_project")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.totalFiles, 3)
        XCTAssertEqual(stats?.totalSize, 4096 + 2048 + 1024)
    }
}
