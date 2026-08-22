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
        var outLen: Int = 0
        let status = ttzip_rust_deflate_compress(
            src.assumingMemoryBound(to: UInt8.self),
            srcSize,
            dst.assumingMemoryBound(to: UInt8.self),
            dstCapacity,
            Int32(level),
            &outLen
        )
        return status == TTZIP_STATUS_OK ? outLen : 0
    }
    
    /// Thread-local pooled DEFLATE decompression with zero per-file allocations.
    public func decompress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int
    ) -> Int {
        var outLen: Int = 0
        let status = ttzip_rust_deflate_decompress(
            src.assumingMemoryBound(to: UInt8.self),
            srcSize,
            dst.assumingMemoryBound(to: UInt8.self),
            dstCapacity,
            &outLen
        )
        return status == TTZIP_STATUS_OK ? outLen : 0
    }
    
    /// Convenience helper compressing Swift `Data` buffers.
    public func compressData(_ data: Data, level: Int = 6) -> Data? {
        guard !data.isEmpty else { return Data() }
        let maxBound = ttzip_rust_deflate_compress_bound(data.count, Int32(level))
        let pageSize: MemoryPageSize = maxBound > 4096 ? .page64K : .page4K
        
        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= maxBound else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxBound)
                let written = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    self.compress(src: srcPtr, srcSize: count, dst: uninitPtr, dstCapacity: maxBound, level: level)
                }
                guard written > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: written, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }
            let written = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                self.compress(src: srcPtr, srcSize: count, dst: dstPtr, dstCapacity: capacity, level: level)
            }
            guard written > 0 else { return nil }
            return Data(bytes: dstPtr, count: written)
        }
    }
    
    /// Convenience helper decompressing Swift `Data` buffers.
    public func decompressData(_ data: Data, originalSize: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        let pageSize: MemoryPageSize = originalSize > 4096 ? .page64K : .page4K
        
        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= originalSize else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
                let actual = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    self.decompress(src: srcPtr, srcSize: count, dst: uninitPtr, dstCapacity: originalSize)
                }
                guard actual == originalSize else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: actual, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }
            let actual = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                self.decompress(src: srcPtr, srcSize: count, dst: dstPtr, dstCapacity: capacity)
            }
            guard actual == originalSize else { return nil }
            return Data(bytes: dstPtr, count: actual)
        }
    }
}
