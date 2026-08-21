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
    public let charsetStrategyName: String = "CJK (GB18030/BIG5/Shift-JIS) Legacy Conversion Strategy"
    
    public init() {}
    
    public func canHandle(bytes: Data) -> Bool {
        return true
    }
    
    public func sanitize(bytes: Data) -> String? {
        let encodings: [CFStringEncodings] = [
            .GB_18030_2000,
            .big5,
            .shiftJIS,
            .EUC_KR
        ]
        for enc in encodings {
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(enc.rawValue))
            let encoding = String.Encoding(rawValue: nsEnc)
            if let converted = String(data: bytes, encoding: encoding), !converted.isEmpty {
                return converted
            }
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
    
    private let charsetCache = ReadWriteLockCache<Data, String>(policy: .lru(maxEntries: 500))
    private let sanitizeCache = ReadWriteLockCache<Data, String>(policy: .lru(maxEntries: 500))
    
    public func detectCharset(data: Data) -> String {
        if data.isEmpty {
            return "ASCII"
        }
        if let cached = charsetCache.value(forKey: data) {
            return cached
        }
        
        let detected: String
        if !data.contains(where: { $0 >= 0x80 }) {
            detected = "ASCII"
        } else if let _ = String(data: data, encoding: .utf8) {
            detected = "UTF-8"
        } else {
            let encodings: [(String, CFStringEncodings)] = [
                ("GB18030", .GB_18030_2000),
                ("BIG5", .big5),
                ("Shift-JIS", .shiftJIS),
                ("EUC-KR", .EUC_KR)
            ]
            var found = "WINDOWS-1252"
            for (name, enc) in encodings {
                let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(enc.rawValue))
                let encoding = String.Encoding(rawValue: nsEnc)
                if let str = String(data: data, encoding: encoding), !str.isEmpty {
                    found = name
                    break
                }
            }
            detected = found
        }
        
        charsetCache.setValue(detected, forKey: data)
        return detected
    }
    
    public func sanitizeFilename(bytes: Data) -> String {
        if let cached = sanitizeCache.value(forKey: bytes) {
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
        
        sanitizeCache.setValue(result, forKey: bytes)
        return result
    }
    
    public func clearCache() {
        charsetCache.removeAll()
        sanitizeCache.removeAll()
    }
}
