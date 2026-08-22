// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Unified native C acceleration facade for Apple Silicon memory and I/O primitives.
public final class NativeCoreArchitecture: @unchecked Sendable {
    public static let shared = NativeCoreArchitecture()
    private init() {}
    
    /// Triggers APFS file extent physical pre-allocation to prevent fragmentation.
    @discardableResult
    public func preallocateFileExtent(fileDescriptor: Int32, targetSizeBytes: Int64) -> Bool {
        guard fileDescriptor >= 0, targetSizeBytes > 0 else { return false }
        var fstore = fstore_t(
            fst_flags: UInt32(F_ALLOCATECONTIG | F_ALLOCATEALL),
            fst_posmode: F_PEOFPOSMODE,
            fst_offset: 0,
            fst_length: targetSizeBytes,
            fst_bytesalloc: 0
        )
        if fcntl(fileDescriptor, F_PREALLOCATE, &fstore) != -1 { return true }
        fstore.fst_flags = UInt32(F_ALLOCATEALL)
        return fcntl(fileDescriptor, F_PREALLOCATE, &fstore) != -1
    }
    
    /// Computes CRC32 checksum with ARM64 NEON SIMD vectorization.
    public func computeFastCRC32(buffer: UnsafeRawPointer, length: Int) -> UInt32 {
        guard length > 0 else { return 0 }
        return ttzip_rust_crc32(0, buffer.assumingMemoryBound(to: UInt8.self), length)
    }
    
    /// Allocates memory aligned to Apple Silicon 16KB physical page boundaries.
    public func allocateAlignedPageBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: capacity)
    }

    public static func allocateAlignedPageBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: capacity)
    }

    /// Deallocates page-aligned buffer ensuring paired memory management.
    public func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer) {
        CUnsafeBufferAdapter.deallocateAlignedBuffer(pointer)
    }

    public static func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer) {
        CUnsafeBufferAdapter.deallocateAlignedBuffer(pointer)
    }
    
    /// Spawns a high-priority POSIX process using `SubprocessExecutor`.
    public func spawnProcessFast(binaryPath: String, arguments: [String], workingDirectory: String? = nil) -> Int32 {
        return (try? SubprocessExecutor.shared.executeProcess(executablePath: binaryPath, arguments: arguments, currentDirectory: workingDirectory)) ?? -1
    }
}
