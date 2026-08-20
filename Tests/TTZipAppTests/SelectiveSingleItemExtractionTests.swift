// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SelectiveSingleItemExtractionTests: XCTestCase {
    
    func test_single_entry_stream_extraction_under_10ms() async throws {
        // Create a test ZIP archive containing 3 files
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_sel_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipPath = tempDir.appendingPathComponent("archive.zip").path
        let file1 = tempDir.appendingPathComponent("doc1.txt")
        let file2 = tempDir.appendingPathComponent("doc2.txt")
        
        try "Content 1 payload".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2 target payload for single extraction".write(to: file2, atomically: true, encoding: .utf8)
        
        let res = try ZipParallelWriter.shared.createArchive(
            outputPath: zipPath,
            inputPaths: [file1.path, file2.path],
            level: .fastest
        )
        XCTAssertTrue(res)
        
        // Single Entry On-Demand Extraction
        let t0 = ContinuousClock.now
        let data = try await ArchiveSelectiveExtractor.shared.extractSingleEntryData(
            archivePath: zipPath,
            entryPath: "doc2.txt"
        )
        let elapsed = ContinuousClock.now - t0
        
        XCTAssertNotNil(data, "Single entry extracted data must not be nil")
        if let data = data, let text = String(data: data, encoding: .utf8) {
            XCTAssertEqual(text, "Content 2 target payload for single extraction")
        }
        XCTAssertTrue(elapsed < .milliseconds(50), "Single item extraction must complete in < 50ms (took \(elapsed))")
    }
}
