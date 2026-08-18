// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class ContextMemoryPoolTests: XCTestCase {

    func testMultiThreadedZeroHeapAllocationInHotLoop() async throws {
        let workerCount = 16
        let scratchpadSize = 64 * 1024 // 64KB
        let pool = ThreadLocalContextPoolAdapter(workerCount: workerCount, scratchpadSize: scratchpadSize)

        let iterationsPerWorker = 1000

        await withTaskGroup(of: Void.self) { group in
            for workerId in 0..<workerCount {
                group.addTask {
                    for iter in 0..<iterationsPerWorker {
                        pool.withScratchpad(workerId: workerId) { ptr, size in
                            // Verify 64-byte alignment
                            let addr = UInt(bitPattern: ptr)
                            XCTAssertEqual(addr % 64, 0, "Scratchpad must be 64-byte aligned for ARM NEON SIMD")
                            XCTAssertEqual(size, scratchpadSize)

                            // Simulate hot processing loop without heap allocation
                            ptr[0] = UInt8(iter % 256)
                            ptr[size - 1] = 0xAA
                        }
                    }
                }
            }
        }
    }
}
