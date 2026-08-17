import Foundation

/// 基于 ARC / RAII 的只读虚拟内存映射句柄 (Swift 6 严格 Sendable 零拷贝)
public final class MmapBufferHandle: @unchecked Sendable {
    
    /// 底层只读内存基地址
    public let baseAddress: UnsafeRawPointer
    
    /// 映射区域总字节大小
    public let count: Int
    
    /// 底层文件描述符 (若持有 ownership 则在 deinit 中由 RAII 关闭)
    public let fileDescriptor: Int32
    public let ownsFileDescriptor: Bool
    
    /// 快速获取强类型连续字节只读缓冲区 (零堆分配)
    @inline(__always)
    public var bytes: UnsafeBufferPointer<UInt8> {
        UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: count)
    }
    
    /// 快速获取原始字节只读缓冲区
    @inline(__always)
    public var rawBuffer: UnsafeRawBufferPointer {
        UnsafeRawBufferPointer(start: baseAddress, count: count)
    }
    
    /// 安全子区域视图提取 (带边界防御，零拷贝返回指针)
    @inline(__always)
    public func slice(offset: Int, length: Int) -> UnsafeBufferPointer<UInt8>? {
        guard offset >= 0, length >= 0, offset + length <= count else { return nil }
        guard let base = bytes.baseAddress else { return nil }
        return UnsafeBufferPointer(start: base.advanced(by: offset), count: length)
    }

    /// 硬件级页缓存建议 (madvise)
    @inline(__always)
    public func advise(_ advice: Int32) {
        if count > 0 {
            posix_madvise(UnsafeMutableRawPointer(mutating: baseAddress), count, advice)
        }
    }

    /// 工厂方法：打开并以只读方式映射文件路径
    public static func mapReadOnly(
        path: String,
        advice: Int32 = POSIX_MADV_SEQUENTIAL
    ) throws -> MmapBufferHandle {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        
        var st = stat()
        guard fstat(fd, &st) == 0 else {
            let err = errno
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: err) ?? .EIO)
        }
        
        let fileSize = size_t(st.st_size)
        guard fileSize > 0 else {
            close(fd)
            throw POSIXError(.EINVAL)
        }
        
        guard let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED else {
            let err = errno
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: err) ?? .ENOMEM)
        }
        
        let handle = MmapBufferHandle(
            baseAddress: UnsafeRawPointer(mapped),
            count: fileSize,
            fileDescriptor: fd,
            ownsFileDescriptor: true
        )
        
        if advice != 0 {
            handle.advise(advice)
        }
        
        return handle
    }

    /// 工厂方法：基于已有文件描述符映射只读区域
    public static func mapReadOnly(
        fd: Int32,
        size: Int,
        advice: Int32 = POSIX_MADV_SEQUENTIAL,
        ownsFileDescriptor: Bool = false
    ) throws -> MmapBufferHandle {
        guard fd >= 0, size > 0 else {
            throw POSIXError(.EINVAL)
        }
        
        guard let mapped = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .ENOMEM)
        }
        
        let handle = MmapBufferHandle(
            baseAddress: UnsafeRawPointer(mapped),
            count: size,
            fileDescriptor: fd,
            ownsFileDescriptor: ownsFileDescriptor
        )
        
        if advice != 0 {
            handle.advise(advice)
        }
        
        return handle
    }

    public init(baseAddress: UnsafeRawPointer, count: Int, fileDescriptor: Int32, ownsFileDescriptor: Bool) {
        self.baseAddress = baseAddress
        self.count = count
        self.fileDescriptor = fileDescriptor
        self.ownsFileDescriptor = ownsFileDescriptor
    }
    
    /// RAII 确定性物理内存解映射与句柄释放
    deinit {
        if count > 0 {
            munmap(UnsafeMutableRawPointer(mutating: baseAddress), count)
        }
        if ownsFileDescriptor && fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }
}
