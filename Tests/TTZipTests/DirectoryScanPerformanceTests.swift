// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

/// HyperCompressBench VFS (50,000 <= 250ms)
final class DirectoryScanPerformanceTests: XCTestCase {
    
    // MARK: - 1. 1,000 <= 10.0 ms
    
    func test1kNodesDirectoryScanPerformance() throws {
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
    
    // MARK: - 2. 10,000 <= 60.0 ms
    
    func test10kNodesDirectoryScanPerformance() throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] == "1" ||
              ProcessInfo.processInfo.environment["TTZIP_RUN_STRESS_BENCHMARKS"] == "1" else {
            return
        }
        
        let profile = MicroCorpusProfile(
            profileId: "bench-10k",
            fileCount: 10000,
            minFileSizeBytes: 512,
            maxFileSizeBytes: 2048,
            jsonRatio: 0.5,
            logRatio: 0.5,
            highEntropyRatio: 0.0,
            maxDirectoryDepth: 4,
            directoryFanout: 12
        )
        let generator = HyperCompressCorpusGenerator(profile: profile)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let start = CACurrentMediaTime()
        let items = ZipDirectoryScanner.scan(inputPaths: [generated.rootURL.path], skipMacJunk: false)
        let elapsedMs = (CACurrentMediaTime() - start) * 1000.0
        
        XCTAssertGreaterThanOrEqual(items.count, 10000, "扫描条目数必须 >= 10,000")
        #if DEBUG
        XCTAssertLessThanOrEqual(elapsedMs, 150.0, "10,000 节点遍历耗时必须 <= 150.0 ms (Debug 容限)")
        #else
        XCTAssertLessThanOrEqual(elapsedMs, 60.0, "10,000 节点遍历耗时必须 <= 60.0 ms (Release 门禁)")
        #endif
    }
    
    // MARK: - 3. 50,000 <= 250.0 ms, >= 200,000 items/s
    
    func test50kNodesDirectoryScanStressPerformance() throws {
        guard ProcessInfo.processInfo.environment["TTZIP_RUN_STRESS_BENCHMARKS"] == "1" else {
            return
        }
        
        let generator = HyperCompressCorpusGenerator(profile: .stress50k)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let start = CACurrentMediaTime()
        let items = ZipDirectoryScanner.scan(inputPaths: [generated.rootURL.path], skipMacJunk: false)
        let elapsed = CACurrentMediaTime() - start
        let elapsedMs = elapsed * 1000.0
        let itemsPerSec = Double(items.count) / elapsed
        
        XCTAssertGreaterThanOrEqual(items.count, 50000, "扫描条目数必须 >= 50,000")
        #if DEBUG
        XCTAssertLessThanOrEqual(elapsedMs, 600.0, "50,000 节点压力遍历耗时必须 <= 600.0 ms (Debug 容限)")
        #else
        XCTAssertLessThanOrEqual(elapsedMs, 250.0, "50,000 节点压力遍历耗时必须 <= 250.0 ms (Release 门禁)")
        XCTAssertGreaterThanOrEqual(itemsPerSec, 200000.0, "50,000 节点扫描吞吐速率必须 >= 200,000 items/s")
        #endif
    }
}
