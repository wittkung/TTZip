// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

/// In-process memory telemetry snapshot (Resident Set Size, high-water mark peak RSS, and virtual size).
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

/// Cross-platform aligned memory allocation, virtual memory mapping, and dead-store immune memory sanitization subsystem.
public enum PlatformMemory {
    
    /// Queries current process physical resident memory (RSS), peak RSS high-water mark, and virtual memory snapshot.
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
    
    /// Allocates contiguous physical memory buffer with custom byte alignment.
    @inlinable
    public static func allocateAlignedPages(alignment: Int, byteCount: Int) -> UnsafeMutableRawPointer? {
        guard byteCount > 0, alignment > 0 else { return nil }
        return ttzip_platform_aligned_alloc(alignment, byteCount)
    }
    
    /// Deallocates memory previously allocated by ``allocateAlignedPages``.
    @inlinable
    public static func deallocateAlignedPages(pointer: UnsafeMutableRawPointer?) {
        guard let pointer = pointer else { return }
        ttzip_platform_aligned_free(pointer)
    }
    
    /// Allocates page-aligned heap buffer conforming to default platform page alignment (16KB on Apple Silicon).
    @inlinable
    public static func allocateAlignedPageBuffer(byteCount: Int) -> UnsafeMutableRawPointer? {
        guard byteCount > 0 else { return nil }
        let alignment = PlatformOperatingSystem.current.defaultPageAlignment
        return ttzip_platform_aligned_alloc(alignment, byteCount)
    }
    
    /// Deallocates page-aligned heap buffer previously allocated by ``allocateAlignedPageBuffer(byteCount:)``.
    @inlinable
    public static func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer?) {
        guard let pointer = pointer else { return }
        ttzip_platform_aligned_free(pointer)
    }
    
    /// Erases sensitive memory (passwords, keys, decryption state) with dead-store elimination immunity.
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
    
    /// Maps physical file into virtual address space in read-only mode and returns mapping descriptor.
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
    
    /// Maps physical file into virtual address space in read-only mode within RAII closure scope.
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
