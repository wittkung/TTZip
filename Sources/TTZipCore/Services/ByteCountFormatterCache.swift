import Foundation

/// 线程安全的全局 ByteCountFormatter 缓存服务，避免在列表渲染时高频创建 Formatter
public enum ByteCountFormatterCache {
    public static func string(fromByteCount byteCount: Int64) -> String {
        return ByteCountFormatterFlyweight.shared.string(fromByteCount: byteCount)
    }
}
