import Foundation
import CTTZipBridge

/// 7z 多固实块 (Multi-Solid Blocks) 全核并发 LZMA2/Zstd 解压调度器
public final class SevenZipBlockParallelDecompressor: @unchecked Sendable {
    public static let shared = SevenZipBlockParallelDecompressor()
    
    private init() {}
    
    /// 将划分好 independent 4GB 固实块分发至全核 CPU 并行解码
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
                
                // 64 字节 Cache Line 物理对齐内存 Buffer
                var alignedOutPtr: UnsafeMutableRawPointer? = nil
                let pageSize = 64
                let alignedLength = ((uSize + pageSize - 1) / pageSize) * pageSize
                posix_memalign(&alignedOutPtr, pageSize, alignedLength)
                
                guard let dstRawPtr = alignedOutPtr else { return }
                let dstBytePtr = dstRawPtr.assumingMemoryBound(to: UInt8.self)
                
                // 优先尝试 Quantum 两阶段 128KB 物理 Block 极速矢量解压 (RLE + Thread-Local libdeflate)
                let decompSize = ttzip_quantum_decompress_two_pass(srcPtr, cSize, dstBytePtr, uSize)
                var actualSize = (decompSize == uSize) ? uSize : 0
                if decompSize != uSize {
                    let appleDecomp = ttzip_zstd_decompress(srcPtr, cSize, dstBytePtr, uSize)
                    if appleDecomp == 0 {
                        OSAtomicCompareAndSwap32Barrier(1, 0, flagPtr)
                    } else {
                        actualSize = appleDecomp
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
