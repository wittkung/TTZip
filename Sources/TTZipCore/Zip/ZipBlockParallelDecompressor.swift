import Foundation
import CTTZipBridge

/// 512KB 分块多核并发 Deflate 极速解压引擎 (消除单超大文件单线程解压瓶颈)
public final class ZipBlockParallelDecompressor: @unchecked Sendable {
    public static let shared = ZipBlockParallelDecompressor()
    
    private init() {}
    
    /// 将 512KB 分块并发由 CPU 全核同时解压至 64 字节缓存行对齐的 Buffer 中
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
        let pageSize = 64 // 64 字节 Cache Line 对齐
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
            
            DispatchQueue.concurrentPerform(iterations: totalBlocks) { blockIdx in
                let inOff = blockOffsets[blockIdx]
                let cSize = blockCompressedSizes[blockIdx]
                let uSize = blockUncompressedSizes[blockIdx]
                let outOff = blockIdx * 512 * 1024
                
                let srcPtr = inPointerBox.pointer.advanced(by: inOff)
                let dstPtr = UnsafeMutablePointer<UInt8>(mutating: outPointerBox.pointer.advanced(by: outOff))
                
                let decompSize = ttzip_libdeflate_decompress(srcPtr, cSize, dstPtr, uSize)
                if decompSize != uSize {
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
