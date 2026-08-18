// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class EdgeCaseTests: XCTestCase {
    
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
    
    func testEmptyInputPathsThrowsError() async {
        let writer = ArchiveWriter()
        let output = (tempDirPath as NSString).appendingPathComponent("empty.zip")
        
        do {
            try await writer.createArchive(outputPath: output, inputPaths: [])
            XCTFail("Should throw ArchiveError.readFailed for empty inputs")
        } catch let error as ArchiveError {
            if case .readFailed(let code) = error {
                XCTAssertEqual(code, -10)
            } else {
                XCTFail("Unexpected ArchiveError code: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testZeroByteFileInspectReturnsEmptyEntries() async throws {
        let emptyFile = (tempDirPath as NSString).appendingPathComponent("zero.zip")
        FileManager.default.createFile(atPath: emptyFile, contents: Data())
        
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: emptyFile)
        XCTAssertEqual(entries.count, 0, "Inspecting 0-byte file should return 0 entries cleanly")
    }
    
    func testTaskCancellationBeforeInspect() async {
        let reader = ArchiveReader()
        let task = Task {
            try Task.checkCancellation()
            return try await reader.inspect(archivePath: "/some/file.zip")
        }
        
        task.cancel()
        
        do {
            _ = try await task.value
            XCTFail("Task should have been cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}
