// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge
import Darwin

/// Test suite verifying LZFSE streaming memory usage boundaries and decompression throughput floors.
final class DMGLZFSEStreamingMemoryGateTests: XCTestCase {
    
    /// Queries the current task's resident memory size in megabytes via Mach kernel APIs.
    /// - Returns: Resident set size (RSS) in megabytes.
    private func getResidentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        }
        return 0.0
    }
    
    /// Tests LZFSE streaming memory consumption ceiling and verifies throughput meets the performance floor.
    func testLZFSEStreamingMemoryAndThroughputFloor() throws {
        let adapter = LzfseCAdapter.shared
        XCTAssertTrue(adapter.isAvailable)
        
        let initialRSS = getResidentMemoryMB()
        let blockSize = 1024 * 1024 // 1MB block
        let iterations = 100 // 100MB streaming simulation
        
        var original = [UInt8](repeating: 0, count: blockSize)
        for i in 0..<blockSize {
            original[i] = UInt8((i ^ (i >> 3)) & 0xFF)
        }
        
        let compCap = blockSize + 65536
        var compressed = [UInt8](repeating: 0, count: compCap)
        let compSize = adapter.compress(src: original, srcLength: blockSize, dst: &compressed, dstCapacity: compCap)
        XCTAssertGreaterThan(compSize, 0)
        
        var decompressed = [UInt8](repeating: 0, count: blockSize)
        
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            let decompSize = adapter.decompress(
                src: compressed,
                srcLength: compSize,
                dst: &decompressed,
                dstCapacity: blockSize
            )
            XCTAssertEqual(decompSize, blockSize)
        }
        let elapsed = max(0.0001, CFAbsoluteTimeGetCurrent() - start)
        let totalMB = Double(blockSize * iterations) / (1024.0 * 1024.0)
        let throughputMBs = totalMB / elapsed
        let peakRSS = getResidentMemoryMB()
        
        TTLogger.debug("[DMGLZFSEStreamingMemoryGateTests] Total: \(totalMB) MB, Elapsed: \(String(format: "%.3f", elapsed))s, Throughput: \(String(format: "%.2f", throughputMBs)) MB/s, RSS: \(String(format: "%.2f", peakRSS)) MB (Initial: \(String(format: "%.2f", initialRSS)) MB)")
        
        // Assertions
        XCTAssertGreaterThanOrEqual(throughputMBs, 500.0, "LZFSE decompression throughput must meet baseline floor")
        XCTAssertLessThanOrEqual(peakRSS - initialRSS, 64.0, "Peak RSS growth must be within 64MB floor")
    }
}
