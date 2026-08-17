import Foundation
import CTTZipBridge

/// VFS 临时解压缓存池条目元数据
public struct VFSCacheBlockMeta: Sendable {
    public let chunkIndex: Int
    public let rawSize: Int
    public let compressedSize: Int
    public let isDiskSpill: Bool
    public let accessTimestamp: UInt64
}

/// 基于 LZ4 微秒级编解码的两级（RAM-LZ4 + Disk-LZ4 Spill）VFS 临时解压缓存池
public final class VFSLz4CachePool: @unchecked Sendable {
    public static let shared = VFSLz4CachePool()
    
    private let lock = NSLock()
    private let lz4Engine = LZ4LzoEngine()
    private let maxRamBytes: Int
    private var currentRamBytes: Int = 0
    
    /// 内存缓存字典：key 为 "sessionId:chunkIndex" -> 压缩数据 Data
    private var ramCache: [String: Data] = [:]
    /// 磁盘溢出缓存：key -> 临时文件路径
    private var diskSpillCache: [String: URL] = [:]
    /// 访问历史（LRU 维护）：key -> 上次访问时钟
    private var lruAccessTimes: [String: UInt64] = [:]
    /// 块大小记录：key -> 原始未压缩尺寸
    private var rawSizeRecord: [String: Int] = [:]
    
    /// 临时缓存根目录
    private let spillDirectory: URL
    
    public init(maxRamBytes: Int = 128 * 1024 * 1024) { // 默认 128MB RAM 配额
        self.maxRamBytes = maxRamBytes
        let tempBase = FileManager.default.temporaryDirectory
        self.spillDirectory = tempBase.appendingPathComponent("TTZip_VFS_LZ4_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: self.spillDirectory, withIntermediateDirectories: true)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: self.spillDirectory)
    }
    
    /// 存入解压块：经由 LZ4 极速压缩后存入 RAM 缓存（若超配则 LRU 溢出至磁盘）
    public func put(sessionId: String, chunkIndex: Int, rawData: Data, acceleration: Int = 1) {
        guard !rawData.isEmpty else { return }
        let compressed = lz4Engine.compressWithTLS(data: rawData, acceleration: acceleration)
        let key = "\(sessionId):\(chunkIndex)"
        let now = DispatchTime.now().uptimeNanoseconds
        
        lock.lock()
        defer { lock.unlock() }
        
        // 记录原始尺寸与访问时间
        rawSizeRecord[key] = rawData.count
        lruAccessTimes[key] = now
        
        // 检查 RAM 配额并进行 LRU 溢出淘汰
        if currentRamBytes + compressed.count > maxRamBytes {
            evictRamToDiskSpill(requiredSpace: compressed.count)
        }
        
        if currentRamBytes + compressed.count <= maxRamBytes {
            ramCache[key] = compressed
            currentRamBytes += compressed.count
        } else {
            // 直接溢出至磁盘
            writeToSpillDisk(key: key, data: compressed)
        }
    }
    
    /// 读取解压块：优先从 RAM 命中，未命中则从磁盘拉取，经由 LZ4 瞬时（4~8 GB/s）解压还原
    public func get(sessionId: String, chunkIndex: Int) -> Data? {
        let key = "\(sessionId):\(chunkIndex)"
        let now = DispatchTime.now().uptimeNanoseconds
        
        lock.lock()
        lruAccessTimes[key] = now
        let rawHint = rawSizeRecord[key]
        
        if let compressedData = ramCache[key] {
            lock.unlock()
            return lz4Engine.decompress(data: compressedData, originalSizeHint: rawHint)
        }
        
        if let fileURL = diskSpillCache[key] {
            lock.unlock()
            guard let diskCompressed = try? Data(contentsOf: fileURL) else { return nil }
            return lz4Engine.decompress(data: diskCompressed, originalSizeHint: rawHint)
        }
        
        lock.unlock()
        return nil
    }
    
    /// 清理指定会话的全部缓存
    public func clearSession(sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let prefix = "\(sessionId):"
        let keysToRemove = ramCache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            if let data = ramCache.removeValue(forKey: key) {
                currentRamBytes -= data.count
            }
            lruAccessTimes.removeValue(forKey: key)
            rawSizeRecord.removeValue(forKey: key)
        }
        
        let diskKeys = diskSpillCache.keys.filter { $0.hasPrefix(prefix) }
        for key in diskKeys {
            if let url = diskSpillCache.removeValue(forKey: key) {
                try? FileManager.default.removeItem(at: url)
            }
            lruAccessTimes.removeValue(forKey: key)
            rawSizeRecord.removeValue(forKey: key)
        }
    }
    
    /// 统计信息
    public func getStats() -> (ramCount: Int, diskCount: Int, ramBytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (ramCache.count, diskSpillCache.count, currentRamBytes)
    }
    
    // MARK: - Private Eviction & Spill
    
    private func evictRamToDiskSpill(requiredSpace: Int) {
        // 按最后访问时间升序排序（最冷排最前）
        let sortedRamKeys = ramCache.keys.sorted { (k1, k2) -> Bool in
            let t1 = lruAccessTimes[k1] ?? 0
            let t2 = lruAccessTimes[k2] ?? 0
            return t1 < t2
        }
        
        for key in sortedRamKeys {
            guard currentRamBytes + requiredSpace > maxRamBytes else { break }
            if let compressed = ramCache.removeValue(forKey: key) {
                currentRamBytes -= compressed.count
                writeToSpillDisk(key: key, data: compressed)
            }
        }
    }
    
    private func writeToSpillDisk(key: String, data: Data) {
        let safeFilename = key.replacingOccurrences(of: ":", with: "_") + ".lz4"
        let fileURL = spillDirectory.appendingPathComponent(safeFilename)
        try? data.write(to: fileURL)
        diskSpillCache[key] = fileURL
    }
}
