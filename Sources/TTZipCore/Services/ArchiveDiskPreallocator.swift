// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Unified APFS physical disk space preallocation and filesystem optimization service.
///
/// Pre-locks contiguous APFS clusters before extraction or archive creation to eliminate
/// POSIX file expansion lock contention and disk fragmentation.
public struct ArchiveDiskPreallocator: Sendable {
    public init() {}
    
    /// Preallocates APFS space for an open file descriptor.
    @discardableResult
    public static func preallocate(fileDescriptor: Int32, targetSizeBytes: Int64) -> Bool {
        guard fileDescriptor >= 0, targetSizeBytes > 0 else { return false }
        return ttzip_apfs_preallocate(fileDescriptor, targetSizeBytes) == 0
    }
    
    /// Preallocates APFS space for specified physical file path.
    @discardableResult
    public static func preallocate(atPath path: String, targetSizeBytes: Int64) -> Bool {
        guard targetSizeBytes > 0 else { return false }
        let fd = open(path, O_RDWR | O_CREAT, 0644)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return preallocate(fileDescriptor: fd, targetSizeBytes: targetSizeBytes)
    }
    
    /// Performs APFS block-level copy-on-write clone range expansion.
    @discardableResult
    public static func cloneRange(sourceFd: Int32, sourceOffset: Int64 = 0, targetFd: Int32, targetOffset: Int64 = 0, countBytes: UInt64) -> Bool {
        guard sourceFd >= 0, targetFd >= 0, countBytes > 0 else { return false }
        return ttzip_apfs_clone_range(sourceFd, sourceOffset, targetFd, targetOffset, countBytes) == 0
    }
}
