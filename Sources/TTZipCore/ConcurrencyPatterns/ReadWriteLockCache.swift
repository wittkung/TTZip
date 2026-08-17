import Foundation

/// 【Pattern 4.2 读写锁 / 线程安全缓存模式】线程安全并发缓存 (Read-Write Lock Cache)
/// 基于 POSIXReadWriteLock 保护的泛型线程安全缓存引擎
/// 内部整合字典与 O(1) 双向链表实现 LRU 淘汰、TTL 时间失效与 Cost 内存开销上限管制
public final class ReadWriteLockCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    
    // MARK: - 内部数据节点定义
    
    private final class CacheNode: @unchecked Sendable {
        let key: Key?
        var value: Value?
        var cost: Int
        var timestamp: Date
        
        var prev: CacheNode?
        var next: CacheNode?
        
        init(key: Key?, value: Value?, cost: Int, timestamp: Date = Date()) {
            self.key = key
            self.value = value
            self.cost = cost
            self.timestamp = timestamp
        }
    }
    
    // MARK: - 存储与并发锁控制
    
    private let lock = POSIXReadWriteLock()
    private var dict: [Key: CacheNode] = [:]
    
    private let head: CacheNode
    private let tail: CacheNode
    
    private var currentTotalCost: Int = 0
    
    // MARK: - 淘汰策略配置
    
    public var maxEntries: Int?
    public var ttlSeconds: TimeInterval?
    public var maxTotalCost: Int?
    
    // MARK: - 初始化方法
    
    public init(maxEntries: Int? = nil, ttlSeconds: TimeInterval? = nil, maxTotalCost: Int? = nil) {
        self.maxEntries = maxEntries
        self.ttlSeconds = ttlSeconds
        self.maxTotalCost = maxTotalCost
        
        let dummyHead = CacheNode(key: nil, value: nil, cost: 0)
        let dummyTail = CacheNode(key: nil, value: nil, cost: 0)
        dummyHead.next = dummyTail
        dummyTail.prev = dummyHead
        self.head = dummyHead
        self.tail = dummyTail
    }
    
    public convenience init(policy: CacheEvictionPolicy) {
        self.init(policies: [policy])
    }
    
    public convenience init(policies: [CacheEvictionPolicy]) {
        var maxEntries: Int? = nil
        var ttlSeconds: TimeInterval? = nil
        var maxTotalCost: Int? = nil
        
        for policy in policies {
            switch policy {
            case .lru(let limit):
                maxEntries = limit
            case .ttl(let seconds):
                ttlSeconds = seconds
            case .cost(let maxCost):
                maxTotalCost = maxCost
            }
        }
        self.init(maxEntries: maxEntries, ttlSeconds: ttlSeconds, maxTotalCost: maxTotalCost)
    }
    
    // MARK: - 公开属性接口
    
    /// 当前缓存中的有效条目总数
    public var count: Int {
        lock.withReadLock { dict.count }
    }
    
    /// 当前缓存所占用的总 Cost 开销
    public var totalCost: Int {
        lock.withReadLock { currentTotalCost }
    }
    
    // MARK: - 缓存读写操作 API
    
    /// 获取指定 Key 的缓存值 (如果命中则自动更新 LRU 顺序与访问时间；若已 TTL 过期则自动清除)
    public func value(forKey key: Key) -> Value? {
        lock.withWriteLock {
            guard let node = dict[key] else {
                return nil
            }
            
            // 校验 TTL 过期判定
            if let ttl = ttlSeconds, Date().timeIntervalSince(node.timestamp) > ttl {
                removeNodeLocked(node)
                return nil
            }
            
            // 命中有效缓存：更新访问时间并移动到 LRU 链表头部 (MRU)
            node.timestamp = Date()
            moveToHeadLocked(node)
            return node.value
        }
    }
    
    /// 仅窥探缓存值 (只读，使用读锁，不更新 LRU 位置，不改变访问时间)
    public func peekValue(forKey key: Key) -> Value? {
        lock.withReadLock {
            guard let node = dict[key] else { return nil }
            if let ttl = ttlSeconds, Date().timeIntervalSince(node.timestamp) > ttl {
                return nil
            }
            return node.value
        }
    }
    
    /// 存储缓存值，支持传入自定义 Cost (内存开销)
    public func setValue(_ value: Value, forKey key: Key, cost: Int = 1) {
        lock.withWriteLock {
            let validCost = max(0, cost)
            
            if let existingNode = dict[key] {
                currentTotalCost += (validCost - existingNode.cost)
                existingNode.value = value
                existingNode.cost = validCost
                existingNode.timestamp = Date()
                moveToHeadLocked(existingNode)
            } else {
                let newNode = CacheNode(key: key, value: value, cost: validCost)
                dict[key] = newNode
                attachToHeadLocked(newNode)
                currentTotalCost += validCost
            }
            
            // 执行自动淘汰逻辑
            evictIfNeededLocked()
        }
    }
    
    /// 移除指定 Key 的缓存
    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        lock.withWriteLock {
            guard let node = dict[key] else { return nil }
            removeNodeLocked(node)
            return node.value
        }
    }
    
    /// 清空全部缓存
    public func removeAll() {
        lock.withWriteLock {
            dict.removeAll()
            head.next = tail
            tail.prev = head
            currentTotalCost = 0
        }
    }

    /// 条件筛选批量清理符合特定谓词的缓存节点
    public func removeAll(where predicate: (Key) -> Bool) {
        lock.withWriteLock {
            var current = head.next
            while let node = current, node !== tail {
                let nextNode = node.next
                if let k = node.key, predicate(k) {
                    removeNodeLocked(node)
                }
                current = nextNode
            }
        }
    }
    
    /// 手动主动清理所有 TTL 已过期的热缓存条目
    public func compact() {
        lock.withWriteLock {
            guard let ttl = ttlSeconds else { return }
            let now = Date()
            var current = head.next
            while let node = current, node !== tail {
                let nextNode = node.next
                if now.timeIntervalSince(node.timestamp) > ttl {
                    removeNodeLocked(node)
                }
                current = nextNode
            }
        }
    }
    
    /// 读锁透传防护执行
    public func read<T>(_ block: () throws -> T) rethrows -> T {
        return try lock.withReadLock(block)
    }
    
    /// 写锁透传防护执行
    public func write<T>(_ block: () throws -> T) rethrows -> T {
        return try lock.withWriteLock(block)
    }
    
    // MARK: - 内部 O(1) 双向链表与 Eviction 算法
    
    private func attachToHeadLocked(_ node: CacheNode) {
        node.next = head.next
        node.prev = head
        head.next?.prev = node
        head.next = node
    }
    
    private func detachLocked(_ node: CacheNode) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        node.prev = nil
        node.next = nil
    }
    
    private func moveToHeadLocked(_ node: CacheNode) {
        detachLocked(node)
        attachToHeadLocked(node)
    }
    
    private func removeNodeLocked(_ node: CacheNode) {
        if let key = node.key {
            dict.removeValue(forKey: key)
        }
        detachLocked(node)
        currentTotalCost -= node.cost
    }
    
    private func evictIfNeededLocked() {
        // 1. LRU 限制淘汰
        if let maxEntries = maxEntries, maxEntries >= 0 {
            while dict.count > maxEntries {
                guard let oldest = tail.prev, oldest !== head else { break }
                removeNodeLocked(oldest)
            }
        }
        
        // 2. Cost 上限限制淘汰
        if let maxCost = maxTotalCost, maxCost >= 0 {
            while currentTotalCost > maxCost {
                guard let oldest = tail.prev, oldest !== head else { break }
                removeNodeLocked(oldest)
            }
        }
    }
}
