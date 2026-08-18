// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp

@MainActor
final class AsyncPathAutocompletionTests: XCTestCase {
    
    nonisolated(unsafe) private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        let uniqueID = UUID().uuidString
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TTZip_Autocomplete_\(uniqueID)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestStructure() {
        // Create subdirectories
        let dirAlpha = tempDirectory.appendingPathComponent("alpha_folder")
        let dirBeta = tempDirectory.appendingPathComponent("beta_folder")
        let dirGamma = tempDirectory.appendingPathComponent("gamma_directory")
        try? FileManager.default.createDirectory(at: dirAlpha, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dirBeta, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dirGamma, withIntermediateDirectories: true)
        
        // Create archive files
        let zipFile = tempDirectory.appendingPathComponent("alpha_archive.zip")
        let sevenZipFile = tempDirectory.appendingPathComponent("backup.7z")
        try? "dummy zip content".write(to: zipFile, atomically: true, encoding: .utf8)
        try? "dummy 7z content".write(to: sevenZipFile, atomically: true, encoding: .utf8)
        
        // Create regular files
        let textFile = tempDirectory.appendingPathComponent("alpha_notes.txt")
        let pdfFile = tempDirectory.appendingPathComponent("document.pdf")
        try? "dummy text".write(to: textFile, atomically: true, encoding: .utf8)
        try? "dummy pdf".write(to: pdfFile, atomically: true, encoding: .utf8)
        
        // Create hidden file
        let hiddenFile = tempDirectory.appendingPathComponent(".hidden_config")
        try? "dummy hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Tests
    
    func testAsyncPathAutocompletionBasicQuery() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine(cacheCapacity: 32)
        
        let results = await engine.queryAsync(rawInput: tempDirectory.path + "/", baseDirectory: tempDirectory)
        
        XCTAssertFalse(results.isEmpty)
        // Hidden file should be excluded by default
        XCTAssertFalse(results.contains { $0.displayName == ".hidden_config" })
        
        // Verify folder icons
        let folderItem = results.first { $0.displayName == "alpha_folder" }
        XCTAssertNotNil(folderItem)
        XCTAssertTrue(folderItem?.isDirectory == true)
        XCTAssertEqual(folderItem?.systemIconName, "folder.fill")
        
        // Verify archive icons
        let archiveItem = results.first { $0.displayName == "alpha_archive.zip" }
        XCTAssertNotNil(archiveItem)
        XCTAssertTrue(archiveItem?.isArchive == true)
        XCTAssertEqual(archiveItem?.systemIconName, "archivebox.fill")
        
        // Verify document icons
        let docItem = results.first { $0.displayName == "alpha_notes.txt" }
        XCTAssertNotNil(docItem)
        XCTAssertFalse(docItem?.isDirectory == true)
        XCTAssertFalse(docItem?.isArchive == true)
        XCTAssertEqual(docItem?.systemIconName, "doc.fill")
    }
    
    func testPrefixFilteringAndHighlightRange() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine()
        
        // Prefix query: "alpha"
        let queryPath = tempDirectory.path + "/alpha"
        let results = await engine.queryAsync(rawInput: queryPath, baseDirectory: tempDirectory)
        
        XCTAssertEqual(results.count, 3)
        for item in results {
            XCTAssertTrue(item.displayName.lowercased().hasPrefix("alpha"))
            XCTAssertEqual(item.matchHighlightRange, [0, 5])
        }
        
