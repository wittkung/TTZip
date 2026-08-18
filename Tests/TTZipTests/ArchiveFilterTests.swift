// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveFilterTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    func testMacJunkFilteredWhenPacking() async throws {
        let validFile = (tempDirPath as NSString).appendingPathComponent("valid_document.pdf")
        let dsStoreFile = (tempDirPath as NSString).appendingPathComponent(".DS_Store")
        let appleDoubleFile = (tempDirPath as NSString).appendingPathComponent("._valid_document.pdf")
        
        try "PDF Data".write(toFile: validFile, atomically: true, encoding: .utf8)
        try "Junk Data".write(toFile: dsStoreFile, atomically: true, encoding: .utf8)
        try "Fork Data".write(toFile: appleDoubleFile, atomically: true, encoding: .utf8)
        
        let outputZip = (tempDirPath as NSString).appendingPathComponent("clean.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outputZip,
            format: .zip,
            level: .normal,
            inputPaths: [validFile, dsStoreFile, appleDoubleFile],
            options: ArchiveFilterOptions(skipMacJunk: true)
        )
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: outputZip)
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "valid_document.pdf")
    }
}
