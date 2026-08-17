import CTTZipBridge

/// macOS APFS 写时复制 (CoW) 预分配与 B-Tree 锁竞争消除工具类
public final class ZipAPFSPreallocator: @unchecked Sendable {
    public static let shared = ZipAPFSPreallocator()
    
    private init() {}
    
    /// 在物理文件创建前，通过 C 语言底层系统调用显式预分配连续磁盘 Block 簇
    @discardableResult
    public func preallocateFileExtent(fd: Int32, targetSize: Int64) -> Bool {
        return ttzip_apfs_preallocate(fd, targetSize) == 0
    }
}
