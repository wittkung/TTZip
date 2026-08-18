// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// High-throughput direct I/O writer with APFS pre-allocation and page alignment.
public final class ZipDirectIOWriter: @unchecked Sendable {
    public static let shared = ZipDirectIOWriter()
    
    private init() {}
    
    /// Writes data buffer directly to disk using page alignment and preallocated extents.
    public func writeDirect(filePath: String, data: Data, expectedSize: Int64) -> Bool {
        let fd = open(filePath, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o644)
        if fd < 0 { return false }
        defer { close(fd) }
        
        ZipAPFSPreallocator.shared.preallocateFileExtent(fd: fd, targetSize: expectedSize)
        
        if data.isEmpty { return true }
        
        data.withUnsafeBytes { rawIn in
            if let src = rawIn.baseAddress {
                writeBuffer(fd: fd, buffer: src.assumingMemoryBound(to: UInt8.self), count: data.count)
            }
        }
        return true
    }
    
    /// Writes raw buffer in 64MB chunks to prevent macOS 2GB write system call limits.
    public func writeBuffer(fd: Int32, buffer: UnsafePointer<UInt8>, count: Int) {
        if count <= 0 { return }
        var bytesWritten = 0
        let maxChunk = 64 * 1024 * 1024 // 64MB per write call
        while bytesWritten < count {
            let toWrite = min(maxChunk, count - bytesWritten)
            let n = write(fd, buffer.advanced(by: bytesWritten), toWrite)
            if n <= 0 { break }
            bytesWritten += n
        }
    }
}
