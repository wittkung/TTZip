// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Character set detection and encoding normalization strategy interface (Strategy Pattern).
public protocol CharsetDetectionStrategyProtocol: Sendable {
    var charsetStrategyName: String { get }
    func canHandle(bytes: Data) -> Bool
    func sanitize(bytes: Data) -> String?
}

// MARK: - Concrete Charset Strategies

/// 1. SIMD ASCII fast-path detection strategy (`ASCIIFastPathCharsetStrategy`).
public final class ASCIIFastPathCharsetStrategy: CharsetDetectionStrategyProtocol {
    public let charsetStrategyName: String = "ASCII SIMD Fast-Path Strategy"
    
    public init() {}
    
    public func canHandle(bytes: Data) -> Bool {
        return !bytes.contains { $0 >= 0x80 }
    }
    
    public func sanitize(bytes: Data) -> String? {
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// 2. UTF-8 standard decoding strategy (`UTF8CharsetStrategy`).
public final class UTF8CharsetStrategy: CharsetDetectionStrategyProtocol {
    public let charsetStrategyName: String = "UTF-8 Standard Strategy"
    
    public init() {}
    
    public func canHandle(bytes: Data) -> Bool {
        if let str = String(data: bytes, encoding: .utf8), !str.isEmpty {
            return true
        }
        return false
    }
    
    public func sanitize(bytes: Data) -> String? {
        return String(data: bytes, encoding: .utf8)
    }
}

/// 3. CJK legacy encoding conversion strategy (`CJKLegacyCharsetStrategy`).
public final class CJKLegacyCharsetStrategy: CharsetDetectionStrategyProtocol {
    public let charsetStrategyName: String = "CJK (GB18030/BIG5/Shift-JIS/EUC-KR) Native Rust Transcoding Strategy"
    
    public init() {}
    
    public func canHandle(bytes: Data) -> Bool {
        return true
    }
    
    public func sanitize(bytes: Data) -> String? {
        if bytes.isEmpty { return "" }
        let capacity = max(bytes.count * 4 + 1, 256)
        var buffer = [CChar](repeating: 0, count: capacity)
        var written: Int = 0
        let status: CTTZipBridge.TTZipStatus = bytes.withUnsafeBytes { rawPtr -> CTTZipBridge.TTZipStatus in
            guard let baseAddress = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return ttzip_rust_sanitize_filename(baseAddress, bytes.count, &buffer, buffer.count, &written)
        }
        if status == TTZIP_STATUS_OK {
            let nonNullBytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            return String(decoding: nonNullBytes, as: UTF8.self)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

// MARK: - Charset Detection Strategy Context

public final class CharsetDetectionStrategyContext: @unchecked Sendable {
    public static let shared = CharsetDetectionStrategyContext()
    private let strategies: [CharsetDetectionStrategyProtocol] = [
        ASCIIFastPathCharsetStrategy(),
        UTF8CharsetStrategy(),
        CJKLegacyCharsetStrategy()
    ]
    
    private let lock = NSLock()
    private var charsetCache: [Data: String] = [:]
    private var sanitizeCache: [Data: String] = [:]
    
    public func detectCharset(data: Data) -> String {
        if data.isEmpty {
            return "ASCII"
        }
        if let cached = lock.withLock({ charsetCache[data] }) {
            return cached
        }
        
        var buffer = [CChar](repeating: 0, count: 64)
        let status: CTTZipBridge.TTZipStatus = data.withUnsafeBytes { rawPtr -> CTTZipBridge.TTZipStatus in
            guard let baseAddress = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return ttzip_rust_detect_charset(baseAddress, data.count, &buffer, buffer.count)
        }
        
        let detected: String
        if status == TTZIP_STATUS_OK, buffer[0] != 0 {
            let nonNullBytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            detected = String(decoding: nonNullBytes, as: UTF8.self)
        } else if !data.contains(where: { $0 >= 0x80 }) {
            detected = "ASCII"
        } else {
            detected = "UTF-8"
        }
        
        lock.withLock {
            if charsetCache.count >= 500 {
                charsetCache.removeAll()
            }
            charsetCache[data] = detected
        }
        return detected
    }
    
    public func sanitizeFilename(bytes: Data) -> String {
        if bytes.isEmpty { return "" }
        if let cached = lock.withLock({ sanitizeCache[bytes] }) {
            return cached
        }
        
        let result: String
        var handled = false
        var tempResult = ""
        
        for strategy in strategies {
            if strategy.canHandle(bytes: bytes), let res = strategy.sanitize(bytes: bytes) {
                tempResult = res
                handled = true
                break
            }
        }
        
        if handled {
            result = tempResult
        } else {
            result = String(decoding: bytes, as: UTF8.self)
        }
        
        lock.withLock {
            if sanitizeCache.count >= 500 {
                sanitizeCache.removeAll()
            }
            sanitizeCache[bytes] = result
        }
        return result
    }
    
    public func clearCache() {
        lock.withLock {
            charsetCache.removeAll()
            sanitizeCache.removeAll()
        }
    }
}
