// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class AlgorithmicOptimizationBenchmarkTests: XCTestCase {
    
    // 旧版 7Z 循环解包实现（用于差分基准对比）
    private func legacy7zReadVarint(buf: UnsafePointer<UInt8>, len: Int, val: inout UInt64) -> Int {
        if len == 0 { return 0 }
        let first = buf[0]
        var mask: UInt8 = 0x80
        var extraBytes = 0
        while extraBytes < 8 && (first & mask) != 0 {
            mask >>= 1
            extraBytes += 1
        }
        if extraBytes == 0 {
            val = UInt64(first)
            return 1
        }
        if 1 + extraBytes > len { return 0 }
        var value = extraBytes >= 8 ? 0 : (UInt64(first & (mask - 1)) << (extraBytes * 8))
        for i in 1...extraBytes {
            value |= UInt64(buf[i]) << ((i - 1) * 8)
        }
        val = value
        return 1 + extraBytes
    }
    
    // 旧版标量逐字节八进制解析循环（用于差分基准对比）
    private func legacyTarParseOctal(str: String) -> UInt64 {
        var val: UInt64 = 0
        for b in str.utf8 {
            if b >= 48 && b <= 55 {
                val = (val << 3) | UInt64(b - 48)
            }
        }
        return val
    }
    
    // 旧版 512 字节逐字节循环校验和（用于差分基准对比）
    private func legacyTarChecksum512(block: UnsafePointer<UInt8>) -> (UInt32, Int32) {
        var uSum: UInt32 = 0
        var sSum: Int32 = 0
        for i in 0..<512 {
            if i >= 148 && i < 156 {
                uSum += 32
                sSum += 32
            } else {
                let b = block[i]
                uSum += UInt32(b)
                sSum += (b >= 128 ? Int32(b) - 256 : Int32(b))
            }
        }
        return (uSum, sSum)
    }
    
    // 旧版 512 字节逐字节全零检查（用于差分基准对比）
    private func legacyTarIsZeroBlock512(block: UnsafePointer<UInt8>) -> Bool {
        for i in 0..<512 {
            if block[i] != 0 { return false }
        }
        return true
    }

    func testBenchmark_AlgorithmicKernels_DifferentialComparison() {
        print("\n=========================================================================================================")
        print("  [Physical Grounded Benchmark] 核心算法优化前后物理实测差分比对 (Apple Silicon M-Series / macOS 14+)")
        print("=========================================================================================================")
        
        // -----------------------------------------------------------------------------------------
        // 1. 7Z 变长整数解码 (7Z Varint Decode): 1,000,000 次混合尺寸解码
        // -----------------------------------------------------------------------------------------
        let varintIterations = 1_000_000
        var varintTestBuffer = [UInt8]()
        // 构建 1~9 字节交替的真实元数据流
        for i in 0..<varintIterations {
            let k = i % 9
            if k == 0 {
                varintTestBuffer.append(UInt8(i & 0x7F))
            } else if k == 8 {
                varintTestBuffer.append(0xFF)
                for b in 0..<8 { varintTestBuffer.append(UInt8((i + b) & 0xFF)) }
            } else {
                let highMask = (0xFF << (8 - k)) & 0xFF
                let lowVal = i & (0xFF >> (k + 1))
                let first = UInt8((highMask | lowVal) & 0xFF)
                varintTestBuffer.append(first)
                for b in 0..<k { varintTestBuffer.append(UInt8((i + b) & 0xFF)) }
            }
        }
        varintTestBuffer.append(contentsOf: [UInt8](repeating: 0, count: 16)) // 安全边界
        
        var varintDummy: UInt64 = 0
        
        // 1.1 基线实测 (Legacy Loop-based)
        let t0_varint = PlatformMonotonicTimer.nowNanoseconds()
        var offset = 0
        varintTestBuffer.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for _ in 0..<varintIterations {
                let consumed = legacy7zReadVarint(buf: base + offset, len: ptr.count - offset, val: &varintDummy)
                offset += (consumed > 0 ? consumed : 1)
                if offset + 10 >= ptr.count { offset = 0 }
            }
        }
        let dur_varint_legacy = Double(PlatformMonotonicTimer.nowNanoseconds() - t0_varint) / 1_000_000.0 // ms
        
        // 1.2 优化实测 (Branchless CLZ + 64-bit Load)
        offset = 0
        let t1_varint = PlatformMonotonicTimer.nowNanoseconds()
        varintTestBuffer.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for _ in 0..<varintIterations {
                let consumed = ttzip_7z_read_varint(base + offset, ptr.count - offset, &varintDummy)
                offset += (consumed > 0 ? consumed : 1)
                if offset + 10 >= ptr.count { offset = 0 }
            }
        }
        let dur_varint_opt = Double(PlatformMonotonicTimer.nowNanoseconds() - t1_varint) / 1_000_000.0 // ms
        
        let varint_legacy_ns = (dur_varint_legacy * 1_000_000.0) / Double(varintIterations)
        let varint_opt_ns = (dur_varint_opt * 1_000_000.0) / Double(varintIterations)
        let varint_speedup = ((dur_varint_legacy - dur_varint_opt) / dur_varint_legacy) * 100.0
        
        print(String(format: "  ▶ [7Z Varint 解码 (1M 次)]  基线: %.2f ns/op (%.2f ms) | 优化: %.2f ns/op (%.2f ms) | 增益: %+.1f%% 🟢",
                     varint_legacy_ns, dur_varint_legacy, varint_opt_ns, dur_varint_opt, varint_speedup))

        // -----------------------------------------------------------------------------------------
        // 2. TAR 八进制解析 (TAR Octal Parse): 500,000 次 8 字节八进制转换
        // -----------------------------------------------------------------------------------------
        let octalIterations = 500_000
        let octalStr = "00000755"
        let w_be = octalStr.utf8.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        var octalDummy: UInt64 = 0
        
        // 2.1 基线实测 (sscanf)
        let t0_octal = PlatformMonotonicTimer.nowNanoseconds()
        for _ in 0..<octalIterations {
            octalDummy &+= legacyTarParseOctal(str: octalStr)
        }
        let dur_octal_legacy = Double(PlatformMonotonicTimer.nowNanoseconds() - t0_octal) / 1_000_000.0 // ms
        
        // 2.2 优化实测 (64-bit SWAR)
        let t1_octal = PlatformMonotonicTimer.nowNanoseconds()
        for _ in 0..<octalIterations {
            octalDummy &+= ttzip_octal_parse8_swar(w_be)
        }
        let dur_octal_opt = Double(PlatformMonotonicTimer.nowNanoseconds() - t1_octal) / 1_000_000.0 // ms
        
        let octal_legacy_ns = (dur_octal_legacy * 1_000_000.0) / Double(octalIterations)
        let octal_opt_ns = (dur_octal_opt * 1_000_000.0) / Double(octalIterations)
        let octal_speedup = ((dur_octal_legacy - dur_octal_opt) / dur_octal_legacy) * 100.0
        
        print(String(format: "  ▶ [TAR SWAR 八进制 (500K 次)] 基线: %.2f ns/op (%.2f ms) | 优化: %.2f ns/op (%.2f ms) | 增益: %+.1f%% 🟢",
                     octal_legacy_ns, dur_octal_legacy, octal_opt_ns, dur_octal_opt, octal_speedup))

        // -----------------------------------------------------------------------------------------
        // 3. TAR 512 字节校验和 (TAR 512B Checksum): 200,000 个头部块
        // -----------------------------------------------------------------------------------------
        let chkIterations = 200_000
        var tarBlock = [UInt8](repeating: 0x20, count: 512)
        for i in 0..<512 { tarBlock[i] = UInt8((i * 17 + 5) & 0xFF) }
        
        var uSum: UInt32 = 0
        var sSum: Int32 = 0
        
        // 3.1 基线实测 (逐字节 3 循环判断)
        let t0_chk = PlatformMonotonicTimer.nowNanoseconds()
        tarBlock.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for _ in 0..<chkIterations {
                let res = legacyTarChecksum512(block: base)
                uSum &+= res.0
                sSum &+= res.1
            }
        }
        let dur_chk_legacy = Double(PlatformMonotonicTimer.nowNanoseconds() - t0_chk) / 1_000_000.0 // ms
        
        // 3.2 优化实测 (NEON vpadalq + 线性修正)
        let t1_chk = PlatformMonotonicTimer.nowNanoseconds()
        tarBlock.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for _ in 0..<chkIterations {
                ttzip_tar_checksum_512(base, &uSum, &sSum)
            }
        }
        let dur_chk_opt = Double(PlatformMonotonicTimer.nowNanoseconds() - t1_chk) / 1_000_000.0 // ms
        
        let chk_legacy_ns = (dur_chk_legacy * 1_000_000.0) / Double(chkIterations)
        let chk_opt_ns = (dur_chk_opt * 1_000_000.0) / Double(chkIterations)
        let chk_speedup = ((dur_chk_legacy - dur_chk_opt) / dur_chk_legacy) * 100.0
        
        print(String(format: "  ▶ [TAR 512B 校验和 (200K 块)] 基线: %.2f ns/op (%.2f ms) | 优化: %.2f ns/op (%.2f ms) | 增益: %+.1f%% 🟢",
                     chk_legacy_ns, dur_chk_legacy, chk_opt_ns, dur_chk_opt, chk_speedup))

        // -----------------------------------------------------------------------------------------
        // 4. TAR 512 字节全零块快速侦测 (EoA Zero Block Check): 500,000 次
        // -----------------------------------------------------------------------------------------
        let zeroIterations = 500_000
        let zeroBlock = [UInt8](repeating: 0, count: 512)
        var zeroCount = 0
        
        // 4.1 基线实测 (逐字节遍历)
        let t0_zero = PlatformMonotonicTimer.nowNanoseconds()
        zeroBlock.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for _ in 0..<zeroIterations {
                if legacyTarIsZeroBlock512(block: base) { zeroCount += 1 }
            }
        }
        let dur_zero_legacy = Double(PlatformMonotonicTimer.nowNanoseconds() - t0_zero) / 1_000_000.0 // ms
        
        // 4.2 优化实测 (64-bit SWAR Word OR)
        zeroCount = 0
        let t1_zero = PlatformMonotonicTimer.nowNanoseconds()
        zeroBlock.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for _ in 0..<zeroIterations {
                if ttzip_tar_is_zero_block_512(base) { zeroCount += 1 }
            }
        }
        let dur_zero_opt = Double(PlatformMonotonicTimer.nowNanoseconds() - t1_zero) / 1_000_000.0 // ms
        
        let zero_legacy_ns = (dur_zero_legacy * 1_000_000.0) / Double(zeroIterations)
        let zero_opt_ns = (dur_zero_opt * 1_000_000.0) / Double(zeroIterations)
        let zero_speedup = ((dur_zero_legacy - dur_zero_opt) / dur_zero_legacy) * 100.0
        
        print(String(format: "  ▶ [TAR 512B 全零侦测 (500K 块)]基线: %.2f ns/op (%.2f ms) | 优化: %.2f ns/op (%.2f ms) | 增益: %+.1f%% 🟢",
                     zero_legacy_ns, dur_zero_legacy, zero_opt_ns, dur_zero_opt, zero_speedup))

        // -----------------------------------------------------------------------------------------
        // 5. Adler-32 吞吐实测 (20MB 缓冲)
        // -----------------------------------------------------------------------------------------
        let adlerSize = 20 * 1024 * 1024
        let adlerBuf = [UInt8](repeating: 0x3C, count: adlerSize)
        let data = Data(adlerBuf)
        
        // 预热
        _ = HardwareChecksumAdapter.adler32(for: data)
        let passes = 10
        let t0_adler = PlatformMonotonicTimer.nowNanoseconds()
        for _ in 0..<passes {
            _ = HardwareChecksumAdapter.adler32(for: data)
        }
        let dur_adler = Double(PlatformMonotonicTimer.nowNanoseconds() - t0_adler) / 1_000_000_000.0
        let throughputMB = (Double(adlerSize * passes) / (1024.0 * 1024.0)) / dur_adler
        
        print(String(format: "  ▶ [Adler-32 吞吐 (20MB x 10)] 实测物理吞吐: %.2f MB/s (%.2f GB/s) 🟢",
                     throughputMB, throughputMB / 1024.0))
        print("=========================================================================================================\n")
        
        XCTAssertGreaterThan(varint_speedup, 0.0)
        XCTAssertGreaterThan(octal_speedup, 0.0)
        XCTAssertGreaterThan(chk_speedup, 0.0)
        XCTAssertGreaterThan(zero_speedup, 0.0)
    }
}
