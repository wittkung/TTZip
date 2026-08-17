import Foundation

/// 享元模式 (Flyweight Pattern): 共享字节数格式化文本享元池与量化缓存
/// 消除 UI (MillerColumnItemRowView, DiskItemInfo) 及 CLI 列表渲染成千上万个条目时的高频 ByteCountFormatter 分配与重复 String 堆分配。
public final class ByteCountFormatterFlyweight: @unchecked Sendable {
    public static let shared = ByteCountFormatterFlyweight()
    
    private let lock = NSLock()
    private var stringCache: [Int64: String] = [:]
    
    private let formatter: ByteCountFormatter = {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useAll]
        fmt.countStyle = .file
        return fmt
    }()
    
    // 命中与未命中统计数据
    private var internalHitCount: Int = 0
    private var internalMissCount: Int = 0
    
    // 最大缓存条目数量阈值
    private let maxCacheSize = 20_000
    
    private init() {
        // 预热常用小尺寸格式化享元字符串 (0 B 到 1024 B)
        for bytes in Int64(0)...Int64(1024) {
            stringCache[bytes] = formatter.string(fromByteCount: bytes)
        }
        setupMemoryPressureObserver()
    }
    
    private func setupMemoryPressureObserver() {
        #if canImport(AppKit)
        _ = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationWillTerminateNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.clearPool()
        }
        #endif
        
        #if os(macOS) || os(iOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            self?.clearPool()
        }
        source.resume()
        #endif
    }
    
    /// 享元核心：通过字节量化与词典共享池获取格式化文本 (线程安全 100%)
    public func string(fromByteCount bytes: Int64) -> String {
        let targetBytes = max(0, bytes)
        
        lock.lock()
        defer { lock.unlock() }
        if let cached = stringCache[targetBytes] {
            internalHitCount += 1
            return cached
        }
        
        internalMissCount += 1
        let formatted = formatter.string(fromByteCount: targetBytes)
        if stringCache.count < maxCacheSize {
            stringCache[targetBytes] = formatted
        }
        return formatted
    }
    
    /// 量化格式化：针对海量大尺寸文件进行按 64KB/1MB 量化收敛，极大提高 UI 渲染时的享元复用率
    public func quantizedString(fromByteCount bytes: Int64, chunkSize: Int64 = 64 * 1024) -> String {
        let targetBytes = max(0, bytes)
        if targetBytes < 1024 * 1024 {
            return string(fromByteCount: targetBytes)
        }
        let quantized = (targetBytes / chunkSize) * chunkSize
        return string(fromByteCount: quantized)
    }
    
    // MARK: - Stats & Maintenance
    
    /// 统一内存释放接口 (遵从享元池统一 clearPool 规范)
    public func clearPool() {
        clearCache()
    }

    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        stringCache.removeAll(keepingCapacity: false)
        internalHitCount = 0
        internalMissCount = 0
        
        // 重新预热常用小尺寸
        for bytes in Int64(0)...Int64(1024) {
            stringCache[bytes] = formatter.string(fromByteCount: bytes)
        }
    }
    
    public var cacheSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return stringCache.count
    }
    
    public var hitCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return internalHitCount
    }
    
    public var missCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return internalMissCount
    }
    
    public var hitRatio: Double {
        lock.lock()
        defer { lock.unlock() }
        let total = internalHitCount + internalMissCount
        guard total > 0 else { return 0.0 }
        return Double(internalHitCount) / Double(total)
    }
}
