// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import XCTest
@testable import TTZipCore

final class DirectoryScanPerformanceTests: XCTestCase {
    
    func test1kNodesDirectoryScanPerformance() throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] == "1" ||
              ProcessInfo.processInfo.environment["TTZIP_RUN_STRESS_BENCHMARKS"] == "1" else {
            // Fast functional scan test in standard mode
            let sandbox = try IsolatedTempSandbox()
            defer { sandbox.cleanup() }
            
            let inputDir = sandbox.fileURL(named: "scan_test_dir")
            try TestFileGenerator.createBatchSmallFiles(in: inputDir, count: 20, sizePerFileInKB: 1)
            
            let items = ZipDirectoryScanner.scan(inputPaths: [inputDir.path], skipMacJunk: false)
            XCTAssertGreaterThanOrEqual(items.count, 20)
            return
        }
        
        let profile = MicroCorpusProfile(
            profileId: "bench-1k",
            fileCount: 1000,
            minFileSizeBytes: 1024,
            maxFileSizeBytes: 4096,
            jsonRatio: 0.5,
            logRatio: 0.5,
            highEntropyRatio: 0.0,
            maxDirectoryDepth: 3,
            directoryFanout: 8
        )
        let generator = HyperCompressCorpusGenerator(profile: profile)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let start = CACurrentMediaTime()
        let items = ZipDirectoryScanner.scan(inputPaths: [generated.rootURL.path], skipMacJunk: false)
        let elapsedMs = (CACurrentMediaTime() - start) * 1000.0
        
        XCTAssertGreaterThanOrEqual(items.count, 1000, "扫描条目数必须 >= 1,000")
        #if DEBUG
        XCTAssertLessThanOrEqual(elapsedMs, 50.0, "1,000 节点遍历耗时必须 <= 50.0 ms (Debug 容限)")
        #else
        XCTAssertLessThanOrEqual(elapsedMs, 10.0, "1,000 节点遍历耗时必须 <= 10.0 ms (Release 门禁)")
        #endif
    }
}
