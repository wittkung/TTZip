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
        return ttzip_lzfse_is_available()
    }
    
    /// Decompresses a raw memory buffer using native C LZFSE with thread-local scratch arena.
    @inline(__always)
    public func decompress(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int
    ) -> Int {
        guard srcLength > 0 && dstCapacity > 0 else { return 0 }
        return ttzip_lzfse_decompress(src, srcLength, dst, dstCapacity)
    }
    
    /// Compresses a raw memory buffer using native C LZFSE with thread-local scratch arena.
    @inline(__always)
    public func compress(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int
    ) -> Int {
        guard srcLength > 0 && dstCapacity > 0 else { return 0 }
        return ttzip_lzfse_compress(src, srcLength, dst, dstCapacity)
    }
    
    /// Decompresses a single DMG / AAR block buffer.
    @inline(__always)
    public func decompressBlock(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int
    ) -> Int {
        guard srcLength > 0 && dstCapacity > 0 else { return 0 }
        return ttzip_lzfse_decompress_block(src, srcLength, dst, dstCapacity)
    }
    
    /// Decompresses a `.lzfse` file to a target destination path using streaming micro-buffering.
    public func decompressFileStream(srcPath: String, dstPath: String) -> Int32 {
        return CUnsafeBufferAdapter.withCString(srcPath) { cSrc in
            CUnsafeBufferAdapter.withCString(dstPath) { cDst in
                guard let cSrc = cSrc, let cDst = cDst else { return Int32(TTZIP_ERR_INVALID_PARAM.rawValue) }
                return Int32(ttzip_lzfse_decompress_file_stream(cSrc, cDst))
            }
        }
    }
    
    /// Compresses a source file to a `.lzfse` target path using streaming micro-buffering.
    public func compressFileStream(srcPath: String, dstPath: String) -> Int32 {
        return CUnsafeBufferAdapter.withCString(srcPath) { cSrc in
            CUnsafeBufferAdapter.withCString(dstPath) { cDst in
                guard let cSrc = cSrc, let cDst = cDst else { return Int32(TTZIP_ERR_INVALID_PARAM.rawValue) }
                return Int32(ttzip_lzfse_compress_file_stream(cSrc, cDst))
            }
        }
    }
}
