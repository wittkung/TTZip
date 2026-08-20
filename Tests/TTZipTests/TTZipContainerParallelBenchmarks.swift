// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class TTZipContainerParallelBenchmarks: XCTestCase {
    func testParallelBlockZipInMemoryThroughput() async throws {
        let pool = BenchmarkBufferPool(size: 1048576) // 1MB test chunk
        pool.prepareCorpus(.text)
        
        let rawData = Data(bytes: pool.inputBuffer, count: 1048576)
        
        // Chunk into 8 x 128KB parallel blocks
        let chunkSize = 131072
        let blockCount = 8
        var blocks: [Data] = []
        for i in 0..<blockCount {
            let chunk = rawData.subdata(in: (i * chunkSize)..<((i + 1) * chunkSize))
            blocks.append(chunk)
        }

        // Parallel compression with TaskGroup (Level 1 fast path)
        let startTime = PlatformMonotonicTimer.nowNanoseconds()
        let compressedBlocks = await withTaskGroup(of: (Int, Data?).self) { group in
            for (idx, block) in blocks.enumerated() {
                group.addTask {
                    let adapter = LibdeflateCAdapter.shared
                    let comp = adapter.compressData(block, level: 1)
                    return (idx, comp)
                }
            }
            var res = [(Int, Data?)]()
            for await item in group {
                res.append(item)
            }
            return res.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
        }

        let endTime = PlatformMonotonicTimer.nowNanoseconds()
        let durationMs = Double(endTime - startTime) / 1_000_000.0
        let totalUncompressedMB = 1.0 // 1MB
        let throughputMBs = (totalUncompressedMB / (durationMs / 1000.0))

        XCTAssertEqual(compressedBlocks.count, blockCount)
        print(String(format: "⚡️ Multi-Core Parallel Block Deflate (L1) Throughput: %.1f MB/s in %.2f ms", throughputMBs, durationMs))
        XCTAssertGreaterThan(throughputMBs, 500.0)
    }
}
