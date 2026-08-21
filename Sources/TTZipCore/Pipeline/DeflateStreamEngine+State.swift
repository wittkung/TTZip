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

// MARK: - DeflateStreamCompressor State Machine & Lifecycle

/// High-performance streaming Deflate compressor wrapping SIMD-accelerated zlib state machines.
public final class DeflateStreamCompressor: @unchecked Sendable {
    var stream = z_stream()
    var isClosed = false
    public let sessionId: UUID
    public let config: DeflateStreamConfig
    var _totalIn: UInt64 = 0
    var _totalOut: UInt64 = 0
    var _adler: UInt32 = 1
    var _crc: UInt32 = 0
    var _isFinished: Bool = false
    
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
    
    /// Closes compressor and releases underlying handles.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        deflateEnd(&stream)
    }
}

// MARK: - DeflateStreamDecompressor State Machine & Lifecycle

/// High-performance streaming Deflate/Inflate decompressor wrapping SIMD-accelerated zlib state machines.
public final class DeflateStreamDecompressor: @unchecked Sendable {
    var stream = z_stream()
    var isClosed = false
    public let sessionId: UUID
    public let windowBits: Int
    var _totalIn: UInt64 = 0
    var _totalOut: UInt64 = 0
    var _adler: UInt32 = 1
    var _crc: UInt32 = 0
    var _isFinished: Bool = false
    
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
    
    /// Closes decompressor and releases underlying handles.
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        inflateEnd(&stream)
    }
}
