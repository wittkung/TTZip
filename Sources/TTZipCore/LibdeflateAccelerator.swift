// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance DEFLATE compression and decompression acceleration infrastructure.
public final class LibdeflateAccelerator: @unchecked Sendable {
    public static let shared = LibdeflateAccelerator()
    
    private init() {}
    
    /// Thread-local pooled DEFLATE compression with zero per-file allocations.
    public func compress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int,
        level: Int = 6
    ) -> Int {
        return LibdeflateCAdapter.shared.compress(src: src, srcSize: srcSize, dst: dst, dstCapacity: dstCapacity, level: level)
    }
    
    /// Thread-local pooled DEFLATE decompression with zero per-file allocations.
    public func decompress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int
    ) -> Int {
        return LibdeflateCAdapter.shared.decompress(src: src, srcSize: srcSize, dst: dst, dstCapacity: dstCapacity)
    }
    
    /// Convenience helper compressing Swift `Data` buffers.
    public func compressData(_ data: Data, level: Int = 6) -> Data? {
        return LibdeflateCAdapter.shared.compressData(data, level: level)
    }
    
    /// Convenience helper decompressing Swift `Data` buffers.
    public func decompressData(_ data: Data, originalSize: Int) -> Data? {
        return LibdeflateCAdapter.shared.decompressData(data, originalSize: originalSize)
    }
}
