// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class AccelerationInfrastructureTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AccelInfra_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    /// 1. Apple LZFSE C
    func testAppleLZFSERoundtrip() throws {
        XCTAssertTrue(ttzip_lzfse_is_available(), "Apple LZFSE library must be available on macOS")
        
        let sampleText = "Apple Silicon Native LZFSE Hardware Acceleration Payload Stream Test 2026 " + String(repeating: "TTZip High Throughput ", count: 100)
        let sampleData = sampleText.data(using: .utf8)!
        
        let srcFile = (tempDirPath as NSString).appendingPathComponent("lzfse_src.bin")
        let compFile = (tempDirPath as NSString).appendingPathComponent("lzfse_compressed.bin")
        let decompFile = (tempDirPath as NSString).appendingPathComponent("lzfse_decompressed.bin")
        
        try sampleData.write(to: URL(fileURLWithPath: srcFile))
        
        // Verify expected invariant
        let compStatus = ttzip_lzfse_compress_file_stream(srcFile, compFile)
        XCTAssertEqual(compStatus, 0, "LZFSE file stream compression must return TTZIP_OK")
        XCTAssertTrue(FileManager.default.fileExists(atPath: compFile))
        
        // Verify expected invariant
        let decompStatus = ttzip_lzfse_decompress_file_stream(compFile, decompFile)
        XCTAssertEqual(decompStatus, 0, "LZFSE file stream decompression must return TTZIP_OK")
        
        let restoredText = try String(contentsOfFile: decompFile, encoding: .utf8)
        XCTAssertEqual(restoredText, sampleText, "LZFSE decompressed payload must match original exactly")
    }
    
    /// 2. UnRAR C
    func testUnRAREngineAvailability() {
        let inspectRes = ttzip_unrar_inspect_entry_count("/non_existent_file.rar")
        XCTAssertEqual(inspectRes, -1, "Inspecting non-existent RAR file should return -1 gracefully")
    }
}
