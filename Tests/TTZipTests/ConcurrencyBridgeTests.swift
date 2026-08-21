// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class ConcurrencyBridgeTests: XCTestCase {

    func testParallelForZeroCount() {
        var called = false
        ConcurrencyBridge.parallelFor(count: 0) { _ in
            called = true
        }
        XCTAssertFalse(called, "Count 0 must be an immediate no-op")
    }

    func testParallelForSingleIteration() {
        var result = -1
        ConcurrencyBridge.parallelFor(count: 1) { idx in
            result = idx
        }
        XCTAssertEqual(result, 0, "Count 1 must execute synchronously for index 0")
    }

    func testParallelForMultiIterationCorrectness() {
        let count = 1000
        let array = UnsafeMutablePointer<Int32>.allocate(capacity: count)
        array.initialize(repeating: 0, count: count)
        defer {
            array.deinitialize(count: count)
            array.deallocate()
        }

        ConcurrencyBridge.parallelFor(iterations: count) { idx in
            array[idx] = Int32(idx * 2)
        }

        for i in 0..<count {
            XCTAssertEqual(array[i], Int32(i * 2), "Index \(i) mismatch in parallel for")
        }
    }

    func testThreadBudgetQueries() {
        let optimal = ConcurrencyBridge.ThreadBudget.optimalThreadCount()
        XCTAssertGreaterThan(optimal, 0, "Optimal thread count must be positive")
    }

    func testMemoryBudgetQueries() {
        let safe = ConcurrencyBridge.MemoryBudget.safeBudget
        XCTAssertGreaterThan(safe, 1024 * 1024, "Safe budget must be greater than 1MB")

        let clamped = ConcurrencyBridge.MemoryBudget.clamp(desiredBytes: 1024, minBytes: 4096, maxBytes: 8192)
        XCTAssertEqual(clamped, 4096, "Clamp must enforce minimum boundary")
    }
}
