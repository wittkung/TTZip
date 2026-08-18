// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import os

/// Thread-safe global cache manager for computationally heavy derived keys (PBKDF2 HMAC-SHA1, SHA-256 KDF).
///
/// Caches derived key material keyed by `(password + salt + length)` to eliminate repeated KDF derivations in multi-file extraction workloads.
public final class ArchiveKeyCacheManager: @unchecked Sendable {
    public static let shared = ArchiveKeyCacheManager()
    
    private struct CacheKey: Hashable {
        let password: String
        let salt: Data
        let keyLength: Int
    }
    
    private var cache: [CacheKey: Data] = [:]
    private var lock = os_unfair_lock_s()
    private let maxEntries: Int = 4090
    
    private init() {}
    
    /// Retrieves cached derived key for given credentials.
    public func getKey(password: String, salt: Data, keyLength: Int) -> Data? {
        let key = CacheKey(password: password, salt: salt, keyLength: keyLength)
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return cache[key]
    }
    
    /// Caches derived key material.
    public func setKey(password: String, salt: Data, keyLength: Int, derivedKey: Data) {
        let key = CacheKey(password: password, salt: salt, keyLength: keyLength)
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if cache.count >= maxEntries {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = derivedKey
    }
    
    /// Clears all cached key material.
    public func clearCache() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        cache.removeAll(keepingCapacity: false)
    }
}
