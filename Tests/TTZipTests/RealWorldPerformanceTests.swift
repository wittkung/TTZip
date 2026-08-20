// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import XCTest
@testable import TTZipCore

final class RealWorldPerformanceTests: XCTestCase {
    
    func testZipPackaging_BasicFunctional() async throws {
        let sandbox = try IsolatedTempSandbox()
        defer { sandbox.cleanup() }
        
        let inputDir = sandbox.fileURL(named: "small_files_in")
        try TestFileGenerator.createBatchSmallFiles(in: inputDir, count: 10, sizePerFileInKB: 2)
        
        let outArchive = sandbox.fileURL(named: "tiny_test.zip").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: outArchive,
            format: .zip,
            level: .normal,
            inputPaths: [inputDir.path]
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
    }
}
