// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Swift adapter for native static in-process LZFSE / LZVN codec.
public final class LzfseCAdapter: Sendable {
    public static let shared = LzfseCAdapter()
    
    private init() {}
    
    /// Checks if LZFSE static C engine is available.
    @inline(__always)
    public var isAvailable: Bool {
        return true
    }
    
    /// Decompresses a raw memory buffer using native LZFSE.
    @inline(__always)
    public func decompress(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int
    ) -> Int {
        guard srcLength > 0 && dstCapacity > 0 else { return 0 }
        var outLen: Int = 0
        let status = ttzip_rust_lzfse_decompress(src, srcLength, dst, dstCapacity, &outLen)
        return status == TTZIP_STATUS_OK ? outLen : 0
    }
    
    /// Compresses a raw memory buffer using native LZFSE.
    @inline(__always)
    public func compress(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int
    ) -> Int {
        guard srcLength > 0 && dstCapacity > 0 else { return 0 }
        var outLen: Int = 0
        let status = ttzip_rust_lzfse_compress(src, srcLength, dst, dstCapacity, &outLen)
        return status == TTZIP_STATUS_OK ? outLen : 0
    }
    
    /// Decompresses a single DMG / AAR block buffer.
    @inline(__always)
    public func decompressBlock(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int
    ) -> Int {
        return decompress(src: src, srcLength: srcLength, dst: dst, dstCapacity: dstCapacity)
    }
    
    /// Decompresses a `.lzfse` file to a target destination path.
    public func decompressFileStream(srcPath: String, dstPath: String) -> Int32 {
        guard let srcData = try? Data(contentsOf: URL(fileURLWithPath: srcPath)) else { return -1 }
        let cap = srcData.count * 4 + 64 * 1024
        var outBuf = [UInt8](repeating: 0, count: cap)
        let decSize = srcData.withUnsafeBytes { srcRaw in
            guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return outBuf.withUnsafeMutableBufferPointer { dstRaw in
                guard let dstPtr = dstRaw.baseAddress else { return 0 }
                return decompress(src: srcPtr, srcLength: srcData.count, dst: dstPtr, dstCapacity: cap)
            }
        }
        if decSize > 0 {
            let outData = Data(bytes: outBuf, count: decSize)
            try? outData.write(to: URL(fileURLWithPath: dstPath))
            return 0
        }
        return -1
    }
    
    /// Compresses a source file to a `.lzfse` target path.
    public func compressFileStream(srcPath: String, dstPath: String) -> Int32 {
        guard let srcData = try? Data(contentsOf: URL(fileURLWithPath: srcPath)) else { return -1 }
        let cap = srcData.count + 4096
        var outBuf = [UInt8](repeating: 0, count: cap)
        let compSize = srcData.withUnsafeBytes { srcRaw in
            guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return outBuf.withUnsafeMutableBufferPointer { dstRaw in
                guard let dstPtr = dstRaw.baseAddress else { return 0 }
                return compress(src: srcPtr, srcLength: srcData.count, dst: dstPtr, dstCapacity: cap)
            }
        }
        if compSize > 0 {
            let outData = Data(bytes: outBuf, count: compSize)
            try? outData.write(to: URL(fileURLWithPath: dstPath))
            return 0
        }
        return -1
    }
}
