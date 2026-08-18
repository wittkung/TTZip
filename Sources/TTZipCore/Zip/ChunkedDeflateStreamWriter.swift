// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adaptive chunked DEFLATE streaming pipeline writer.
///
/// Streams files > 256MB in 1MB chunks to constrain resident memory <= 64MB.
public final class ChunkedDeflateStreamWriter: @unchecked Sendable {
    public static let adaptiveThresholdBytes: Int64 = 256 * 1024 * 1024 // 256MB
    
    private var streamHandle: OpaquePointer?
    private let outFd: Int32
    private let level: Int32
    private var isClosed = false
    
    public init?(outFd: Int32, level: Int = 6) {
        self.outFd = outFd
        self.level = Int32(level > 0 ? (level > 12 ? 12 : level) : 6)
        guard let handle = ttzip_zip_chunked_stream_create(outFd, self.level) else {
            return nil
        }
        self.streamHandle = handle
    }
    
    deinit {
        close()
    }
    
    /// Writes a data buffer into the streaming pipeline.
    public func write(data: Data) -> Bool {
        guard let handle = streamHandle, !isClosed, !data.isEmpty else {
            return !isClosed
        }
        
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            let written = ttzip_zip_chunked_stream_write(handle, baseAddress, rawBuffer.count)
            return written == Int64(rawBuffer.count)
        }
    }
    
    /// Writes raw pointer buffer into the streaming pipeline.
    public func write(buffer: UnsafeRawPointer, count: Int) -> Bool {
        guard let handle = streamHandle, !isClosed, count > 0 else {
            return !isClosed
        }
        let written = ttzip_zip_chunked_stream_write(handle, buffer, count)
        return written == Int64(count)
    }
    
    /// Finalizes the stream and returns total compressed bytes and CRC-32 checksum.
    public func finish() -> (totalCompressed: UInt64, finalCrc32: UInt32)? {
        guard let handle = streamHandle, !isClosed else { return nil }
        var totalComp: UInt64 = 0
        var finalCrc: UInt32 = 0
        
        let res = ttzip_zip_chunked_stream_finish(handle, &totalComp, &finalCrc)
        guard res == 0 else { return nil }
        
        close()
        return (totalCompressed: totalComp, finalCrc32: finalCrc)
    }
    
    /// Closes and releases the chunked stream handle.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        if let handle = streamHandle {
            ttzip_zip_chunked_stream_destroy(handle)
            streamHandle = nil
        }
    }
}
