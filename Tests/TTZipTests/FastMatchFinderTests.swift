// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// Test suite validating NEON-accelerated fast matchfinder initialization, saturated rebase arithmetic, and latency microbenchmarks.
final class FastMatchFinderTests: XCTestCase {
    
    /// Verifies 16-bit relative matchfinder initialization and saturated rebase arithmetic correctness.
    func testMatchfinderRebase_SaturatedArithmetic_Correctness() {
        let entryCount = 65536 // 128KB 16-bit entries
        let sizeBytes = entryCount * MemoryLayout<Int16>.size
        
        let ptr = UnsafeMutablePointer<Int16>.allocate(capacity: entryCount)
        defer { ptr.deallocate() }
        
        // 1. Initialize table
        ttzip_matchfinder_init_neon(ptr, sizeBytes)
        for i in 0..<entryCount {
            XCTAssertEqual(ptr[i], -32768, "Entry \(i) should be initialized to -32768")
        }
        
        // 2. Populate entries with active and expired negative offsets
        ptr[0] = 100
        ptr[1] = 32700
        ptr[2] = -100
        ptr[3] = -32000
        
        // 3. Execute saturated rebase
        ttzip_matchfinder_rebase_neon(ptr, sizeBytes)
        
        // ptr[0]: 100 - 32768 = -32668
        XCTAssertEqual(ptr[0], -32668)
        // ptr[1]: 32700 - 32768 = -68
        XCTAssertEqual(ptr[1], -68)
        // ptr[2]: -100 - 32768 -> saturated truncation to -32768
        XCTAssertEqual(ptr[2], -32768)
        // ptr[3]: -32000 - 32768 -> saturated truncation to -32768
        XCTAssertEqual(ptr[3], -32768)
    }
    
    /// Measures matchfinder rebase latency microbenchmark against performance thresholds (32KB window reset latency <= 5.0 μs).
    func testMatchfinderRebase_LatencyMicrobenchmark() {
        let entryCount = 32768 // Standard 32KB window (64KB 16-bit entries)
        let sizeBytes = entryCount * MemoryLayout<Int16>.size
        
        let ptr = UnsafeMutablePointer<Int16>.allocate(capacity: entryCount)
        defer { ptr.deallocate() }
        
        ttzip_matchfinder_init_neon(ptr, sizeBytes)
        
        // Warmup and execute 1000 iterations of vectorized rebase benchmark
        _ = ttzip_matchfinder_benchmark_rebase(ptr, sizeBytes, 100)
        let avgMicros = ttzip_matchfinder_benchmark_rebase(ptr, sizeBytes, 1000)
        
        TTLogger.debug("⚡ [Matchfinder] 32KB Window Rebase Average Latency: \(String(format: "%.3f", avgMicros)) μs")
        
        // Performance floor: Release mode <= 5.0 μs; Debug mode <= 10.0 μs
        #if !DEBUG
        XCTAssertLessThanOrEqual(avgMicros, 5.0, "Matchfinder 32KB window rebase latency exceeded 5.0 μs hard floor in Release")
        #else
        XCTAssertLessThanOrEqual(avgMicros, 10.0, "Matchfinder 32KB window rebase latency exceeded 10.0 μs floor in Debug")
        #endif
    }
    
    /// Tests unaligned 24-bit integer loading and Knuth multiplicative hashing.
    func testLoadU24Unaligned_AndHash24() {
        let bytes: [UInt8] = [0x12, 0x34, 0x56, 0x78, 0x9A]
        bytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let seq = ttzip_load_u24_unaligned(base)
            // On little-endian architectures, 0x12, 0x34, 0x56 loads as 0x00563412
            #if !arch(arm) && !arch(arm64) && !arch(x86_64)
            // generic
            #else
            XCTAssertEqual(seq, 0x00563412)
            #endif
            
            let hash15 = ttzip_lz_hash24(seq, 15)
            XCTAssertLessThan(hash15, 32768)
        }
    }
}
