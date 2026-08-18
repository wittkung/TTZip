// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class VirtualMultiBlockArenaTests: XCTestCase {

    func testArenaAllocationAndAppending() {
        guard let arena = VirtualMultiBlockArena(capacity: 1024 * 1024) else {
            XCTFail("Failed to allocate 1MB arena")
            return
        }

        let chunkA = [UInt8](repeating: 0x41, count: 1000)
        let chunkB = [UInt8](repeating: 0x42, count: 2000)

        let blockA = arena.appendBlock(name: "fileA.txt", data: chunkA, length: chunkA.count)
        XCTAssertNotNil(blockA)
        XCTAssertEqual(blockA?.offset, 0)
        XCTAssertEqual(blockA?.length, 1000)

        let blockB = arena.appendBlock(name: "fileB.txt", data: chunkB, length: chunkB.count)
        XCTAssertNotNil(blockB)
        XCTAssertEqual(blockB?.offset, 1000)
        XCTAssertEqual(blockB?.length, 2000)

        XCTAssertEqual(arena.currentOffset, 3000)
        XCTAssertEqual(arena.blocks.count, 2)

        // Verify memory contents
        let base = arena.basePointer
        XCTAssertEqual(base[0], 0x41)
        XCTAssertEqual(base[999], 0x41)
        XCTAssertEqual(base[1000], 0x42)
        XCTAssertEqual(base[2999], 0x42)

        // Reset
        arena.reset()
        XCTAssertEqual(arena.currentOffset, 0)
        XCTAssertEqual(arena.blocks.count, 0)
    }
}
