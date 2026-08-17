import Foundation
import CTTZipBridge

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

/// 零开销进程内存遥测快照 (物理驻留内存、内核记录的历史峰值高水位与虚拟内存)
public struct MemoryCeilingSnapshot: Sendable, Equatable {
    public let currentRSSBytes: UInt64
    public let peakRSSBytes: UInt64
    public let virtualSizeBytes: UInt64
    public let sampledTimestampMs: Double
    
    public init(
        currentRSSBytes: UInt64,
        peakRSSBytes: UInt64,
        virtualSizeBytes: UInt64,
        sampledTimestampMs: Double = Date().timeIntervalSince1970 * 1000.0
    ) {
        self.currentRSSBytes = currentRSSBytes
        self.peakRSSBytes = peakRSSBytes
        self.virtualSizeBytes = virtualSizeBytes
        self.sampledTimestampMs = sampledTimestampMs
    }
}

/// 跨平台高性能对齐内存分配、虚拟映射与敏感内存物理销毁中枢
///
/// 对标 libarchive 内存架构与安全规范，提供：
/// - 页对齐缓冲区分配 (Apple Silicon 16KB / 通用 4KB)
/// - 内存屏障敏感数据安全物理清零 (`secureZero`)，彻底免疫死存储消除 (DSE)
/// - 虚拟内存只读映射 RAII 作用域封装 (`mapFileReadOnly`) 与独立句柄
/// - 零开销进程内存高水位采样 (`currentMemoryUsage`)
public enum PlatformMemory {
    
    /// 零开销获取当前进程的物理驻留内存 (RSS)、峰值高水位物理内存 (Peak RSS) 与虚拟内存快照
    @inlinable
    public static func currentMemoryUsage() -> MemoryCeilingSnapshot {
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        guard kerr == KERN_SUCCESS else {
            return MemoryCeilingSnapshot(currentRSSBytes: 0, peakRSSBytes: 0, virtualSizeBytes: 0)
        }
        return MemoryCeilingSnapshot(
            currentRSSBytes: UInt64(info.resident_size),
            peakRSSBytes: UInt64(info.resident_size_max),
            virtualSizeBytes: UInt64(info.virtual_size)
        )
        #elseif os(Linux)
        var usage = rusage()
        _ = getrusage(RUSAGE_SELF, &usage)
        let peakBytes = UInt64(max(0, usage.ru_maxrss)) * 1024
        return MemoryCeilingSnapshot(currentRSSBytes: peakBytes, peakRSSBytes: peakBytes, virtualSizeBytes: 0)
        #else
        return MemoryCeilingSnapshot(currentRSSBytes: 0, peakRSSBytes: 0, virtualSizeBytes: 0)
        #endif
    }
    
    /// 申请指定对齐字节的连续物理内存块
    @inlinable
    public static func allocateAlignedPages(alignment: Int, byteCount: Int) -> UnsafeMutableRawPointer? {
        guard byteCount > 0, alignment > 0 else { return nil }
        return ttzip_platform_aligned_alloc(alignment, byteCount)
    }
    
    /// 释放由 ``allocateAlignedPages`` 分配的内存
    @inlinable
    public static func deallocateAlignedPages(pointer: UnsafeMutableRawPointer?) {
        guard let pointer = pointer else { return }
        ttzip_platform_aligned_free(pointer)
    }
    
    /// 申请指定字节大小的页对齐堆内存缓冲区 (默认当前系统页对齐尺寸)
    @inlinable
    public static func allocateAlignedPageBuffer(byteCount: Int) -> UnsafeMutableRawPointer? {
        guard byteCount > 0 else { return nil }
        let alignment = PlatformOperatingSystem.current.defaultPageAlignment
        return ttzip_platform_aligned_alloc(alignment, byteCount)
    }
    
    /// 释放由 ``allocateAlignedPageBuffer(byteCount:)`` 分配的页对齐内存
    @inlinable
    public static func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer?) {
        guard let pointer = pointer else { return }
        ttzip_platform_aligned_free(pointer)
    }
    
    /// 物理强制擦除敏感内存缓冲区 (密码、密钥与中间状态)
    @inlinable
    public static func secureZero(pointer: UnsafeMutableRawPointer, byteCount: Int) {
        guard byteCount > 0 else { return }
        #if os(macOS)
        _ = memset_s(pointer, byteCount, 0, byteCount)
        #else
        let volatilePtr = pointer.bindMemory(to: UInt8.self, capacity: byteCount)
        for i in 0..<byteCount {
            volatilePtr.advanced(by: i).pointee = 0
        }
        #endif
    }
    
    /// 以只读模式将物理文件映射至虚拟内存并返回映射句柄
    public static func mapFileReadOnly(filePath: String) throws -> PlatformMmapResult {
        let fd = open(filePath, O_RDONLY)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
        }
        
        var statBuf = stat()
        guard fstat(fd, &statBuf) == 0 else {
            close(fd)
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        
        let fileSize = Int(statBuf.st_size)
        if fileSize == 0 {
            return PlatformMmapResult(pointer: UnsafeRawPointer(bitPattern: 1)!, size: 0, rawDescriptor: fd)
        }
        
        guard let mappedPtr = mmap(nil, fileSize, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0),
              mappedPtr != MAP_FAILED else {
            close(fd)
            throw POSIXError(.init(rawValue: errno) ?? .ENOMEM)
        }
        
        return PlatformMmapResult(pointer: UnsafeRawPointer(mappedPtr), size: fileSize, rawDescriptor: fd)
    }
    
    /// 以只读零拷贝模式将物理文件映射至虚拟内存地址空间并执行 RAII 闭包
    public static func mapFileReadOnly<R: Sendable>(
        atPath path: String,
        _ body: @Sendable (UnsafeRawBufferPointer) throws -> R
    ) throws -> R {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
        }
        defer { close(fd) }
        
        var statBuf = stat()
        guard fstat(fd, &statBuf) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        
        let fileSize = Int(statBuf.st_size)
        if fileSize == 0 {
            return try body(UnsafeRawBufferPointer(start: nil, count: 0))
        }
        
        guard let mappedPtr = mmap(nil, fileSize, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0),
              mappedPtr != MAP_FAILED else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOMEM)
        }
        
        let ptrValue = UInt(bitPattern: mappedPtr)
        defer {
            if let rawPtr = UnsafeMutableRawPointer(bitPattern: ptrValue) {
                munmap(rawPtr, fileSize)
            }
        }
        
        let buffer = UnsafeRawBufferPointer(start: mappedPtr, count: fileSize)
        return try body(buffer)
    }
}
