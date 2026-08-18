// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

#if os(macOS) || os(Linux)
import Darwin
#endif

/// Cross-platform POSIX flock advisory file lock mode.
public enum PlatformFileLockType: Sendable {
    case exclusive
    case shared
}

/// Cross-platform file system metadata extraction, continuous disk space preallocation, and advisory locking subsystem.
public enum PlatformFileSystem {
    
    /// Cross-platform POSIX advisory file lock RAII scope executor.
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
    
    /// Reads physical file or directory metadata attributes.
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
    
    /// Preallocates contiguous physical disk space to prevent file system fragmentation and extent expansion overhead.
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
        #endif
    }
    
    /// Fast check for physical file existence using `access(2)`.
    @inlinable
    public static func fileExists(atPath path: String) -> Bool {
        #if os(macOS) || os(Linux)
        return access(path, F_OK) == 0
        #else
        return FileManager.default.fileExists(atPath: path)
        #endif
    }
}
