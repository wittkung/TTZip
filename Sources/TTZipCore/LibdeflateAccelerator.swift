import Foundation
import CTTZipBridge

/// 统一通用 libdeflate 全格式底层加速基础设施 (Universal Core Deflate Accelerator)
/// 覆盖 ZIP、GZ、TAR.GZ、7Z、CBZ、EPUB 等全格式编解码与 NEON 矢量加速
public final class LibdeflateAccelerator: @unchecked Sendable {
    public static let shared = LibdeflateAccelerator()
    
    private init() {}
    
    /// 执行 Thread-Local 复用池的高吞吐 Deflate 压缩 (零内存分配)
    public func compress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int,
        level: Int = 6
    ) -> Int {
        return LibdeflateCAdapter.shared.compress(src: src, srcSize: srcSize, dst: dst, dstCapacity: dstCapacity, level: level)
    }
    
    /// 执行 Thread-Local 复用池的高吞吐 Deflate 解压 (零内存分配)
    public func decompress(
        src: UnsafeRawPointer,
        srcSize: Int,
        dst: UnsafeMutableRawPointer,
        dstCapacity: Int
    ) -> Int {
        return LibdeflateCAdapter.shared.decompress(src: src, srcSize: srcSize, dst: dst, dstCapacity: dstCapacity)
    }
    
    /// Data 快捷包装接口：零拷贝内存切片 Deflate 压缩
    public func compressData(_ data: Data, level: Int = 6) -> Data? {
        return LibdeflateCAdapter.shared.compressData(data, level: level)
    }
    
    /// Data 快捷包装接口：零拷贝内存切片 Deflate 解压
    public func decompressData(_ data: Data, originalSize: Int) -> Data? {
        return LibdeflateCAdapter.shared.decompressData(data, originalSize: originalSize)
    }
}
