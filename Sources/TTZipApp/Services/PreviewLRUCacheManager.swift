import Foundation
import AppKit

/// 智能 LRU 预览缓存管理器 (在应用生命周期内提供配额控制的极速预览复用)
public final class PreviewLRUCacheManager: @unchecked Sendable {
    public static let shared = PreviewLRUCacheManager()
    
    private static let quotaDefaultsKey = "PreviewCacheQuotaGB"
    
    /// 动态 LRU 缓存上限 (单位：GB)，默认 10.0 GB，支持用户在设置中自定义调节
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
    
    /// 获取已缓存的预览 URL (若存在并有效则更新访问时间)
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
    
    /// 注册新的预览文件，并触发 LRU 容量超限自动清理
    public func register(key: String, fileURL: URL) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let item = CacheItem(key: key, fileURL: fileURL, sizeBytes: size, lastAccessed: Date())
        items[key] = item
        
        evictIfNecessary()
    }
    
    /// 生成标准可复用的缓存文件 URL 目标路径
    public func targetURL(forKey key: String, filename: String) -> URL {
        let hashDir = cacheDir.appendingPathComponent(key, isDirectory: true)
        try? fileManager.createDirectory(at: hashDir, withIntermediateDirectories: true)
        return hashDir.appendingPathComponent(filename)
    }
    
    /// 超出 maxCacheSizeBytes 时按 LRU 顺序淘汰旧文件
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
    
    /// 应用退出或手动调用时清空全部临时预览缓存
    @objc public func purgeAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        items.removeAll()
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
