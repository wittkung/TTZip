// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: Zero-Overhead RFC 1950 (ZLIB) and RFC 1952 (GZIP) Container Fast Engine.
///
/// Direct in-place framing with fused hardware-vectorized CRC-32/Adler-32 checksums.
public enum FastContainerEngine {

    // MARK: - GZIP Container API

    /// Compresses uncompressed payload into GZIP container (RFC 1952) with zero intermediate copies.
    /// - Parameters:
    ///   - data: Input uncompressed data.
    ///   - level: Deflate compression level (1 to 12).
    /// - Returns: GZIP container bytes, or `nil` on failure.
    public static func compressGzip(_ data: Data, level: Int = 6) -> Data? {
        guard !data.isEmpty else {
            var emptyGzip = [UInt8](repeating: 0, count: 64)
            var written: Int = 0
            let status = ttzip_rust_gzip_compress([UInt8](), 0, &emptyGzip, emptyGzip.count, Int32(level), &written)
            guard status == TTZIP_STATUS_OK && written > 0 else { return nil }
            return Data(emptyGzip.prefix(written))
        }

        let maxBound = data.count + (data.count >> 3) + 128
        let pageSize: MemoryPageSize = maxBound > 4096 ? .page64K : .page4K

        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= maxBound else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxBound)
                var written: Int = 0
                let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    ttzip_rust_gzip_compress(srcPtr, count, uninitPtr, maxBound, Int32(level), &written)
                }
                guard status == TTZIP_STATUS_OK && written > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: written, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }

            var written: Int = 0
            let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                ttzip_rust_gzip_compress(srcPtr, count, dstPtr, capacity, Int32(level), &written)
            }
            guard status == TTZIP_STATUS_OK && written > 0 else { return nil }
            return Data(bytes: dstPtr, count: written)
        }
    }

    /// Decompresses GZIP container into original raw payload.
    /// - Parameters:
    ///   - data: GZIP container data.
    ///   - expectedSize: Expected uncompressed size (if known, or 0 for dynamic sizing).
    /// - Returns: Decompressed uncompressed data, or `nil` on failure.
    public static func decompressGzip(_ data: Data, expectedSize: Int) -> Data? {
        guard data.count >= 10 else { return nil }

        let targetSize = expectedSize > 0 ? expectedSize : (data.count * 4 + 1024)
        let pageSize: MemoryPageSize = targetSize > 4096 ? .page64K : .page4K

        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= targetSize else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: targetSize)
                var actual: Int = 0
                let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    ttzip_rust_gzip_decompress(srcPtr, count, uninitPtr, targetSize, &actual)
                }
                guard status == TTZIP_STATUS_OK && actual > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: actual, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }

            var actual: Int = 0
            let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                ttzip_rust_gzip_decompress(srcPtr, count, dstPtr, capacity, &actual)
            }
            guard status == TTZIP_STATUS_OK && actual > 0 else { return nil }
            return Data(bytes: dstPtr, count: actual)
        }
    }

    // MARK: - ZLIB Container API

    /// Compresses uncompressed payload into ZLIB container (RFC 1950) with zero intermediate copies.
    /// - Parameters:
    ///   - data: Input uncompressed data.
    ///   - level: Deflate compression level (1 to 12).
    /// - Returns: ZLIB container bytes, or `nil` on failure.
    public static func compressZlib(_ data: Data, level: Int = 6) -> Data? {
        guard !data.isEmpty else {
            var emptyZlib = [UInt8](repeating: 0, count: 64)
            var written: Int = 0
            let status = ttzip_rust_zlib_compress([UInt8](), 0, &emptyZlib, emptyZlib.count, Int32(level), &written)
            guard status == TTZIP_STATUS_OK && written > 0 else { return nil }
            return Data(emptyZlib.prefix(written))
        }

        let maxBound = data.count + (data.count >> 3) + 128
        let pageSize: MemoryPageSize = maxBound > 4096 ? .page64K : .page4K

        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= maxBound else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxBound)
                var written: Int = 0
                let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    ttzip_rust_zlib_compress(srcPtr, count, uninitPtr, maxBound, Int32(level), &written)
                }
                guard status == TTZIP_STATUS_OK && written > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: written, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }

            var written: Int = 0
            let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                ttzip_rust_zlib_compress(srcPtr, count, dstPtr, capacity, Int32(level), &written)
            }
            guard status == TTZIP_STATUS_OK && written > 0 else { return nil }
            return Data(bytes: dstPtr, count: written)
        }
    }

    /// Decompresses ZLIB container into original raw payload.
    /// - Parameters:
    ///   - data: ZLIB container data.
    ///   - expectedSize: Expected uncompressed size.
    /// - Returns: Decompressed uncompressed data, or `nil` on failure.
    public static func decompressZlib(_ data: Data, expectedSize: Int) -> Data? {
        guard data.count >= 6 else { return nil }

        let targetSize = expectedSize > 0 ? expectedSize : (data.count * 4 + 1024)
        let pageSize: MemoryPageSize = targetSize > 4096 ? .page64K : .page4K

        return MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
            guard capacity >= targetSize else {
                let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: targetSize)
                var actual: Int = 0
                let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                    ttzip_rust_zlib_decompress(srcPtr, count, uninitPtr, targetSize, &actual)
                }
                guard status == TTZIP_STATUS_OK && actual > 0 else {
                    uninitPtr.deallocate()
                    return nil
                }
                return Data(bytesNoCopy: uninitPtr, count: actual, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
            }

            var actual: Int = 0
            let status = CUnsafeBufferAdapter.withBufferPointer(data) { srcPtr, count in
                ttzip_rust_zlib_decompress(srcPtr, count, dstPtr, capacity, &actual)
            }
            guard status == TTZIP_STATUS_OK && actual > 0 else { return nil }
            return Data(bytes: dstPtr, count: actual)
        }
    }
}
