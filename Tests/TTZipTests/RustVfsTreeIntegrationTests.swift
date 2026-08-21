// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class RustVfsTreeIntegrationTests: XCTestCase {
    
    // MARK: - 1. Safe Rust VFS Tree Building & Rendering
    
    func testRustVfsTreeRenderFormatting() {
        let entries = [
            ArchiveEntry(path: "Project/src/main.swift", uncompressedSize: 500, isDirectory: false),
            ArchiveEntry(path: "Project/src/utils.swift", uncompressedSize: 300, isDirectory: false),
            ArchiveEntry(path: "Project/README.md", uncompressedSize: 150, isDirectory: false)
        ]
        
        let rendered = RustVfsBridge.renderTree(from: entries, rootName: "Project")
        XCTAssertFalse(rendered.isEmpty)
        XCTAssertTrue(rendered.contains("Project (<DIR>)"))
        XCTAssertTrue(rendered.contains("src (<DIR>)"))
        XCTAssertTrue(rendered.contains("main.swift"))
        XCTAssertTrue(rendered.contains("utils.swift"))
        XCTAssertTrue(rendered.contains("README.md"))
        
        let treeBuilderRendered = ArchiveComponentTreeBuilder.renderTree(from: entries, rootName: "Project")
        XCTAssertEqual(treeBuilderRendered, rendered)
    }
    
    // MARK: - 2. Safe Rust VFS High-Performance Fuzzy Search
    
    func testRustVfsFuzzySearch() {
        let entries = [
            ArchiveEntry(path: "Sources/TTZipCore/ArchiveReader.swift", uncompressedSize: 1200, isDirectory: false),
            ArchiveEntry(path: "Sources/TTZipCore/ArchiveWriter.swift", uncompressedSize: 1800, isDirectory: false),
            ArchiveEntry(path: "Sources/TTZipCore/ArchiveExtractor.swift", uncompressedSize: 1500, isDirectory: false),
            ArchiveEntry(path: "Documentation/Architecture.md", uncompressedSize: 4500, isDirectory: false),
            ArchiveEntry(path: "Tests/TTZipTests/ArchiveReaderTests.swift", uncompressedSize: 2000, isDirectory: false)
        ]
        
        // Exact prefix search
        let readerMatches = RustVfsBridge.fuzzySearch(in: entries, query: "Reader")
        XCTAssertFalse(readerMatches.isEmpty)
        XCTAssertEqual(readerMatches.first?.path, "Sources/TTZipCore/ArchiveReader.swift")
        
        // Subsequence fuzzy search
        let archMatches = ArchiveComponentTreeBuilder.fuzzySearch(in: entries, query: "Arch")
        XCTAssertGreaterThanOrEqual(archMatches.count, 4)
        
        // Empty query returns all entries
        let allMatches = RustVfsBridge.fuzzySearch(in: entries, query: "")
        XCTAssertEqual(allMatches.count, entries.count)
    }
    
    // MARK: - 3. ArchiveReader inspectTree & fuzzySearch
    
    func testArchiveReaderInspectTreeAndFuzzySearch() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let file1 = tempDir.appendingPathComponent("document.txt")
        let file2 = tempDir.appendingPathComponent("graphic.png")
        try "Document Text Content".write(to: file1, atomically: true, encoding: .utf8)
        try "PNG Image Data".write(to: file2, atomically: true, encoding: .utf8)
        
        let zipPath = tempDir.appendingPathComponent("test_vfs.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zipPath,
            format: .zip,
            level: .normal,
            inputPaths: [file1.path, file2.path]
        )
        
        let reader = ArchiveReader()
        
        // 1. inspectTree
        let tree = try await reader.inspectTree(archivePath: zipPath)
        XCTAssertTrue(tree.isDirectory)
        XCTAssertEqual(tree.totalFileCount(), 2)
        
        // 2. fuzzySearch
        let docResults = try await reader.fuzzySearch(archivePath: zipPath, query: "doc")
        XCTAssertFalse(docResults.isEmpty)
        XCTAssertTrue(docResults.contains(where: { $0.path.contains("document.txt") }))
    }
    
    // MARK: - 4. High-Scale VFS Tree & Search Stress Test (< 10ms)
    
    func testVfsTreeAndSearchLargeScaleStress() {
        var largeEntries: [ArchiveEntry] = []
        largeEntries.reserveCapacity(2000)
        
        for i in 0..<2000 {
            let dirId = i / 50
            let path = "Folder_\(dirId)/subfolder_\(i % 5)/file_\(i).dat"
            largeEntries.append(ArchiveEntry(path: path, uncompressedSize: Int64(i * 10), isDirectory: false))
        }
        
        let startTreeTime = CFAbsoluteTimeGetCurrent()
        let rendered = RustVfsBridge.renderTree(from: largeEntries, rootName: "Root")
        let treeDurationMs = (CFAbsoluteTimeGetCurrent() - startTreeTime) * 1000.0
        
        XCTAssertFalse(rendered.isEmpty)
        XCTAssertLessThan(treeDurationMs, 50.0) // < 50ms for 2,000 entries
        
        let startSearchTime = CFAbsoluteTimeGetCurrent()
        let searchResults = RustVfsBridge.fuzzySearch(in: largeEntries, query: "file_1234")
        let searchDurationMs = (CFAbsoluteTimeGetCurrent() - startSearchTime) * 1000.0
        
        XCTAssertFalse(searchResults.isEmpty)
        XCTAssertEqual(searchResults.first?.path, "Folder_24/subfolder_4/file_1234.dat")
        XCTAssertLessThan(searchDurationMs, 20.0) // < 20ms fuzzy search
    }
}
