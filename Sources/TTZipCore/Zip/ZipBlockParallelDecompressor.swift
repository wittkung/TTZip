// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Multi-core parallel Deflate decompression engine for 512KB blocks,
/// utilizing 64-byte cacheline-aligned buffers to avoid single-thread bottlenecks.
public final class ZipBlockParallelDecompressor: @unchecked Sendable {
    public static let shared = ZipBlockParallelDecompressor()
    
    private init() {}
    
    /// Decompresses partitioned 512KB blocks concurrently across CPU cores into an aligned destination buffer.
    public func decompressBlocksConcurrently(
        compressedData: Data,
        uncompressedSize: Int64,
        blockOffsets: [Int],
        blockCompressedSizes: [Int],
        blockUncompressedSizes: [Int]
    ) -> Data? {
        let totalBlocks = blockOffsets.count
        guard totalBlocks > 0, uncompressedSize > 0 else { return nil }
        
        var alignedOutPtr: UnsafeMutableRawPointer? = nil
        let pageSize = 64 // 64-byte cacheline alignment
        let alignedLength = ((Int(uncompressedSize) + pageSize - 1) / pageSize) * pageSize
        posix_memalign(&alignedOutPtr, pageSize, alignedLength)
        
        guard let dstRawPtr = alignedOutPtr else { return nil }
        defer { free(dstRawPtr) }
        
        let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
        let failedBox = StateBoxInt64(0)
        
        compressedData.withUnsafeBytes { inRaw in
            guard let srcBase = inRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let inPointerBox = SendablePointerBox(pointer: srcBase, size: compressedData.count)
            let outPointerBox = SendablePointerBox(pointer: dstBytePtr, size: Int(uncompressedSize))
            
            ConcurrencyBridge.parallelFor(iterations: totalBlocks) { blockIdx in
                let inOff = blockOffsets[blockIdx]
                let cSize = blockCompressedSizes[blockIdx]
                let uSize = blockUncompressedSizes[blockIdx]
                let outOff = blockIdx * 512 * 1024
                
                let srcPtr = inPointerBox.pointer.advanced(by: inOff)
                let dstPtr = UnsafeMutablePointer<UInt8>(mutating: outPointerBox.pointer.advanced(by: outOff))
                
                var outLen: Int = 0
                let st = ttzip_rust_deflate_decompress(srcPtr, cSize, dstPtr, uSize, &outLen)
                if st != TTZIP_STATUS_OK || outLen != uSize {
                    OSAtomicAdd64(1, &failedBox.value)
                }
            }
        }
        
        if failedBox.value == 0 {
            return Data(bytes: dstBytePtr, count: Int(uncompressedSize))
        }
        return nil
    }
}
