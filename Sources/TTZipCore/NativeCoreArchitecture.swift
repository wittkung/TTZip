import Foundation
import CTTZipBridge

/// 统一跨格式 Apple Silicon 原生 C 语言加速基座 (CTTZipCoreArchitecture Swift 门面)
public final class NativeCoreArchitecture: @unchecked Sendable {
    public static let shared = NativeCoreArchitecture()
    private init() {}
    
    /// 触发 APFS 簇级空间物理预分配 (彻底消除格式无关的盘块碎片与文件膨胀锁)
    @discardableResult
    public func preallocateFileExtent(fileDescriptor: Int32, targetSizeBytes: Int64) -> Bool {
        return ttzip_core_apfs_preallocate_file(fileDescriptor, targetSizeBytes) == 0
    }
    
    /// 调度 ARM64 NEON 矢量硬件加速计算 CRC32
    public func computeFastCRC32(buffer: UnsafeRawPointer, length: Int) -> UInt32 {
        return ttzip_core_crc32_neon_single(0, buffer.assumingMemoryBound(to: UInt8.self), length)
    }
    
    /// 分配 Apple Silicon 16KB 物理页界限对齐内存块
    public func allocateAlignedPageBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: capacity)
    }

    public static func allocateAlignedPageBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: capacity)
    }

    /// 释放对齐内存块 (闭环内存分配与释放成对对称契约)
    public func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer) {
        CUnsafeBufferAdapter.deallocateAlignedBuffer(pointer)
    }

    public static func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer) {
        CUnsafeBufferAdapter.deallocateAlignedBuffer(pointer)
    }
    
    /// 执行零 Pipe /dev/null 高优先级 POSIX 子进程调度
    public func spawnProcessFast(binaryPath: String, arguments: [String], workingDirectory: String? = nil) -> Int32 {
        return (try? POSIXTarCAdapter.shared.spawnProcess(binaryPath: binaryPath, arguments: arguments, workingDirectory: workingDirectory)) ?? -1
    }
}
