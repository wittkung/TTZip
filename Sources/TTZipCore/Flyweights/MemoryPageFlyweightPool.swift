import Foundation

/// 内存页尺寸枚举 (4KB 标准系统页 / 16KB Apple Silicon 原生硬件页 / 64KB 高吞吐超级页)
public enum MemoryPageSize: Int, Sendable, CaseIterable {
    case page4K = 4096
    case page16K = 16384
    case page64K = 65536
}

/// 享元页 Buffer 封装结构 (共享内部物理内存页)
public final class MemoryPageBufferFlyweight: @unchecked Sendable {
    public let pointer: UnsafeMutableRawPointer
    public let capacity: Int
    public let pageSize: MemoryPageSize
    internal var inUse: Bool = false
    
    internal init?(pageSize: MemoryPageSize) {
        self.pageSize = pageSize
        self.capacity = pageSize.rawValue
        var rawPtr: UnsafeMutableRawPointer? = nil
        // 使用 posix_memalign 分配 16KB+ 物理页对齐内存 (Zero Heap Allocation reuse)
        let alignment = max(16384, pageSize.rawValue)
        let result = posix_memalign(&rawPtr, alignment, capacity)
        guard result == 0, let validPtr = rawPtr else {
            return nil
        }
        // 初始化置零
        memset(validPtr, 0, capacity)
        self.pointer = validPtr
    }
    
    public static let sharedEmergencyFallback: MemoryPageBufferFlyweight = {
        if let flyweight = MemoryPageBufferFlyweight(pageSize: .page16K) {
            return flyweight
        }
        var rawPtr: UnsafeMutableRawPointer? = nil
        let res = posix_memalign(&rawPtr, 16384, 4096)
        if res == 0, let ptr = rawPtr {
            memset(ptr, 0, 4096)
            return MemoryPageBufferFlyweight(rawPointer: ptr, capacity: 4096, pageSize: .page4K)
        }
        let fallbackPtr = malloc(4096)!
        memset(fallbackPtr, 0, 4096)
        return MemoryPageBufferFlyweight(rawPointer: fallbackPtr, capacity: 4096, pageSize: .page4K)
    }()

    private init(rawPointer: UnsafeMutableRawPointer, capacity: Int, pageSize: MemoryPageSize) {
        self.pointer = rawPointer
        self.capacity = capacity
        self.pageSize = pageSize
        self.inUse = false
    }
    
    deinit {
        free(pointer)
    }
    
    /// 清零 buffer 内容准备下次复用
    public func reset() {
        memset(pointer, 0, capacity)
    }
}

/// 享元模式 (Flyweight Pattern): 内存页 Buffer 借还享元复用池
/// 为流式读写 (SevenZipStoreStreamWriter, ArchiveWriter) 及 mmap / 哈希计算 (HashCalculator) 提供零堆分配的 byte buffer 借还机制。
public final class MemoryPageFlyweightPool: @unchecked Sendable {
    public static let shared = MemoryPageFlyweightPool()
    
    private let lock = NSLock()
    private var pool4K: [MemoryPageBufferFlyweight] = []
    private var pool16K: [MemoryPageBufferFlyweight] = []
    private var pool64K: [MemoryPageBufferFlyweight] = []
    
    // 单个尺寸池最大保留数量
    private let maxPoolCapacity = 64
    
    // 统计指标
    private var totalBorrowed: Int = 0
    private var totalReturned: Int = 0
    private var totalAllocatedCount: Int = 0
    
    private init() {
        // 预热 4 个 4KB 页、4 个 16KB 硬件页与 4 个 64KB 页 buffer 享元
        for _ in 0..<4 {
            if let b4 = MemoryPageBufferFlyweight(pageSize: .page4K) {
                pool4K.append(b4)
                totalAllocatedCount += 1
            }
            if let b16 = MemoryPageBufferFlyweight(pageSize: .page16K) {
                pool16K.append(b16)
                totalAllocatedCount += 1
            }
            if let b64 = MemoryPageBufferFlyweight(pageSize: .page64K) {
                pool64K.append(b64)
                totalAllocatedCount += 1
            }
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
    
    // MARK: - Borrow & Return API
    
    /// 从享元池中借出一个指定页尺寸的 Buffer (零堆分配复用)
    public func borrowBuffer(size: MemoryPageSize = .page64K) -> MemoryPageBufferFlyweight {
        lock.lock()
        totalBorrowed += 1
        
        switch size {
        case .page4K:
            if let existing = pool4K.popLast() {
                existing.inUse = true
                lock.unlock()
                return existing
            }
        case .page16K:
            if let existing = pool16K.popLast() {
                existing.inUse = true
                lock.unlock()
                return existing
            }
        case .page64K:
            if let existing = pool64K.popLast() {
                existing.inUse = true
                lock.unlock()
                return existing
            }
        }
        
        totalAllocatedCount += 1
        lock.unlock()
        
        // 若池子暂无空闲，动态分配新的享元 Buffer
        if let newBuffer = MemoryPageBufferFlyweight(pageSize: size) {
            newBuffer.inUse = true
            return newBuffer
        }
        // 极度罕见的分配失败防御：降级分配 16K/4K
        let fallback = MemoryPageBufferFlyweight(pageSize: .page16K) ?? MemoryPageBufferFlyweight(pageSize: .page4K)
        fallback?.inUse = true
        return fallback ?? MemoryPageBufferFlyweight.sharedEmergencyFallback
    }
    
    /// 归还 Buffer 享元至复用池 (带重复归还防崩溃拦截)
    public func returnBuffer(_ buffer: MemoryPageBufferFlyweight) {
        lock.lock()
        defer { lock.unlock() }
        guard buffer.inUse else { return }
        totalReturned += 1
        buffer.inUse = false
        
        switch buffer.pageSize {
        case .page4K:
            if pool4K.count < maxPoolCapacity {
                pool4K.append(buffer)
            }
        case .page16K:
            if pool16K.count < maxPoolCapacity {
                pool16K.append(buffer)
            }
        case .page64K:
            if pool64K.count < maxPoolCapacity {
                pool64K.append(buffer)
            }
        }
    }
    
    /// RAII / Scope 安全借还 Closure API
    public func withBuffer<T>(
        size: MemoryPageSize = .page64K,
        _ block: (UnsafeMutableRawPointer, Int) throws -> T
    ) rethrows -> T {
        let buffer = borrowBuffer(size: size)
        defer { returnBuffer(buffer) }
        return try block(buffer.pointer, buffer.capacity)
    }
    
    // MARK: - Pool Maintenance & Statistics
    
    /// 清空享元池与计数指标
    public func clearPool() {
        lock.lock()
        defer { lock.unlock() }
        pool4K.removeAll()
        pool16K.removeAll()
        pool64K.removeAll()
        totalBorrowed = 0
        totalReturned = 0
        totalAllocatedCount = 0
    }
    
    /// 享元池实时运行指标
    public var poolStats: (
        idle4K: Int,
        idle16K: Int,
        idle64K: Int,
        totalAllocatedCount: Int,
        borrowCount: Int,
        returnCount: Int,
        reuseRatio: Double
    ) {
        lock.lock()
        defer { lock.unlock() }
        let totalRequests = totalBorrowed
        let reuseRatio = totalRequests > 0 ? Double(totalReturned) / Double(totalRequests) : 0.0
        return (
            idle4K: pool4K.count,
            idle16K: pool16K.count,
            idle64K: pool64K.count,
            totalAllocatedCount: totalAllocatedCount,
            borrowCount: totalBorrowed,
            returnCount: totalReturned,
            reuseRatio: reuseRatio
        )
    }
}
