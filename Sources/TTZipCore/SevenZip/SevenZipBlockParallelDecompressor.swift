// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Multi-solid block concurrent LZMA2/Zstd decompressor scheduler.
public final class SevenZipBlockParallelDecompressor: @unchecked Sendable {
    public static let shared = SevenZipBlockParallelDecompressor()
    
    private init() {}
    
    /// Dispatches independent solid blocks across CPU cores for concurrent decompression.
    public func decompressSolidBlocksConcurrently(
        blocks: [(offset: Int64, compressedSize: Int64, uncompressedSize: Int64)],
        archiveBytePtr: UnsafePointer<UInt8>,
        archiveFileSize: Int,
        outputDir: String
    ) -> Bool {
        guard !blocks.isEmpty else { return false }
        
        let pointerBox = SendablePointerBox(pointer: archiveBytePtr, size: archiveFileSize)
        var successFlag: Int32 = 1
        
        withUnsafeMutablePointer(to: &successFlag) { flagPtr in
            DispatchQueue.concurrentPerform(iterations: blocks.count) { blockIdx in
                let block = blocks[blockIdx]
                let srcOffset = Int(block.offset)
                let cSize = Int(block.compressedSize)
                let uSize = Int(block.uncompressedSize)
                
                if srcOffset + cSize > pointerBox.size { return }
                let srcPtr = pointerBox.pointer.advanced(by: srcOffset)
                
                // 64-byte cache line aligned buffer
                var alignedOutPtr: UnsafeMutableRawPointer? = nil
                let pageSize = 64
                let alignedLength = ((uSize + pageSize - 1) / pageSize) * pageSize
                posix_memalign(&alignedOutPtr, pageSize, alignedLength)
                
                guard let dstRawPtr = alignedOutPtr else { return }
                let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
                
                // Two-pass block decompression fallback
                let decompSize = ttzip_quantum_decompress_two_pass(srcPtr, cSize, dstBytePtr, uSize)
                var actualSize = (decompSize == uSize) ? uSize : 0
                if decompSize != uSize {
                    let zstdDecomp = ttzip_zstd_decompress(srcPtr, cSize, dstBytePtr, uSize)
                    if zstdDecomp == 0 {
                        OSAtomicCompareAndSwap32Barrier(1, 0, flagPtr)
                    } else {
                        actualSize = zstdDecomp
                    }
                }
                
                if actualSize > 0 && !outputDir.isEmpty {
                    let blockFile = (outputDir as NSString).appendingPathComponent(String(format: "solid_block_%04d.tmp", blockIdx))
                    let outFd = open(blockFile, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o644)
                    if outFd >= 0 {
                        _ = write(outFd, dstBytePtr, actualSize)
                        close(outFd)
                    }
                }
                
                free(dstRawPtr)
            }
        }
        
        return successFlag == 1
    }
}
