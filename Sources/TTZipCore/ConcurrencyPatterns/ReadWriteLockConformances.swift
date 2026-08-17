import Foundation

/// 【Pattern 4.2 读写锁 / 线程安全缓存模式】读写锁缓存接入协议 (Read-Write Lock Cacheable Protocol)
/// 统一规范 TTZip Core 代理与关键服务组件的并发缓存监控、清理与指标导出
public protocol ReadWriteLockCacheable: Sendable {
    /// 缓存名称/标识
    var cacheName: String { get }
    
    /// 当前缓存条目总数
    var cacheEntryCount: Int { get }
    
    /// 清空热内存缓存
    func purgeCache()
}

// MARK: - ArchiveInspectionCacheProxy ReadWriteLockCacheable 适配

extension ArchiveInspectionCacheProxy: ReadWriteLockCacheable {
    public var cacheName: String {
        return "ArchiveInspectionCacheProxy (Metadata & Tree Cache)"
    }
    
    public var cacheEntryCount: Int {
        return cachedItemCount
    }
    
    public func purgeCache() {
        clearCache()
    }
}

// MARK: - CharsetDetectionStrategyContext ReadWriteLockCacheable 适配

extension CharsetDetectionStrategyContext: ReadWriteLockCacheable {
    public var cacheName: String {
        return "CharsetDetector (Encoding & Sanitization Cache)"
    }
    
    public var cacheEntryCount: Int {
        return 0 // CharsetDetector 在内部单例 Context 中托管 ReadWriteLockCache
    }
    
    public func purgeCache() {
        clearCache()
    }
}

// MARK: - PresetManager ReadWriteLockCacheable 适配

extension PresetManager: ReadWriteLockCacheable {
    public var cacheName: String {
        return "PresetManager (User Compression Presets Cache)"
    }
    
    public var cacheEntryCount: Int {
        return presets.count
    }
    
    public func purgeCache() {
        loadPresets()
    }
}
