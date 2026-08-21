// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge
import zlib

// MARK: - DeflateStreamCompressor Chunk Streaming & Flush

extension DeflateStreamCompressor {
    /// Streams compression on raw pointer buffer.
    public func compress(
        buffer: UnsafeRawPointer,
        count: Int,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        guard count > 0 || flush == .finish else { return }
        
        let effectiveChunkSize = max(1024, outputChunkSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: effectiveChunkSize)
        defer { outBuffer.deallocate() }
        
        if count > 0 {
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: buffer.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = uInt(count)
        } else {
            stream.next_in = nil
            stream.avail_in = 0
        }
        
        let zFlush: Int32
        switch flush {
        case .noFlush: zFlush = Z_NO_FLUSH
        case .syncFlush: zFlush = Z_SYNC_FLUSH
        case .fullFlush: zFlush = Z_FULL_FLUSH
        case .finish: zFlush = Z_FINISH
        }
        
        while stream.avail_in > 0 || (flush == .finish && !_isFinished) {
            stream.next_out = outBuffer
            stream.avail_out = uInt(effectiveChunkSize)
            
            let ret = deflate(&stream, zFlush)
            if ret == Z_STREAM_ERROR {
                throw DeflateStreamError.processingFailed("deflate failed with Z_STREAM_ERROR")
            }
            
            let produced = effectiveChunkSize - Int(stream.avail_out)
            if produced > 0 {
                chunkHandler(UnsafeRawBufferPointer(start: outBuffer, count: produced))
            }
            
            if ret == Z_STREAM_END {
                _isFinished = true
                break
            }
            
            if produced == 0 && stream.avail_in == 0 {
                break
            }
        }
        
        _totalIn = UInt64(stream.total_in)
        _totalOut = UInt64(stream.total_out)
        _adler = UInt32(stream.adler)
    }
    
    /// Streams compression on Data block.
    public func compress(
        chunk: Data,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        var output = Data()
        if chunk.isEmpty && flush != .finish {
            return output
        }
        
        try chunk.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                try compress(
                    buffer: baseAddress,
                    count: rawBuffer.count,
                    flush: flush,
                    outputChunkSize: outputChunkSize
                ) { outChunk in
                    output.append(outChunk.bindMemory(to: UInt8.self))
                }
            } else {
                let dummy = [UInt8]()
                try dummy.withUnsafeBytes { dummyBuffer in
                    try compress(
                        buffer: dummyBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!,
                        count: 0,
                        flush: flush,
                        outputChunkSize: outputChunkSize
                    ) { outChunk in
                        output.append(outChunk.bindMemory(to: UInt8.self))
                    }
                }
            }
        }
        return output
    }
    
    /// Finishes stream and flushes trailing compressed bytes.
    public func finish(
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        if _isFinished { return }
        
        let dummy = [UInt8]()
        try dummy.withUnsafeBytes { dummyBuffer in
            try compress(
                buffer: dummyBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!,
                count: 0,
                flush: .finish,
                outputChunkSize: outputChunkSize,
                chunkHandler: chunkHandler
            )
        }
    }
    
    /// Finishes stream and returns remaining trailing bytes.
    public func finish(outputChunkSize: Int = 64 * 1024) throws -> Data {
        var output = Data()
        try finish(outputChunkSize: outputChunkSize) { outChunk in
            output.append(outChunk.bindMemory(to: UInt8.self))
        }
        return output
    }
}

// MARK: - DeflateStreamDecompressor Chunk Streaming & Flush

extension DeflateStreamDecompressor {
    /// Streams decompression on raw pointer buffer.
    public func decompress(
        buffer: UnsafeRawPointer,
        count: Int,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        guard count > 0 || flush == .finish else { return }
        
        let effectiveChunkSize = max(1024, outputChunkSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: effectiveChunkSize)
        defer { outBuffer.deallocate() }
        
        if count > 0 {
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: buffer.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = uInt(count)
        } else {
            stream.next_in = nil
            stream.avail_in = 0
        }
        
        let zFlush = (flush == .finish) ? Z_FINISH : Z_NO_FLUSH
        
        while stream.avail_in > 0 || (flush == .finish && !_isFinished) {
            stream.next_out = outBuffer
            stream.avail_out = uInt(effectiveChunkSize)
            
            let ret = inflate(&stream, zFlush)
            if ret < 0 && ret != Z_BUF_ERROR {
                throw DeflateStreamError.corruptedData("Stream decompression failed with status: \(ret)")
            }
            
            let produced = effectiveChunkSize - Int(stream.avail_out)
            if produced > 0 {
                chunkHandler(UnsafeRawBufferPointer(start: outBuffer, count: produced))
            }
            
            if ret == Z_STREAM_END {
                _isFinished = true
                break
            }
            
            if produced == 0 && stream.avail_in == 0 {
                break
            }
        }
        
        _totalIn = UInt64(stream.total_in)
        _totalOut = UInt64(stream.total_out)
        _adler = UInt32(stream.adler)
        
        if flush == .finish && !_isFinished {
            throw DeflateStreamError.corruptedData("Deflate stream ended prematurely without Z_STREAM_END")
        }
    }
    
    /// Streams decompression on Data block.
    public func decompress(
        chunk: Data,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        var output = Data()
        if chunk.isEmpty && flush != .finish {
            return output
        }
        
        try chunk.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                try decompress(
                    buffer: baseAddress,
                    count: rawBuffer.count,
                    flush: flush,
                    outputChunkSize: outputChunkSize
                ) { outChunk in
                    output.append(outChunk.bindMemory(to: UInt8.self))
                }
            } else {
                let dummy = [UInt8]()
                try dummy.withUnsafeBytes { dummyBuffer in
                    try decompress(
                        buffer: dummyBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!,
                        count: 0,
                        flush: flush,
                        outputChunkSize: outputChunkSize
                    ) { outChunk in
                        output.append(outChunk.bindMemory(to: UInt8.self))
                    }
                }
            }
        }
        return output
    }
    
    /// Finishes decompression and flushes trailing decompressed bytes.
    public func finish(
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        if _isFinished { return }
        
        let dummy = [UInt8]()
        try dummy.withUnsafeBytes { dummyBuffer in
            try decompress(
                buffer: dummyBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!,
                count: 0,
                flush: .finish,
                outputChunkSize: outputChunkSize,
                chunkHandler: chunkHandler
            )
        }
    }
    
    /// Finishes decompression and returns trailing decompressed bytes.
    public func finish(outputChunkSize: Int = 64 * 1024) throws -> Data {
        var output = Data()
        try finish(outputChunkSize: outputChunkSize) { outChunk in
            output.append(outChunk.bindMemory(to: UInt8.self))
        }
        return output
    }
}
