// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: libdeflate high-throughput C engine adapter.
///
/// Bridges `libdeflate_deflate_compress` and `ttzip_libdeflate_*` C functions
/// with memory-safe `Data` and `UnsafeRawPointer` Swift interfaces with thread-local pooling.
public final class LibdeflateCAdapter: LibdeflateEngineProtocol, Sendable {
    public static let shared = LibdeflateCAdapter()
    
    private init() {}
    
    /// Executes high-throughput raw pointer Deflate compression with thread-local state recycling.
    /// - Parameters:
    ///   - src: Pointer to uncompressed source bytes.
    ///   - srcSize: Uncompressed byte count.
    ///   - dst: Pointer to output destination buffer.
    ///   - dstCapacity: Allocated capacity of destination buffer.
    ///   - level: Compression level (1 to 12).
    /// - Returns: Number of compressed bytes written, or 0 on failure.
    public func compress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int,
        level: Int = 6
    ) -> Int {
        return ttzip_libdeflate_compress(src, srcSize, dst, dstCapacity, Int32(level))
    }
    
    /// Executes high-throughput raw pointer Deflate decompression with thread-local state recycling.
    /// - Parameters:
    ///   - src: Pointer to compressed source bytes.
    ///   - srcSize: Compressed byte count.
    ///   - dst: Pointer to uncompressed output destination buffer.
    ///   - dstCapacity: Expected capacity of destination buffer.
    /// - Returns: Number of decompressed bytes written, or 0 on failure.
    public func decompress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int
    ) -> Int {
        return ttzip_libdeflate_decompress(src, srcSize, dst, dstCapacity)
    }
    
    /// Convenience interface: memory-safe Deflate compression using buffer flyweights.
    /// - Parameters:
    ///   - data: Input payload Data.
    ///   - level: Deflate compression level.
    /// - Returns: Compressed Data, or `nil` on failure.
    public func compressData(_ data: Data, level: Int = 6) -> Data? {
        guard !data.isEmpty else { return Data() }
        let maxBound = data.count + (data.count >> 3) + 128
        let pageSize: MemoryPageSize = maxBound > 4096 ? .page64K : .page4K
        
        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= maxBound else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxBound)
                let written = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    ttzip_libdeflate_compress(srcPtr, count, uninitPtr, maxBound, Int32(level))
                }
                guard written > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: written, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }
            let written = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                ttzip_libdeflate_compress(srcPtr, count, dstPtr, capacity, Int32(level))
            }
            guard written > 0 else { return nil }
            return Data(bytes: dstPtr, count: written)
        }
    }
    
    /// Convenience interface: memory-safe Deflate decompression using buffer flyweights.
    /// - Parameters:
    ///   - data: Input compressed payload Data.
    ///   - originalSize: Expected uncompressed byte count.
    /// - Returns: Decompressed Data, or `nil` on failure.
    public func decompressData(_ data: Data, originalSize: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        let pageSize: MemoryPageSize = originalSize > 4096 ? .page64K : .page4K
        
        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= originalSize else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
                let actual = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    ttzip_libdeflate_decompress(srcPtr, count, uninitPtr, originalSize)
                }
                guard actual == originalSize else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: actual, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }
            let actual = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                ttzip_libdeflate_decompress(srcPtr, count, dstPtr, capacity)
            }
            guard actual == originalSize else { return nil }
            return Data(bytes: dstPtr, count: actual)
        }
    }
    
    /// Creates a 1MB chunked multi-threaded streaming writer for large files (> 256MB).
    /// - Parameters:
    ///   - outFd: File descriptor to write compressed chunks into.
    ///   - level: Compression level.
    /// - Returns: `ChunkedDeflateStreamWriter` instance, or `nil` on initialization error.
    public func createChunkedWriter(outFd: Int32, level: Int = 6) -> ChunkedDeflateStreamWriter? {
        return ChunkedDeflateStreamWriter(outFd: outFd, level: level)
    }
}
