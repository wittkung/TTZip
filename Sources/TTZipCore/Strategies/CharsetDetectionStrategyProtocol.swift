import Foundation
import CTTZipBridge

/// 【3.1 策略模式 - 自主寻猎扩展】字符集编码识别与乱码修复策略接口
public protocol CharsetDetectionStrategyProtocol: Sendable {
    var charsetStrategyName: String { get }
    func canHandle(bytes: Data) -> Bool
    func sanitize(bytes: Data) -> String?
}

// MARK: - 具体字符集策略实现 (Concrete Charset Strategies)

/// 1. SIMD ASCII 极速直通策略 (`ASCIIFastPathCharsetStrategy`)
public final class ASCIIFastPathCharsetStrategy: CharsetDetectionStrategyProtocol {
    public let charsetStrategyName: String = "ASCII SIMD 极速直通策略"
    
    public init() {}
    
    public func canHandle(bytes: Data) -> Bool {
        return CUnsafeBufferAdapter.withBufferPointer(bytes) { ptr, count in
            return ttzip_is_ascii_fast(ptr, count)
        }
    }
    
    public func sanitize(bytes: Data) -> String? {
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// 2. 标准 UTF-8 编码修复策略 (`UTF8CharsetStrategy`)
public final class UTF8CharsetStrategy: CharsetDetectionStrategyProtocol {
    public let charsetStrategyName: String = "UTF-8 标准解码策略"
    
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

/// 3. 东亚 CJK (GB18030 / BIG5 / Shift-JIS) 历史遗留编码转换策略 (`CJKLegacyCharsetStrategy`)
public final class CJKLegacyCharsetStrategy: CharsetDetectionStrategyProtocol {
    public let charsetStrategyName: String = "CJK (GB18030/BIG5/Shift-JIS) 历史编码转换策略"
    
    public init() {}
    
    public func canHandle(bytes: Data) -> Bool {
        return true // 作为兜底逻辑
    }
    
    public func sanitize(bytes: Data) -> String? {
        let charsetName = CharsetDetector.detectCharset(data: bytes)
        let encoding: String.Encoding
        switch charsetName.uppercased() {
        case "GB18030", "GBK", "GB2312", "CP936":
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        case "BIG5":
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        case "SHIFT-JIS", "SHIFT_JIS":
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)))
        default:
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        }
        
        if let converted = String(data: bytes, encoding: encoding), !converted.isEmpty {
            return converted
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
        if let cached = charsetCache.value(forKey: data) {
            return cached
        }
        
        let detected: String
        for strategy in strategies {
            if strategy.canHandle(bytes: data) {
                if strategy is ASCIIFastPathCharsetStrategy {
                    detected = "ASCII"
                    charsetCache.setValue(detected, forKey: data)
                    return detected
                } else if strategy is UTF8CharsetStrategy {
                    detected = "UTF-8"
                    charsetCache.setValue(detected, forKey: data)
                    return detected
                }
            }
        }
        
        detected = CUnsafeBufferAdapter.withBufferPointer(data) { buffer, count -> String in
            let baseAddress = buffer.assumingMemoryBound(to: UInt8.self)
            if let cStr = ttzip_detect_encoding_fast(baseAddress, count) {
                return String(cString: cStr)
            }
            return "UTF-8"
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

