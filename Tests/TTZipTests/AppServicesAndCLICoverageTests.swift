// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class AppServicesAndCLICoverageTests: XCTestCase {
    
    var tempDirURL: URL!
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("AppServicesTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        tempDirPath = tempDirURL.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // 1. Test DeepFileMetadataReader POSIX permissions and APFS Inode inspection
    func testDeepFileMetadataReader() async throws {
        let sampleFile = tempDirURL.appendingPathComponent("metadata_sample.txt")
        try "Metadata Reader Test Data 2026".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let metadata = await DeepFileMetadataReader.readMetadata(for: sampleFile)
        XCTAssertFalse(metadata.isEmpty)
        XCTAssertNotNil(metadata["POSIX Permissions"])
        XCTAssertNotNil(metadata["Owner : Group"])
        XCTAssertNotNil(metadata["APFS Inode"])
    }
    
    // 2. Test FolderStatsVisitor directory sizing and distribution
    func testFolderStatsVisitor() throws {
        let leaf1 = ArchiveLeafFile(name: "doc.txt", path: "subfolder/doc.txt", sizeBytes: 100)
        let leaf2 = ArchiveLeafFile(name: "video.mp4", path: "subfolder/video.mp4", sizeBytes: 2000)
        let dir = ArchiveCompositeDirectory(name: "subfolder", path: "subfolder", children: [leaf1, leaf2])
        let root = ArchiveCompositeDirectory(name: "root", path: "", children: [dir])
        
        let stats = root.accept(visitor: FolderStatsVisitor())
        XCTAssertGreaterThan(stats.totalSizeBytes, 0)
        XCTAssertEqual(stats.totalDirectories, 1)
        XCTAssertEqual(stats.totalFiles, 2)
        XCTAssertFalse(stats.categoryDistribution.isEmpty)
    }
    
    // 3. Test DateFormatterCache and ByteCountFormatterCache thread-safe formatting
    func testFormattersCache() {
        let sizeString = ByteCountFormatterCache.string(fromByteCount: 1024 * 1024 * 50)
        XCTAssertFalse(sizeString.isEmpty)
        
        let dateString = DateFormatterCache.shared.string(fromShortDateTime: Date())
        XCTAssertFalse(dateString.isEmpty)
    }
}
