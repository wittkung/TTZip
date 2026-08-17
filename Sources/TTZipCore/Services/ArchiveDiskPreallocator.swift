import Foundation
import CTTZipBridge

/// 跨格式通用 APFS 物理磁盘预分配与文件系统优化服务
/// 在任意归档格式 (ZIP, 7z, Zstd 等) 执行解压落盘或压缩包写盘前，提前一次性锁定 APFS 连续簇空间，
/// 彻底消除文件扩展写入过程中的 POSIX 锁瓶颈与磁盘碎片化。
public struct ArchiveDiskPreallocator: Sendable {
    public init() {}
    
    /// 对打开的文件描述符执行 APFS 空间预分配
    @discardableResult
    public static func preallocate(fileDescriptor: Int32, targetSizeBytes: Int64) -> Bool {
        guard fileDescriptor >= 0, targetSizeBytes > 0 else { return false }
        return ttzip_apfs_preallocate(fileDescriptor, targetSizeBytes) == 0
    }
    
    /// 对指定物理路径执行 APFS 空间预分配
    @discardableResult
    public static func preallocate(atPath path: String, targetSizeBytes: Int64) -> Bool {
        guard targetSizeBytes > 0 else { return false }
        let fd = open(path, O_RDWR | O_CREAT, 0644)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return preallocate(fileDescriptor: fd, targetSizeBytes: targetSizeBytes)
    }
    
    /// 执行 APFS 块级 COW (Copy-on-Write) 零拷贝扩展克隆
    @discardableResult
    public static func cloneRange(sourceFd: Int32, sourceOffset: Int64 = 0, targetFd: Int32, targetOffset: Int64 = 0, countBytes: UInt64) -> Bool {
        guard sourceFd >= 0, targetFd >= 0, countBytes > 0 else { return false }
        return ttzip_apfs_clone_range(sourceFd, sourceOffset, targetFd, targetOffset, countBytes) == 0
    }
}
