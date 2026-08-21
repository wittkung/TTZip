// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge
import zlib

// MARK: - Deflate Stream Enums & Configuration

/// Deflate execution tier mode.
public enum DeflateTierMode: Int32, Sendable, Codable, Equatable {
    /// Tier 1: In-memory full-buffer fast path (libdeflate).
    case tier1Block = 1
    /// Tier 2: State machine incremental streaming pipeline (zlib-ng SIMD).
    case tier2Stream = 2
}

/// Deflate window and container header format.
public enum DeflateWindowBits: Int32, Sendable, Codable, Equatable {
    /// Raw DEFLATE stream without header or trailer checksum (RFC 1951, standard in ZIP).
    case raw = -15
    /// Standard zlib header and Adler-32 checksum (RFC 1950).
    case zlib = 15
    /// GZIP header and CRC-32 checksum (RFC 1952).
    case gzip = 31
}

/// Deflate compression strategies.
public enum DeflateStrategy: Int32, Sendable, Codable, Equatable {
    case defaultStrategy = 0
    case filtered = 1
    case huffmanOnly = 2
    case rle = 3
    case fixed = 4
}

/// Deflate buffer flush modes.
public enum DeflateFlushMode: Int32, Sendable, Codable, Equatable {
    case noFlush = 0
    case syncFlush = 2
    case fullFlush = 3
    case finish = 4
    
    public var stringValue: String {
        switch self {
        case .noFlush: return "NO_FLUSH"
        case .syncFlush: return "SYNC_FLUSH"
        case .fullFlush: return "FULL_FLUSH"
        case .finish: return "FINISH"
        }
    }
}

/// Deflate stream processing errors.
public enum DeflateStreamError: LocalizedError, Sendable, Equatable {
    case initializationFailed(Int32)
    case processingFailed(String)
    case streamAlreadyClosed
    case invalidParameters(String)
    case corruptedData(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let code):
            return "Deflate stream initialization failed with code: \(code)"
        case .processingFailed(let msg):
            return "Deflate stream processing failed: \(msg)"
        case .streamAlreadyClosed:
            return "Deflate stream has already been closed"
        case .invalidParameters(let msg):
            return "Invalid stream parameters: \(msg)"
        case .corruptedData(let msg):
            return "Corrupted Deflate stream data: \(msg)"
        }
    }
}

/// Deflate streaming configuration payload.
public struct DeflateStreamConfig: Sendable, Codable, Equatable {
    public var tierMode: DeflateTierMode
    public var compressionLevel: Int
    public var windowBits: Int
    public var memLevel: Int
    public var strategy: DeflateStrategy
    
    public init(
        tierMode: DeflateTierMode = .tier2Stream,
        compressionLevel: Int = 6,
        windowBits: Int = 15,
        memLevel: Int = 8,
        strategy: DeflateStrategy = .defaultStrategy
    ) {
        self.tierMode = tierMode
        self.compressionLevel = max(1, min(9, compressionLevel))
        self.windowBits = windowBits
        self.memLevel = max(1, min(9, memLevel))
        self.strategy = strategy
    }
    
    public static var fastStreaming: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 1, windowBits: 15)
    }
    
    public static var gzipFastStreaming: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 1, windowBits: 31)
    }
    
    public static var rawFastStreaming: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 1, windowBits: -15)
    }
    
    public static var standardGzip: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 6, windowBits: 31)
    }
    
    public static var standardRaw: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
    }
}

/// Runtime telemetry metrics for Deflate streams.
public struct DeflateStreamMetrics: Sendable, Equatable {
    public let totalIn: UInt64
    public let totalOut: UInt64
    public let adler32: UInt32
    public let crc32: UInt32
    public let isFinished: Bool
}

// MARK: - DeflateStreamCompressor

/// High-performance streaming Deflate compressor wrapping SIMD-accelerated zlib state machines.
public final class DeflateStreamCompressor: @unchecked Sendable {
    private var stream = z_stream()
    private var isClosed = false
    public let sessionId: UUID
    public let config: DeflateStreamConfig
    private var _totalIn: UInt64 = 0
    private var _totalOut: UInt64 = 0
    private var _adler: UInt32 = 1
    private var _crc: UInt32 = 0
    private var _isFinished: Bool = false
    
    public init(config: DeflateStreamConfig = DeflateStreamConfig()) throws {
        self.sessionId = UUID()
        self.config = config
        
        let st = deflateInit2_(
            &self.stream,
            Int32(config.compressionLevel),
            Z_DEFLATED,
            Int32(config.windowBits),
            Int32(config.memLevel),
            config.strategy.rawValue,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard st == Z_OK else {
            throw DeflateStreamError.initializationFailed(st)
        }
    }
    
    deinit {
        close()
    }
    
    public var totalIn: UInt64 {
        return _totalIn
    }
    
    public var totalOut: UInt64 {
        return _totalOut
    }
    
    public var adler32: UInt32 {
        return _adler
    }
    
    public var crc32: UInt32 {
        return _crc
    }
    
    public var isFinished: Bool {
        return _isFinished
    }
    
    public var metrics: DeflateStreamMetrics {
        return DeflateStreamMetrics(
            totalIn: _totalIn,
            totalOut: _totalOut,
            adler32: _adler,
            crc32: _crc,
            isFinished: _isFinished
        )
    }
    
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
    
    /// Closes compressor and releases underlying handles.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        deflateEnd(&stream)
    }
}

