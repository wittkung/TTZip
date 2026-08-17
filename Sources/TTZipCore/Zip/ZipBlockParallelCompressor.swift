import Foundation
import CTTZipBridge

/// 超大单文件块级并行 (Block-Level Parallelism) 极速 Deflate 压缩引擎
public final class ZipBlockParallelCompressor: @unchecked Sendable {
    public static let shared = ZipBlockParallelCompressor()
    
    private init() {}
    
    public static let blockSize: Int = 512 * 1024 // 512 KB Block 分块
    
    public struct ParallelBlockResult: Sendable {
        public let compressedData: Data
        public let rawSize: Int
    }
    
    /// 将单个超大内存 Buffer/文件划分为 512KB 分块并跨 CPU 全核并行压缩
    public func compressBlocksConcurrently(data: Data, level: Int32 = 6) -> Data {
        guard data.count > ZipBlockParallelCompressor.blockSize else {
            // 小文件直接单块压缩
            var outBuf = Data(count: data.count + 512)
            let outCap = outBuf.count
            let compSize = data.withUnsafeBytes { inPtr -> size_t in
                guard let src = inPtr.baseAddress else { return 0 }
                return outBuf.withUnsafeMutableBytes { outPtr -> size_t in
                    guard let dst = outPtr.baseAddress else { return 0 }
                    return ttzip_libdeflate_compress(src, data.count, dst, outCap, level)
                }
            }
            return compSize > 0 && compSize < data.count ? outBuf.prefix(compSize) : data
        }
        
        let totalBlocks = (data.count + ZipBlockParallelCompressor.blockSize - 1) / ZipBlockParallelCompressor.blockSize
        let blockResultsBox = StateBoxResults([Data?](repeating: nil, count: totalBlocks))
        
        data.withUnsafeBytes { rawIn in
            guard let baseAddr = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let ptrBox = SendablePointerBox(pointer: baseAddr, size: data.count)
            
            DispatchQueue.concurrentPerform(iterations: totalBlocks) { blockIdx in
                let offset = blockIdx * ZipBlockParallelCompressor.blockSize
                let currentChunkSize = min(ZipBlockParallelCompressor.blockSize, ptrBox.size - offset)
                let chunkPtr = ptrBox.pointer.advanced(by: offset)
                
                var compressedBuf = Data(count: currentChunkSize + 512)
                let compCap = compressedBuf.count
                let compSize = compressedBuf.withUnsafeMutableBytes { outPtr -> size_t in
                    guard let dst = outPtr.baseAddress else { return 0 }
                    return ttzip_libdeflate_compress(chunkPtr, currentChunkSize, dst, compCap, level)
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
