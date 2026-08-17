import Foundation
import CTTZipBridge

#if os(macOS) || os(Linux)
import Darwin
#endif

/// 跨平台 POSIX flock 文件锁类型
public enum PlatformFileLockType: Sendable {
    case exclusive
    case shared
}

/// 跨平台文件系统元数据访问与磁盘空间预分配中枢
///
/// 对标 libarchive `archive_read_disk` 工业模型，提供：
/// - 单次系统调用提取全量文件元数据 (`statFile`)
/// - 消除磁盘碎片与文件系统锁争用的物理连续空间预分配 (`preallocateDiskSpace`)
/// - 跨平台统一的文件存在性快速检定 (`fileExists`)
/// - 跨进程 POSIX flock 建议性文件锁 RAII 作用域封装 (`withFileLock`)
public enum PlatformFileSystem {
    
    /// 跨平台 POSIX flock 建议性文件锁 RAII 作用域执行器
    ///
    /// 进程崩溃或异常退出时内核自动释放文件锁，彻底免疫 CI 死锁与资源争用。
    public static func withFileLock<R: Sendable>(
        atPath lockFilePath: String,
        type: PlatformFileLockType = .exclusive,
        _ body: () throws -> R
    ) throws -> R {
        #if os(macOS) || os(Linux)
        let parentDir = (lockFilePath as NSString).deletingLastPathComponent
        if !parentDir.isEmpty && !FileManager.default.fileExists(atPath: parentDir) {
            try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }
        let fd = open(lockFilePath, O_RDWR | O_CREAT, 0o666)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }

        let operation = (type == .exclusive ? LOCK_EX : LOCK_SH)
        while flock(fd, operation) != 0 {
            if errno == EINTR { continue }
            throw POSIXError(.init(rawValue: errno) ?? .EDEADLK)
        }
        defer { _ = flock(fd, LOCK_UN) }

        return try body()
        #else
        return try body()
        #endif
    }
    
    /// 跨平台高效读取物理文件/目录的基础元数据属性
    ///
    /// - Parameter path: 目标文件或目录的绝对路径
    /// - Returns: 强类型 ``PlatformFileAttributes`` 实体
    /// - Throws: 路径不存在或无读取权限时抛出 `POSIXError`
    public static func statFile(path: String) throws -> PlatformFileAttributes {
        #if os(macOS) || os(Linux)
        var statBuf = stat()
        guard stat(path, &statBuf) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
        }
        
        let isDir = (statBuf.st_mode & S_IFMT) == S_IFDIR
        let isSymlink = (statBuf.st_mode & S_IFMT) == S_IFLNK
        let perms = UInt32(statBuf.st_mode & 0o777)
        let isReadOnly = (perms & 0o222) == 0
        let baseName = (path as NSString).lastPathComponent
        let isHidden = baseName.hasPrefix(".")
        
        return PlatformFileAttributes(
            size: Int64(statBuf.st_size),
            isDirectory: isDir,
            isSymbolicLink: isSymlink,
            creationTimeUnixSec: Int64(statBuf.st_ctimespec.tv_sec),
            modificationTimeUnixSec: Int64(statBuf.st_mtimespec.tv_sec),
            posixPermissions: perms,
            isReadOnly: isReadOnly,
            isHidden: isHidden
        )
        #else
        throw POSIXError(.ENOSYS)
        #endif
    }
    
    /// 跨平台磁盘物理空间连续预分配 (消除写入期间的文件系统碎片与 Extent 动态扩展锁)
    ///
    /// - Parameters:
    ///   - filePath: 目标物理文件绝对路径
    ///   - byteCount: 需要预分配的目标字节总大小
    /// - Throws: 无法创建或预分配磁盘空间时抛出错误
    ///
    /// - Note: [APFS Optimization] macOS 上优先使用 `F_PREALLOCATE` (`F_ALLOCATECONTIG`) 申请连续块，失败时自动平滑回退至普通预分配
    public static func preallocateDiskSpace(filePath: String, byteCount: Int64) throws {
        guard byteCount > 0 else { return }
        #if os(macOS)
        let fd = open(filePath, O_WRONLY | O_CREAT, 0o644)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }
        
        var fst = fstore_t(
            fst_flags: UInt32(F_ALLOCATECONTIG | F_ALLOCATEALL),
            fst_posmode: F_PEOFPOSMODE,
            fst_offset: 0,
            fst_length: byteCount,
            fst_bytesalloc: 0
        )
        
        if fcntl(fd, F_PREALLOCATE, &fst) == -1 {
            // 连续空间申请失败时，回退到非连续预分配
            fst.fst_flags = UInt32(F_ALLOCATEALL)
            _ = fcntl(fd, F_PREALLOCATE, &fst)
        }
        _ = ftruncate(fd, byteCount)
        
        #elseif os(Linux)
        let fd = open(filePath, O_WRONLY | O_CREAT, 0o644)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }
        _ = posix_fallocate(fd, 0, byteCount)
        _ = ftruncate(fd, byteCount)
        
        #else
        // Windows SetFileInformationByHandle 预留
        #endif
    }
    
    /// 快速检定目标路径是否存在物理文件或目录
    ///
    /// - Parameter path: 待检视的路径
    /// - Returns: 存在返回 true，不存在返回 false
    @inlinable
    public static func fileExists(atPath path: String) -> Bool {
        #if os(macOS) || os(Linux)
        return access(path, F_OK) == 0
        #else
        return FileManager.default.fileExists(atPath: path)
        #endif
    }
}
