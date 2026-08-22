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
    
    private let outFd: Int32
    private let compressor: DeflateStreamCompressor?
    private var isClosed = false
    private var totalOut: UInt64 = 0
    private var currentCrc: UInt32 = 0
    
    public init?(outFd: Int32, level: Int = 6) {
        self.outFd = outFd
        let config = DeflateStreamConfig(compressionLevel: level, windowBits: -15)
        self.compressor = try? DeflateStreamCompressor(config: config)
        if self.compressor == nil { return nil }
    }
    
    deinit {
        close()
    }
    
    /// Writes a data buffer into the streaming pipeline.
    public func write(data: Data) -> Bool {
        guard compressor != nil, !isClosed else { return false }
        if data.isEmpty { return true }
        
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            return write(buffer: baseAddress, count: rawBuffer.count)
        }
    }
    
    /// Writes raw pointer buffer into the streaming pipeline.
    public func write(buffer: UnsafeRawPointer, count: Int) -> Bool {
        guard let compressor = compressor, !isClosed else { return false }
        if count == 0 { return true }
        
        let inBytes = buffer.assumingMemoryBound(to: UInt8.self)
        currentCrc = ttzip_rust_crc32(currentCrc, inBytes, count)
        
        var writeSuccess = true
        do {
            try compressor.compress(buffer: buffer, count: count, flush: .noFlush) { outChunk in
                if let base = outChunk.baseAddress, outChunk.count > 0 {
                    let w = Darwin.write(outFd, base, outChunk.count)
                    if w != outChunk.count {
                        writeSuccess = false
                    } else {
                        totalOut += UInt64(w)
                    }
                }
            }
        } catch {
            return false
        }
        return writeSuccess
    }
    
    /// Finalizes the stream and returns total compressed bytes and CRC-32 checksum.
    public func finish() -> (totalCompressed: UInt64, finalCrc32: UInt32)? {
        guard let compressor = compressor, !isClosed else { return nil }
        
        var writeSuccess = true
        do {
            try compressor.finish { outChunk in
                if let base = outChunk.baseAddress, outChunk.count > 0 {
                    let w = Darwin.write(outFd, base, outChunk.count)
                    if w != outChunk.count {
                        writeSuccess = false
                    } else {
                        totalOut += UInt64(w)
                    }
                }
            }
        } catch {
            return nil
        }
        
        guard writeSuccess else { return nil }
        close()
        return (totalCompressed: totalOut, finalCrc32: currentCrc)
    }
    
    /// Closes and releases the chunked stream handle.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        compressor?.close()
    }
}

