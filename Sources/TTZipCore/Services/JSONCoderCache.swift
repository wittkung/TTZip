import Foundation

/// 线程安全的全局 JSONEncoder 与 JSONDecoder 缓存服务，避免高频 JSON 编解码场景下重新初始化 Coder 带来的性能与堆内存碎片损耗
public final class JSONCoderCache: @unchecked Sendable {
    public static let shared = JSONCoderCache()
    
    public let encoder = JSONEncoder()
    public let prettyEncoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        return enc
    }()
    public let decoder = JSONDecoder()
    
    private init() {}
}
