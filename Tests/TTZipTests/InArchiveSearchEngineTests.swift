// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class InArchiveSearchEngineTests: XCTestCase {
    private var tempDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("TTZip_SearchTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    func test100kNodesSearchIndexPerformance() {
        let index = ArchiveSearchIndex()
        let count = 100_000
        
        var mockEntries = [(path: String, size: Int64, isDir: Bool)]()
        mockEntries.reserveCapacity(count)
        
        for i in 0..<count {
            let path = "root/subfolder_\(i / 1000)/document_item_\(i).pdf"
            mockEntries.append((path: path, size: Int64(i * 100), isDir: false))
        }
        // Add a specific needle
        mockEntries.append((path: "secret/confidential_financial_report_2026.xlsx", size: 1024000, isDir: false))
        
        index.build(entries: mockEntries)
        
        let query = ArchiveSearchQuery(
            queryText: "financial_report",
            isRegex: false,
            caseSensitive: false
        )
        
        let result = index.search(query: query)
        
        XCTAssertEqual(result.matchedEntriesCount, 1)
        XCTAssertLessThanOrEqual(result.searchDurationMs, 25.0, "100k nodes search must execute in sub-25ms")
        print("[SEARCH BENCHMARK] Scanned \(result.totalScannedEntries) items in \(String(format: "%.2f", result.searchDurationMs)) ms")
    }
    
    func testZipSelectiveExtractorFastPath() async throws {
        let file1 = tempDirectoryURL.appendingPathComponent("file1.txt").path
        let file2 = tempDirectoryURL.appendingPathComponent("target_report.txt").path
        let file3 = tempDirectoryURL.appendingPathComponent("file3.txt").path
        
        try "Content 1".write(toFile: file1, atomically: true, encoding: .utf8)
        try "Target Report Content 2026".write(toFile: file2, atomically: true, encoding: .utf8)
        try "Content 3".write(toFile: file3, atomically: true, encoding: .utf8)
        
        let zipPath = tempDirectoryURL.appendingPathComponent("archive.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: zipPath, format: .zip, inputPaths: [file1, file2, file3])
        
        let destDir = tempDirectoryURL.appendingPathComponent("selective_out").path
        let selectiveExtractor = ArchiveSelectiveExtractor.shared
        
        let extractedCount = try await selectiveExtractor.extractSelected(
            archivePath: zipPath,
            targetEntryPaths: ["target_report.txt"],
            destinationDir: destDir
        )
        
        XCTAssertEqual(extractedCount, 1)
        let extractedFile = (destDir as NSString).appendingPathComponent("target_report.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        let text = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(text, "Target Report Content 2026")
        
        // Ensure unselected files were not extracted
        XCTAssertFalse(FileManager.default.fileExists(atPath: (destDir as NSString).appendingPathComponent("file1.txt")))
    }
}
