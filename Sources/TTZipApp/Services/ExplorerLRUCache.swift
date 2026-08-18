// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import os

/// Thread-safe generic LRU (Least Recently Used) cache container.
///
/// Implemented via a doubly-linked list with a hash map guarded by `os_unfair_lock` for nanosecond access.
public final class ExplorerLRUCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    public let capacity: Int
    
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private var map: [Key: Node] = [:]
    private var head: Node? // MRU (Most Recently Used)
    private var tail: Node? // LRU (Least Recently Used)
    private var lock = os_unfair_lock_s()
    
    public init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }
    
    public var count: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return map.count
    }
    
    public func get(_ key: Key) -> Value? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard let node = map[key] else { return nil }
        moveToHead(node)
        return node.value
    }
    
    public func set(_ key: Key, value: Value) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if let existing = map[key] {
            existing.value = value
            moveToHead(existing)
            return
        }
        
        let newNode = Node(key: key, value: value)
        map[key] = newNode
        addToHead(newNode)
        
        if map.count > capacity {
            if let lruNode = removeTail() {
                map.removeValue(forKey: lruNode.key)
            }
        }
    }
    
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard let node = map.removeValue(forKey: key) else { return nil }
        removeNode(node)
        return node.value
    }
    
    public func removeAll() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        map.removeAll(keepingCapacity: true)
        head = nil
        tail = nil
    }
    
    // MARK: - Private Doubly-Linked List Operations (Under Lock)
    
    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: Node) {
        let prev = node.prev
        let next = node.next
        
        if let p = prev {
            p.next = next
        } else {
            head = next
        }
        
        if let n = next {
            n.prev = prev
        } else {
            tail = prev
        }
        
        node.prev = nil
        node.next = nil
    }
    
    private func moveToHead(_ node: Node) {
        guard head !== node else { return }
        removeNode(node)
        addToHead(node)
    }
    
    private func removeTail() -> Node? {
        guard let t = tail else { return nil }
        removeNode(t)
        return t
    }
}
