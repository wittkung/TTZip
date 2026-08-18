// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class PlatformMemoryTests: XCTestCase {
    
    func testAlignedPagesAllocationAndDeallocation() {
        let size = 65536 // 64KB
        let alignment = 16384 // 16KB
        
        let ptr = PlatformMemory.allocateAlignedPages(alignment: alignment, byteCount: size)
        XCTAssertNotNil(ptr)
        
        if let raw = ptr {
            let addr = UInt(bitPattern: raw)
            XCTAssertEqual(addr % UInt(alignment), 0, "内存首地址必须满足 16KB 对齐")
            
            // Verify expected invariant
            raw.assumingMemoryBound(to: UInt8.self).initialize(repeating: 0x5A, count: size)
            XCTAssertEqual(raw.assumingMemoryBound(to: UInt8.self)[0], 0x5A)
            
            // Verify expected invariant
            PlatformMemory.secureZero(pointer: raw, byteCount: size)
            XCTAssertEqual(raw.assumingMemoryBound(to: UInt8.self)[0], 0x00)
            XCTAssertEqual(raw.assumingMemoryBound(to: UInt8.self)[size - 1], 0x00)
            
            PlatformMemory.deallocateAlignedPages(pointer: raw)
        }
    }
    
    func testMapFileReadOnlyLifecycle() throws {
        let fm = FileManager.default
        let tempURL = fm.temporaryDirectory.appendingPathComponent("pal_mmap_test_\(UUID().uuidString).bin")
        let sampleData = Data(repeating: 0xEE, count: 32768)
        try sampleData.write(to: tempURL)
        defer { try? fm.removeItem(at: tempURL) }
        
        let mmapResult = try PlatformMemory.mapFileReadOnly(filePath: tempURL.path)
        XCTAssertEqual(mmapResult.size, 32768)
        let firstByte = mmapResult.pointer.assumingMemoryBound(to: UInt8.self).pointee
        XCTAssertEqual(firstByte, 0xEE)
        
        // Verify expected invariant
        mmapResult.unmap()
    }
}