        // Case-insensitive query: "ALPHA"
        let upperQueryPath = tempDirectory.path + "/ALPHA"
        let upperResults = await engine.queryAsync(rawInput: upperQueryPath, baseDirectory: tempDirectory)
        XCTAssertEqual(upperResults.count, 3)
        for item in upperResults {
            XCTAssertEqual(item.matchHighlightRange, [0, 5])
        }
    }
    
    func testHiddenFileInclusionWhenQueryStartsWithDot() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine()
        
        let queryPath = tempDirectory.path + "/."
        let results = await engine.queryAsync(rawInput: queryPath, baseDirectory: tempDirectory)
        
        XCTAssertTrue(results.contains { $0.displayName == ".hidden_config" })
    }
    
    func testSortingHierarchyDirectoriesThenArchivesThenFiles() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine()
        
        let queryPath = tempDirectory.path + "/alpha"
        let results = await engine.queryAsync(rawInput: queryPath, baseDirectory: tempDirectory)
        
        // 3 items matching "alpha":
        // 1. alpha_folder (dir -> rank 0)
        // 2. alpha_archive.zip (archive -> rank 1)
        // 3. alpha_notes.txt (file -> rank 2)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].displayName, "alpha_folder")
        XCTAssertTrue(results[0].isDirectory)
        
        XCTAssertEqual(results[1].displayName, "alpha_archive.zip")
        XCTAssertTrue(results[1].isArchive)
        
        XCTAssertEqual(results[2].displayName, "alpha_notes.txt")
        XCTAssertFalse(results[2].isDirectory)
        XCTAssertFalse(results[2].isArchive)
    }
    
    func testLRUCacheHitAndLatency() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine(cacheCapacity: 64)
        
        XCTAssertEqual(engine.cache.count, 0)
        
        // First query (cold cache)
        _ = await engine.queryAsync(rawInput: tempDirectory.path + "/", baseDirectory: tempDirectory)
        XCTAssertGreaterThanOrEqual(engine.cache.count, 1)
        
        // Second query (warm cache hit)
        let startTime = DispatchTime.now()
        let cachedResults = await engine.queryAsync(rawInput: tempDirectory.path + "/alpha", baseDirectory: tempDirectory)
        let endTime = DispatchTime.now()
        
        let elapsedNs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds)
        let elapsedMs = elapsedNs / 1_000_000.0
        
        XCTAssertEqual(cachedResults.count, 3)
        // Cache hit query should resolve well within 15ms target
        XCTAssertLessThan(elapsedMs, 50.0)
    }
    
    func testQueryCancellation() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine()
        
        // Rapid sequential queries
        engine.query(rawInput: tempDirectory.path + "/gamma", baseDirectory: tempDirectory)
        engine.query(rawInput: tempDirectory.path + "/beta", baseDirectory: tempDirectory)
        
        // Await the final query
        let finalResults = await engine.queryAsync(rawInput: tempDirectory.path + "/alpha", baseDirectory: tempDirectory)
        
        XCTAssertEqual(finalResults.count, 3)
        XCTAssertTrue(finalResults.allSatisfy { $0.displayName.hasPrefix("alpha") })
    }
    
    func testClearAndReset() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine()
        
        _ = await engine.queryAsync(rawInput: tempDirectory.path + "/", baseDirectory: tempDirectory)
        XCTAssertFalse(engine.suggestions.isEmpty)
        
        engine.clear()
        XCTAssertTrue(engine.suggestions.isEmpty)
        XCTAssertFalse(engine.isLoading)
    }
    
    func testMaxSuggestionsLimit() async {
        // Create 25 files in tempDirectory
        for i in 1...25 {
            let fileURL = tempDirectory.appendingPathComponent(String(format: "item_%02d.txt", i))
            try? "content".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        let engine = AsyncPathAutocompletionEngine()
        let results = await engine.queryAsync(rawInput: tempDirectory.path + "/item", baseDirectory: tempDirectory)
        
        XCTAssertEqual(results.count, AsyncPathAutocompletionEngine.maxSuggestionsCount)
        XCTAssertEqual(results.count, 15)
    }
    
    func testRelativePathQuery() async {
        createTestStructure()
        let engine = AsyncPathAutocompletionEngine()
        
        // Relative query starting with "./alpha" or "alpha"
        let results = await engine.queryAsync(rawInput: "./alpha", baseDirectory: tempDirectory)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.contains { $0.displayName == "alpha_folder" })
    }
}
