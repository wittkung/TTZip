import Foundation
import os

/// 跨格式通用派生 Key 线程安全全局缓存管理器 (Unified Archive Key Cache Manager)
/// 针对 ZIP WinZip AES (100,000 次 PBKDF2 HMAC-SHA1) 和 7z AES (524,288 次 SHA-256) 等高强度迭代派生 Key，
/// 在解压海量分块或多小文件场景下按 `(password + salt + length)` 进行无锁/轻量级锁缓存，消除 CPU 重复导键沉没成本。
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
    
    /// 获取已缓存的派生密钥
    public func getKey(password: String, salt: Data, keyLength: Int) -> Data? {
        let key = CacheKey(password: password, salt: salt, keyLength: keyLength)
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return cache[key]
    }
    
    /// 缓存生成的派生密钥
    public func setKey(password: String, salt: Data, keyLength: Int, derivedKey: Data) {
        let key = CacheKey(password: password, salt: salt, keyLength: keyLength)
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if cache.count >= maxEntries {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = derivedKey
    }
    
    /// 清空所有 Key 缓存
    public func clearCache() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        cache.removeAll(keepingCapacity: false)
    }
}
