import Foundation

/// 【Pattern 4.2 读写锁 / 线程安全缓存模式】读写锁抽象接口 (Read-Write Lock Protocol)
/// 定义 Reader-Writer 锁规范：允许多 reader 并发无阻断读取，写操作独占互斥
public protocol ReadWriteLockProtocol: Sendable {
    /// 执行读锁保护的代码块（多 reader 并发执行）
    func read<T>(_ block: () throws -> T) rethrows -> T
    
    /// 执行写锁保护的代码块（单 writer 独占执行）
    func write<T>(_ block: () throws -> T) rethrows -> T
}

/// 【Pattern 4.2 读写锁 / 线程安全缓存模式】缓存淘汰策略 (Cache Eviction Policy)
public enum CacheEvictionPolicy: Equatable, Hashable, Sendable {
    /// LRU (Least Recently Used) 最久未访问淘汰，限制最大条目数量
    case lru(maxEntries: Int)
    
    /// TTL (Time to Live) 生存时间过期淘汰，超时自动失效 (单位: 秒)
    case ttl(seconds: TimeInterval)
    
    /// Cost (Memory Cost) 内存开销上限淘汰，总 Cost 超过上限时淘汰最久未访问条目
    case cost(maxTotalCost: Int)
}
