import Foundation
import CTTZipBridge

/// libdeflate 原生 C 引擎适配器 (Adapter Pattern)
/// 将 libdeflate_deflate_compress 与 ttzip_libdeflate_* 适配为内存安全的 Data / RawPointer Swift 接口
public final class LibdeflateCAdapter: LibdeflateEngineProtocol, Sendable {
    public static let shared = LibdeflateCAdapter()
    
    private init() {}
    
    /// 执行 Thread-Local 复用池的高吞吐 RawPointer Deflate 压缩
    public func compress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int,
        level: Int = 6
    ) -> Int {
        return ttzip_libdeflate_compress(src, srcSize, dst, dstCapacity, Int32(level))
    }
    
    /// 执行 Thread-Local 复用池的高吞吐 RawPointer Deflate 解压
    public func decompress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int
    ) -> Int {
        return ttzip_libdeflate_decompress(src, srcSize, dst, dstCapacity)
    }
    
    /// Data 快捷包装接口：类型安全且零内存泄漏 Deflate 压缩 (享元模式 Buffer 复用)
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
    
    /// Data 快捷包装接口：类型安全且零内存泄漏 Deflate 解压 (享元模式 Buffer 复用)
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
    
    /// 创建面向超大单文件 (> 256MB) 的 1MB 分块流式多线程写入器
    public func createChunkedWriter(outFd: Int32, level: Int = 6) -> ChunkedDeflateStreamWriter? {
        return ChunkedDeflateStreamWriter(outFd: outFd, level: level)
    }
}
