// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Direct I/O and page-aligned storage writer for 7z extraction.
public final class SevenZipDirectIOWriter: @unchecked Sendable {
    public static let shared = SevenZipDirectIOWriter()
    
    private init() {}
    
    public func writeDirect(filePath: String, data: Data, expectedSize: Int64) -> Bool {
        let fd = open(filePath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if fd < 0 { return false }
        defer { close(fd) }
        
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
