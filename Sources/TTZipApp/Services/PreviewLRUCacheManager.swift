// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit

/// Smart LRU preview cache manager providing quota-controlled preview recycling.
public final class PreviewLRUCacheManager: @unchecked Sendable {
    public static let shared = PreviewLRUCacheManager()
    
    private static let quotaDefaultsKey = "PreviewCacheQuotaGB"
    
    /// Dynamic LRU cache limit (GB), defaulting to 10.0 GB.
    public var maxCacheSizeGB: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: Self.quotaDefaultsKey)
            return saved > 0 ? saved : 10.0
        }
        set {
            let clamped = max(0.5, newValue)
            UserDefaults.standard.set(clamped, forKey: Self.quotaDefaultsKey)
            cacheLock.lock()
            evictIfNecessary()
            cacheLock.unlock()
        }
    }
    
    public var maxCacheSizeBytes: Int64 {
        return Int64(maxCacheSizeGB * 1024.0 * 1024.0 * 1024.0)
    }
    
    private let fileManager = FileManager.default
    private let cacheLock = NSLock()
    private let cacheDir: URL
    
    private struct CacheItem {
        let key: String
        let fileURL: URL
        let sizeBytes: Int64
        var lastAccessed: Date
    }
    
    private var items: [String: CacheItem] = [:]
    
    private init() {
        let baseDir = fileManager.temporaryDirectory.appendingPathComponent("TTZipLRUPreviewCache", isDirectory: true)
        try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.cacheDir = baseDir
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(purgeAll),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Retrieves cached preview URL if valid.
    public func cachedURL(forKey key: String) -> URL? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard var item = items[key] else { return nil }
        guard fileManager.fileExists(atPath: item.fileURL.path) else {
            items.removeValue(forKey: key)
            return nil
        }
        
        item.lastAccessed = Date()
        items[key] = item
        return item.fileURL
    }
    
    /// Registers newly generated preview file and triggers LRU eviction.
    public func register(key: String, fileURL: URL) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let item = CacheItem(key: key, fileURL: fileURL, sizeBytes: size, lastAccessed: Date())
        items[key] = item
        
        evictIfNecessary()
    }
    
    /// Generates standard reusable cache file URL path.
    public func targetURL(forKey key: String, filename: String) -> URL {
        let hashDir = cacheDir.appendingPathComponent(key, isDirectory: true)
        try? fileManager.createDirectory(at: hashDir, withIntermediateDirectories: true)
        return hashDir.appendingPathComponent(filename)
    }
    
    /// Evicts oldest files according to LRU order when total size exceeds limit.
    private func evictIfNecessary() {
        var currentTotalSize = items.values.reduce(0) { $0 + $1.sizeBytes }
        guard currentTotalSize > maxCacheSizeBytes else { return }
        
        let sortedItems = items.values.sorted { $0.lastAccessed < $1.lastAccessed }
        for item in sortedItems {
            try? fileManager.removeItem(at: item.fileURL.deletingLastPathComponent())
            items.removeValue(forKey: item.key)
            currentTotalSize -= item.sizeBytes
            if currentTotalSize <= maxCacheSizeBytes {
                break
            }
        }
    }
    
    /// Purges all temporary preview cache files.
    @objc public func purgeAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        items.removeAll()
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
