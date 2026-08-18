// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// ARC / RAII-managed read-only virtual memory mapping handle.
///
/// Implements zero-copy kernel page mapping (`mmap`) with Swift 6 strict concurrency
/// (`Sendable`), deterministic unmapping in `deinit`, and OS page cache prefetching (`madvise`).
public final class MmapBufferHandle: @unchecked Sendable {
    
    /// Base address of mapped read-only memory region.
    public let baseAddress: UnsafeRawPointer
    
    /// Total mapped byte size.
    public let count: Int
    
    /// Underlying file descriptor.
    public let fileDescriptor: Int32
    
    /// Whether this handle owns and should close the file descriptor on deinitialization.
    public let ownsFileDescriptor: Bool
    
    /// Zero-copy strongly-typed continuous byte buffer.
    @inline(__always)
    public var bytes: UnsafeBufferPointer<UInt8> {
        UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: count)
    }
    
    /// Raw un-typed byte buffer view.
    @inline(__always)
    public var rawBuffer: UnsafeRawBufferPointer {
        UnsafeRawBufferPointer(start: baseAddress, count: count)
    }
    
    /// Extracts a bounds-checked zero-copy slice of mapped memory.
    /// - Parameters:
    ///   - offset: Starting byte offset.
    ///   - length: Sliced byte count.
    /// - Returns: Pointer buffer view, or `nil` if bounds are exceeded.
    @inline(__always)
    public func slice(offset: Int, length: Int) -> UnsafeBufferPointer<UInt8>? {
        guard offset >= 0, length >= 0, offset + length <= count else { return nil }
        guard let base = bytes.baseAddress else { return nil }
        return UnsafeBufferPointer(start: base.advanced(by: offset), count: length)
    }

    /// Advises kernel on expected memory access patterns (`posix_madvise`).
    /// - Parameter advice: POSIX memory advice flag (e.g. `POSIX_MADV_SEQUENTIAL`).
    @inline(__always)
    public func advise(_ advice: Int32) {
        if count > 0 {
            posix_madvise(UnsafeMutableRawPointer(mutating: baseAddress), count, advice)
        }
    }

    /// Maps a filesystem path into virtual memory as a read-only buffer.
    /// - Parameters:
    ///   - path: Absolute or relative filesystem path.
    ///   - advice: Kernel page access advice.
    /// - Returns: RAII-managed `MmapBufferHandle`.
    /// - Throws: `POSIXError` on open, stat, or mmap failure.
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

    /// Maps an existing open file descriptor into virtual memory.
    /// - Parameters:
    ///   - fd: Open file descriptor.
    ///   - size: Byte size to map.
    ///   - advice: Kernel page access advice.
    ///   - ownsFileDescriptor: Whether this handle should close the fd upon deinit.
    /// - Returns: RAII-managed `MmapBufferHandle`.
    /// - Throws: `POSIXError` on mmap failure.
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
    
    /// Deterministic memory unmapping and descriptor closure.
    deinit {
        if count > 0 {
            munmap(UnsafeMutableRawPointer(mutating: baseAddress), count)
        }
        if ownsFileDescriptor && fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }
}
