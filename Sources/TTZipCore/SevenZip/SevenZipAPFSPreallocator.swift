// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// APFS physical extent preallocator for 7z target files.
public final class SevenZipAPFSPreallocator: @unchecked Sendable {
    public static let shared = SevenZipAPFSPreallocator()
    
    private init() {}
    
    @discardableResult
    public func preallocateFileExtent(fd: Int32, targetSize: Int64) -> Bool {
        return ttzip_rust_apfs_preallocate(fd, targetSize) == 0
    }
}
