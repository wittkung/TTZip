// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// APFS contiguous block preallocation helper eliminating CoW lock contention.
public final class ZipAPFSPreallocator: @unchecked Sendable {
    public static let shared = ZipAPFSPreallocator()
    
    private init() {}
    
    /// Preallocates contiguous physical extent for file descriptor before streaming write.
    @discardableResult
    public func preallocateFileExtent(fd: Int32, targetSize: Int64) -> Bool {
        return ttzip_apfs_preallocate(fd, targetSize) == 0
    }
}
