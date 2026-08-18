// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Read-Write lock interface protocol.
public protocol ReadWriteLockProtocol: Sendable {
    /// Executes closure with shared read lock.
    func read<T>(_ block: () throws -> T) rethrows -> T
    
    /// Executes closure with exclusive write lock.
    func write<T>(_ block: () throws -> T) rethrows -> T
}

/// Cache eviction policies for thread-safe caches.
public enum CacheEvictionPolicy: Equatable, Hashable, Sendable {
    /// Least Recently Used eviction constrained by maximum entry count.
    case lru(maxEntries: Int)
    
    /// Time-to-live expiration eviction in seconds.
    case ttl(seconds: TimeInterval)
    
    /// Memory cost threshold eviction in arbitrary units.
    case cost(maxTotalCost: Int)
}
