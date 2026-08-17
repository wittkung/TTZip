import Foundation
import CTTZipBridge

/// 字符集检测与乱码修复引擎
public enum CharsetDetector {
    /// 自动检测传入 Data 数据的字符编码格式名称（如 GB18030, UTF-8）
    public static func detectCharset(data: Data) -> String {
        return CharsetDetectionStrategyContext.shared.detectCharset(data: data)
    }
    
    /// 尝试将原始字节文件名修复为正确无乱码的 Swift String (结合 CharsetDetectionStrategyContext)
    public static func sanitizeFilename(bytes: Data) -> String {
        return CharsetDetectionStrategyContext.shared.sanitizeFilename(bytes: bytes)
    }
    
    /// 清空字符集识别与文件名修复缓存
    public static func clearCache() {
        CharsetDetectionStrategyContext.shared.clearCache()
    }
}

