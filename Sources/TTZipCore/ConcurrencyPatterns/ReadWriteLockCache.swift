// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Thread-safe generic in-memory cache protected by POSIX read-write locks.
///
/// Implements dual hash-map and doubly-linked list for O(1) LRU eviction, TTL expiry, and cost capacity limits.
public final class ReadWriteLockCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    
    // MARK: - Internal Node Structure
    
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
    
    // MARK: - Storage and Lock
    
    private let lock = POSIXReadWriteLock()
    private var dict: [Key: CacheNode] = [:]
    
    private let head: CacheNode
    private let tail: CacheNode
    
    private var currentTotalCost: Int = 0
    
    // MARK: - Eviction Configuration
    
    public var maxEntries: Int?
    public var ttlSeconds: TimeInterval?
    public var maxTotalCost: Int?
    
    // MARK: - Initialization
    
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
    
    // MARK: - Public State
    
    public var count: Int {
        lock.withReadLock { dict.count }
    }
    
    public var totalCost: Int {
        lock.withReadLock { currentTotalCost }
    }
    
    // MARK: - Cache Access API
    
    /// Retrieves value for key, promoting node to head and checking TTL expiration.
    public func value(forKey key: Key) -> Value? {
        lock.withWriteLock {
            guard let node = dict[key] else {
                return nil
            }
            
            if let ttl = ttlSeconds, Date().timeIntervalSince(node.timestamp) > ttl {
                removeNodeLocked(node)
                return nil
            }
            
            node.timestamp = Date()
            moveToHeadLocked(node)
            return node.value
        }
    }
    
    /// Inspects value for key using read lock without modifying LRU order or access timestamps.
    public func peekValue(forKey key: Key) -> Value? {
        lock.withReadLock {
            guard let node = dict[key] else { return nil }
            if let ttl = ttlSeconds, Date().timeIntervalSince(node.timestamp) > ttl {
                return nil
            }
            return node.value
        }
    }
    
    /// Stores value for key with custom memory cost weighting.
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
            
            evictIfNeededLocked()
        }
    }
    
    /// Removes and returns value for key.
    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        lock.withWriteLock {
            guard let node = dict[key] else { return nil }
            removeNodeLocked(node)
            return node.value
        }
    }
    
    /// Evicts all cached entries.
    public func removeAll() {
        lock.withWriteLock {
            dict.removeAll()
            head.next = tail
            tail.prev = head
            currentTotalCost = 0
        }
    }

    /// Evicts all entries matching the specified predicate.
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
    
    /// Manually purges expired TTL entries from the cache.
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
    
    public func read<T>(_ block: () throws -> T) rethrows -> T {
        return try lock.withReadLock(block)
    }
    
    public func write<T>(_ block: () throws -> T) rethrows -> T {
        return try lock.withWriteLock(block)
    }
    
    // MARK: - Internal Doubly-Linked List & Eviction Algorithms
    
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
        if let maxEntries = maxEntries, maxEntries >= 0 {
            while dict.count > maxEntries {
                guard let oldest = tail.prev, oldest !== head else { break }
                removeNodeLocked(oldest)
            }
        }
        
        if let maxCost = maxTotalCost, maxCost >= 0 {
            while currentTotalCost > maxCost {
                guard let oldest = tail.prev, oldest !== head else { break }
                removeNodeLocked(oldest)
            }
        }
    }
}
