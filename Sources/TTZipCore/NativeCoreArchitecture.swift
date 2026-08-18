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
        return ttzip_core_apfs_preallocate_file(fileDescriptor, targetSizeBytes) == 0
    }
    
    /// Computes CRC32 checksum with ARM64 NEON SIMD vectorization.
    public func computeFastCRC32(buffer: UnsafeRawPointer, length: Int) -> UInt32 {
        return ttzip_core_crc32_neon_single(0, buffer.assumingMemoryBound(to: UInt8.self), length)
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
    
    /// Spawns a high-priority POSIX process using `posix_spawn`.
    public func spawnProcessFast(binaryPath: String, arguments: [String], workingDirectory: String? = nil) -> Int32 {
        return (try? POSIXTarCAdapter.shared.spawnProcess(binaryPath: binaryPath, arguments: arguments, workingDirectory: workingDirectory)) ?? -1
    }
}
