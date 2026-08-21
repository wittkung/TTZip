// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Block-level parallel Deflate compression engine for large in-memory buffers and large single files.
public final class ZipBlockParallelCompressor: @unchecked Sendable {
    public static let shared = ZipBlockParallelCompressor()
    
    private init() {}
    
    public static let blockSize: Int = 512 * 1024 // 512 KB block partition
    
    public struct ParallelBlockResult: Sendable {
        public let compressedData: Data
        public let rawSize: Int
    }
    
    /// Partitions an in-memory buffer into 512KB chunks and compresses them concurrently across CPU cores.
    public func compressBlocksConcurrently(data: Data, level: Int32 = 6) -> Data {
        guard data.count > ZipBlockParallelCompressor.blockSize else {
            // Small data fallback to single-block compression
            var outBuf = Data(count: data.count + 512)
            let outCap = outBuf.count
            let compSize = data.withUnsafeBytes { inPtr -> Int in
                guard let src = inPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return outBuf.withUnsafeMutableBytes { outPtr -> Int in
                    guard let dst = outPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    var outLen: Int = 0
                    let st = ttzip_rust_deflate_compress(src, data.count, dst, outCap, level, &outLen)
                    return st == TTZIP_STATUS_OK ? outLen : 0
                }
            }
            return compSize > 0 && compSize < data.count ? outBuf.prefix(compSize) : data
        }
        
        let totalBlocks = (data.count + ZipBlockParallelCompressor.blockSize - 1) / ZipBlockParallelCompressor.blockSize
        let blockResultsBox = StateBoxResults([Data?](repeating: nil, count: totalBlocks))
        
        data.withUnsafeBytes { rawIn in
            guard let baseAddr = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let ptrBox = SendablePointerBox(pointer: baseAddr, size: data.count)
            
            ConcurrencyBridge.parallelFor(iterations: totalBlocks) { blockIdx in
                let offset = blockIdx * ZipBlockParallelCompressor.blockSize
                let currentChunkSize = min(ZipBlockParallelCompressor.blockSize, ptrBox.size - offset)
                let chunkPtr = ptrBox.pointer.advanced(by: offset)
                
                var compressedBuf = Data(count: currentChunkSize + 512)
                let compCap = compressedBuf.count
                let compSize = compressedBuf.withUnsafeMutableBytes { outPtr -> Int in
                    guard let dst = outPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    var outLen: Int = 0
                    let st = ttzip_rust_deflate_compress(chunkPtr, currentChunkSize, dst, compCap, level, &outLen)
                    return st == TTZIP_STATUS_OK ? outLen : 0
                }
                
                if compSize > 0 && compSize < currentChunkSize {
                    blockResultsBox.set(idx: blockIdx, res: compressedBuf.prefix(compSize))
                } else {
                    blockResultsBox.set(idx: blockIdx, res: Data(bytes: chunkPtr, count: currentChunkSize))
                }
            }
        }
        
        var merged = Data()
        for idx in 0..<totalBlocks {
            if let bData = blockResultsBox.values[idx] {
                merged.append(bData)
            }
        }
        return merged
    }
}
