// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Metadata record for a cached chunk in the VFS decompression cache pool.
public struct VFSCacheBlockMeta: Sendable {
    public let chunkIndex: Int
    public let rawSize: Int
    public let compressedSize: Int
    public let isDiskSpill: Bool
    public let accessTimestamp: UInt64
}

/// High-throughput two-tier (RAM-LZ4 + Disk-LZ4 Spill) VFS decompression cache pool leveraging microsecond LZ4 codec.
public final class VFSLz4CachePool: @unchecked Sendable {
    public static let shared = VFSLz4CachePool()
    
    private let lock = NSLock()
    private let lz4Engine = LZ4LzoEngine()
    private let maxRamBytes: Int
    private var currentRamBytes: Int = 0
    
    /// Memory cache: "sessionId:chunkIndex" -> LZ4 compressed Data
    private var ramCache: [String: Data] = [:]
    /// Disk spill cache: "sessionId:chunkIndex" -> local temp URL
    private var diskSpillCache: [String: URL] = [:]
    /// LRU access timestamps: "sessionId:chunkIndex" -> timestamp
    private var lruAccessTimes: [String: UInt64] = [:]
    /// Uncompressed raw block sizes: "sessionId:chunkIndex" -> byte size
    private var rawSizeRecord: [String: Int] = [:]
    
    /// Root directory for disk spill cache
    private let spillDirectory: URL
    
    public init(maxRamBytes: Int = 128 * 1024 * 1024) {
        self.maxRamBytes = maxRamBytes
        let tempBase = FileManager.default.temporaryDirectory
        self.spillDirectory = tempBase.appendingPathComponent("TTZip_VFS_LZ4_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: self.spillDirectory, withIntermediateDirectories: true)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: self.spillDirectory)
    }
    
    /// Stores decompressed chunk: compresses via LZ4 and places in RAM cache (spills to disk via LRU on budget overflow).
    public func put(sessionId: String, chunkIndex: Int, rawData: Data, acceleration: Int = 1) {
        guard !rawData.isEmpty else { return }
        let compressed = lz4Engine.compressWithTLS(data: rawData, acceleration: acceleration)
        let key = "\(sessionId):\(chunkIndex)"
        let now = DispatchTime.now().uptimeNanoseconds
        
        lock.lock()
        defer { lock.unlock() }
        
        rawSizeRecord[key] = rawData.count
        lruAccessTimes[key] = now
        
        if currentRamBytes + compressed.count > maxRamBytes {
            evictRamToDiskSpill(requiredSpace: compressed.count)
        }
        
        if currentRamBytes + compressed.count <= maxRamBytes {
            ramCache[key] = compressed
            currentRamBytes += compressed.count
        } else {
            writeToSpillDisk(key: key, data: compressed)
        }
    }
    
    /// Retrieves decompressed chunk: returns from RAM if present, otherwise reads from disk spill and decompresses via LZ4.
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
    
    /// Clears all cached chunks associated with a specific session ID.
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
    
    /// Returns pool allocation and occupancy metrics.
    public func getStats() -> (ramCount: Int, diskCount: Int, ramBytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (ramCache.count, diskSpillCache.count, currentRamBytes)
    }
    
    // MARK: - Private Eviction & Spill
    
    private func evictRamToDiskSpill(requiredSpace: Int) {
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
