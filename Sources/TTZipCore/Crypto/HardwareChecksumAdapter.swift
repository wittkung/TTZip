// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 硬件级 Adler-32 与 CRC-32 高性能校验和适配器
public enum HardwareChecksumAdapter {
    
    /// 计算 Adler-32 校验和（直通 ARM64 DotProd / NEON 向量化延迟取模实现）
    /// - Parameters:
    ///   - data: 待校验数据
    ///   - initial: 初始 Adler-32 值 (默认 1)
    /// - Returns: 计算后的 32-bit Adler-32 校验和
    @inlinable
    public static func adler32(for data: Data, initial: UInt32 = 1) -> UInt32 {
        guard !data.isEmpty else { return initial }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return initial
            }
            return ttzip_adler32_fast(initial, baseAddress, rawBuffer.count)
        }
    }
    
    /// 计算 Adler-32 校验和（内存指针直通版）
    @inlinable
    public static func adler32(ptr: UnsafePointer<UInt8>, count: Int, initial: UInt32 = 1) -> UInt32 {
        guard count > 0 else { return initial }
        return ttzip_adler32_fast(initial, ptr, count)
    }

    /// 计算 CRC-32 校验和（直通 libdeflate PMULL 宽折叠硬件加速）
    /// - Parameters:
    ///   - data: 待校验数据
    ///   - initial: 初始 CRC-32 值 (默认 0)
    /// - Returns: 计算后的 32-bit CRC-32 校验和
    @inlinable
    public static func crc32(for data: Data, initial: UInt32 = 0) -> UInt32 {
        guard !data.isEmpty else { return initial }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return initial
            }
            return ttzip_crc32_fast(initial, baseAddress, rawBuffer.count)
        }
    }

    /// 计算 CRC-32 校验和（内存指针直通版）
    @inlinable
    public static func crc32(ptr: UnsafePointer<UInt8>, count: Int, initial: UInt32 = 0) -> UInt32 {
        guard count > 0 else { return initial }
        return ttzip_crc32_fast(initial, ptr, count)
    }
}
