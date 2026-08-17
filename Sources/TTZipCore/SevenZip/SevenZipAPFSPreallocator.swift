import CTTZipBridge

/// 针对 7z 文件提取的 APFS 物理 Extent 预分配器
public final class SevenZipAPFSPreallocator: @unchecked Sendable {
    public static let shared = SevenZipAPFSPreallocator()
    
    private init() {}
    
    @discardableResult
    public func preallocateFileExtent(fd: Int32, targetSize: Int64) -> Bool {
        return ttzip_apfs_preallocate(fd, targetSize) == 0
    }
}
