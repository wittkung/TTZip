// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class TarSnappyInProcessTests: XCTestCase {

    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_snappy_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testTarSnappyArchiveCreationAndExtraction() async throws {
        // Create test directory hierarchy with multiple files
        let srcDir = tempDir.appendingPathComponent("source_tree")
        let subDir = srcDir.appendingPathComponent("nested_dir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let file1 = srcDir.appendingPathComponent("file1.txt")
        let file2 = subDir.appendingPathComponent("file2.txt")
        let file3 = srcDir.appendingPathComponent("large_data.bin")

        let content1 = "Hello TTZip Native In-Process Snappy Archive Creation!"
        let content2 = "Nested Subdirectory Snappy Framed Stream File 2 Content."
        var largeContent = Data(count: 128 * 1024)
        for i in 0..<largeContent.count {
            largeContent[i] = UInt8((i * 37 + 13) & 0xFF)
        }

        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2, atomically: true, encoding: .utf8)
        try largeContent.write(to: file3)

        let archivePath = tempDir.appendingPathComponent("test_archive.tar.sz")
        let extractDir = tempDir.appendingPathComponent("extracted_tree")

        // 1. Create TAR.SZ archive using ArchiveWriter
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archivePath.path,
            format: .snappy,
            level: .level1,
            inputPaths: [srcDir.path]
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath.path), "Archive file should exist on disk")

        // 2. Verify magic header starts with standard Snappy framing identifier
        let archiveData = try Data(contentsOf: archivePath)
        XCTAssertGreaterThanOrEqual(archiveData.count, 10)
        XCTAssertTrue(SnappyFramingStream.shared.isFramedSnappy(data: archiveData), "Archive must begin with \\xFF\\x06\\x00\\x00sNaPpY")

        // 3. Extract TAR.SZ archive using in-process native extraction
        let extractRes = ttzip_extract_tar_snappy_native_c(
            archivePath.path,
            extractDir.path,
            false
        )
        XCTAssertEqual(extractRes, TTZIP_OK.rawValue, "Native in-process Snappy extract must succeed with TTZIP_OK")

        // 4. Verify extracted contents
        let extractedRoot = extractDir.appendingPathComponent("source_tree")
        let extractedF1 = extractedRoot.appendingPathComponent("file1.txt")
        let extractedF2 = extractedRoot.appendingPathComponent("nested_dir").appendingPathComponent("file2.txt")
        let extractedF3 = extractedRoot.appendingPathComponent("large_data.bin")

        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedF1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedF2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedF3.path))

        let restored1 = try String(contentsOf: extractedF1, encoding: .utf8)
        let restored2 = try String(contentsOf: extractedF2, encoding: .utf8)
        let restored3 = try Data(contentsOf: extractedF3)

        XCTAssertEqual(restored1, content1)
        XCTAssertEqual(restored2, content2)
        XCTAssertEqual(restored3, largeContent)
    }
}