// MARK: - DeflateStreamDecompressor

/// High-performance streaming Deflate/Inflate decompressor wrapping SIMD-accelerated zlib state machines.
public final class DeflateStreamDecompressor: @unchecked Sendable {
    private var stream = z_stream()
    private var isClosed = false
    public let sessionId: UUID
    public let windowBits: Int
    private var _totalIn: UInt64 = 0
    private var _totalOut: UInt64 = 0
    private var _adler: UInt32 = 1
    private var _crc: UInt32 = 0
    private var _isFinished: Bool = false
    
    public init(windowBits: Int = 15) throws {
        self.sessionId = UUID()
        self.windowBits = windowBits
        let st = inflateInit2_(
            &self.stream,
            Int32(windowBits),
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard st == Z_OK else {
            throw DeflateStreamError.initializationFailed(st)
        }
    }
    
    deinit {
        close()
    }
    
    public var totalIn: UInt64 {
        return _totalIn
    }
    
    public var totalOut: UInt64 {
        return _totalOut
    }
    
    public var adler32: UInt32 {
        return _adler
    }
    
    public var crc32: UInt32 {
        return _crc
    }
    
    public var isFinished: Bool {
        return _isFinished
    }
    
    public var metrics: DeflateStreamMetrics {
        return DeflateStreamMetrics(
            totalIn: _totalIn,
            totalOut: _totalOut,
            adler32: _adler,
            crc32: _crc,
            isFinished: _isFinished
        )
    }
    
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
    
    /// Closes decompressor and releases underlying handles.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        inflateEnd(&stream)
    }
}

// MARK: - DeflateStreamEngine

/// High-level facade for streaming Deflate transformations.
public enum DeflateStreamEngine: Sendable {
    
    /// In-memory one-shot compression.
    public static func compress(
        data: Data,
        config: DeflateStreamConfig = DeflateStreamConfig(),
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        let compressor = try DeflateStreamCompressor(config: config)
        var result = try compressor.compress(chunk: data, flush: .finish, outputChunkSize: outputChunkSize)
        if !compressor.isFinished {
            let tail = try compressor.finish(outputChunkSize: outputChunkSize)
            result.append(tail)
        }
        return result
    }
    
    /// In-memory one-shot decompression.
    public static func decompress(
        data: Data,
        windowBits: Int = 15,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        let decompressor = try DeflateStreamDecompressor(windowBits: windowBits)
        var result = try decompressor.decompress(chunk: data, flush: .finish, outputChunkSize: outputChunkSize)
        if !decompressor.isFinished {
            let tail = try decompressor.finish(outputChunkSize: outputChunkSize)
            result.append(tail)
        }
        return result
    }
    
    /// Asynchronous streaming compression pipeline (`AsyncSequence` -> `AsyncThrowingStream`).
    public static func compressStream<S: AsyncSequence>(
        _ sequence: S,
        config: DeflateStreamConfig = DeflateStreamConfig(),
        outputChunkSize: Int = 64 * 1024
    ) -> AsyncThrowingStream<Data, Error> where S.Element == Data, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let compressor = try DeflateStreamCompressor(config: config)
                    defer { compressor.close() }
                    
                    for try await chunk in sequence {
                        try Task.checkCancellation()
                        let compressedChunk = try compressor.compress(
                            chunk: chunk,
                            flush: .noFlush,
                            outputChunkSize: outputChunkSize
                        )
                        if !compressedChunk.isEmpty {
                            continuation.yield(compressedChunk)
                        }
                    }
                    
                    let tail = try compressor.finish(outputChunkSize: outputChunkSize)
                    if !tail.isEmpty {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    /// Asynchronous streaming decompression pipeline (`AsyncSequence` -> `AsyncThrowingStream`).
    public static func decompressStream<S: AsyncSequence>(
        _ sequence: S,
        windowBits: Int = 15,
        outputChunkSize: Int = 64 * 1024
    ) -> AsyncThrowingStream<Data, Error> where S.Element == Data, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let decompressor = try DeflateStreamDecompressor(windowBits: windowBits)
                    defer { decompressor.close() }
                    
                    for try await chunk in sequence {
                        try Task.checkCancellation()
                        let decompressedChunk = try decompressor.decompress(
                            chunk: chunk,
                            flush: .noFlush,
                            outputChunkSize: outputChunkSize
                        )
                        if !decompressedChunk.isEmpty {
                            continuation.yield(decompressedChunk)
                        }
                    }
                    
                    let tail = try decompressor.finish(outputChunkSize: outputChunkSize)
                    if !tail.isEmpty {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

