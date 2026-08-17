import Foundation

/// 针对 7z 解压释放的 NVMe Direct I/O 页对齐直写落盘引擎
public final class SevenZipDirectIOWriter: @unchecked Sendable {
    public static let shared = SevenZipDirectIOWriter()
    
    private init() {}
    
    public func writeDirect(filePath: String, data: Data, expectedSize: Int64) -> Bool {
        let fd = open(filePath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if fd < 0 { return false }
        defer { close(fd) }
        
        // 结合系统 Page Cache 与 APFS 空间预分配打满 RAM/NVMe 总线吞吐
        SevenZipAPFSPreallocator.shared.preallocateFileExtent(fd: fd, targetSize: expectedSize)
        if data.isEmpty { return true }
        
        var pageAlignedPtr: UnsafeMutableRawPointer? = nil
        let pageSize = 4096
        let alignedLength = ((data.count + pageSize - 1) / pageSize) * pageSize
        
        posix_memalign(&pageAlignedPtr, pageSize, alignedLength)
        guard let dstPtr = pageAlignedPtr else { return false }
        defer { free(dstPtr) }
        
        data.copyBytes(to: dstPtr.assumingMemoryBound(to: UInt8.self), count: data.count)
        let written = write(fd, dstPtr, data.count)
        return written == data.count
    }
}
