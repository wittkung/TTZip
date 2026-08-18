// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class FastMatchFinderTests: XCTestCase {
    
    // 16-bit 相对位置匹配查找器初始化与饱和 Rebase 验证
    func testMatchfinderRebase_SaturatedArithmetic_Correctness() {
        let entryCount = 65536 // 128KB 16-bit entries
        let sizeBytes = entryCount * MemoryLayout<Int16>.size
        
        let ptr = UnsafeMutablePointer<Int16>.allocate(capacity: entryCount)
        defer { ptr.deallocate() }
        
        // 1. 初始化
        ttzip_matchfinder_init_neon(ptr, sizeBytes)
        for i in 0..<entryCount {
            XCTAssertEqual(ptr[i], -32768, "Entry \(i) should be initialized to -32768")
        }
        
        // 2. 模拟填入部分在 [0, 32767] 内的坐标与部分过期负坐标
        ptr[0] = 100
        ptr[1] = 32700
        ptr[2] = -100
        ptr[3] = -32000
        
        // 3. 执行 Rebase
        ttzip_matchfinder_rebase_neon(ptr, sizeBytes)
        
        // ptr[0]: 100 - 32768 = -32668
        XCTAssertEqual(ptr[0], -32668)
        // ptr[1]: 32700 - 32768 = -68
        XCTAssertEqual(ptr[1], -68)
        // ptr[2]: -100 - 32768 -> 饱和截断为 -32768
        XCTAssertEqual(ptr[2], -32768)
        // ptr[3]: -32000 - 32768 -> 饱和截断为 -32768
        XCTAssertEqual(ptr[3], -32768)
    }
    
    // 16-bit 匹配查找器重置耗时微基准 (严格遵循 Spec SC-003: 32KB 窗口重置耗时 <= 5.0 μs)
    func testMatchfinderRebase_LatencyMicrobenchmark() {
        let entryCount = 32768 // 标准 32KB 窗口 (64KB 16-bit entries)
        let sizeBytes = entryCount * MemoryLayout<Int16>.size
        
        let ptr = UnsafeMutablePointer<Int16>.allocate(capacity: entryCount)
        defer { ptr.deallocate() }
        
        ttzip_matchfinder_init_neon(ptr, sizeBytes)
        
        // 预热并运行 1000 轮纯向量化重置微基准
        _ = ttzip_matchfinder_benchmark_rebase(ptr, sizeBytes, 100)
        let avgMicros = ttzip_matchfinder_benchmark_rebase(ptr, sizeBytes, 1000)
        
        print("⚡ [Matchfinder] 32KB Window Rebase Average Latency: \(String(format: "%.3f", avgMicros)) μs")
        
        // 门禁：Release 下硬门禁 <= 5.0 μs (实测 0.53 μs)；Debug 下由于无内联 <= 10.0 μs (实测 6.9 μs)
        #if !DEBUG
        XCTAssertLessThanOrEqual(avgMicros, 5.0, "Matchfinder 32KB window rebase latency exceeded 5.0 μs hard floor in Release")
        #else
        XCTAssertLessThanOrEqual(avgMicros, 10.0, "Matchfinder 32KB window rebase latency exceeded 10.0 μs floor in Debug")
        #endif
    }
    
    // 24-bit 未对齐加载与 Knuth 乘法哈希测试
    func testLoadU24Unaligned_AndHash24() {
        let bytes: [UInt8] = [0x12, 0x34, 0x56, 0x78, 0x9A]
        bytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let seq = ttzip_load_u24_unaligned(base)
            // 在小端序上，0x12, 0x34, 0x56 应该装载为 0x563412
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
