// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// Metadata record for a cached chunk in the VFS decompression cache pool.
public struct VFSCacheBlockMeta: Sendable {
    public let chunkIndex: Int
    public let rawSize: Int
    public let compressedSize: Int
    public let isDiskSpill: Bool
    public let accessTimestamp: UInt64
    
    public init(chunkIndex: Int, rawSize: Int, compressedSize: Int, isDiskSpill: Bool, accessTimestamp: UInt64) {
        self.chunkIndex = chunkIndex
        self.rawSize = rawSize
        self.compressedSize = compressedSize
        self.isDiskSpill = isDiskSpill
        self.accessTimestamp = accessTimestamp
    }
}

/// High-throughput two-tier (RAM-LZ4 + Disk-LZ4 Spill) VFS decompression cache pool leveraging 16-way sharded microsecond LZ4 codec.
public final class VFSLz4CachePool: @unchecked Sendable {
    public static let shared = VFSLz4CachePool()
    
    private let nativeHandle: OpaquePointer?
    private let maxRamBytes: Int
    private let spillDirectory: URL
    private let fallbackEngine = LZ4LzoEngine()
    private let lock = NSLock()
    private var rawSizeCache: [String: Int] = [:]
    
    public init(maxRamBytes: Int = 128 * 1024 * 1024) {
        self.maxRamBytes = maxRamBytes
        let tempBase = FileManager.default.temporaryDirectory
        self.spillDirectory = tempBase.appendingPathComponent("TTZip_VFS_LZ4_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: self.spillDirectory, withIntermediateDirectories: true)
        
        let spillPath = self.spillDirectory.path
        self.nativeHandle = CUnsafeBufferAdapter.withCString(spillPath) { cSpill in
            ttzip_rust_vfs_cache_new(maxRamBytes, cSpill)
        }
    }
    
    deinit {
        if let handle = nativeHandle {
            ttzip_rust_vfs_cache_free(handle)
        }
        try? FileManager.default.removeItem(at: self.spillDirectory)
    }
    
    /// Stores decompressed chunk: compresses via LZ4 and places in RAM cache (spills to disk via LRU on budget overflow).
    public func put(sessionId: String, chunkIndex: Int, rawData: Data, acceleration: Int = 1) {
        guard !rawData.isEmpty else { return }
        let key = "\(sessionId):\(chunkIndex)"
        lock.withLock {
            rawSizeCache[key] = rawData.count
        }
        
        if let handle = nativeHandle {
            CUnsafeBufferAdapter.withCString(sessionId) { cSess in
                guard let cSess = cSess else { return }
                rawData.withUnsafeBytes { rawBuffer in
                    guard let basePtr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    _ = ttzip_rust_vfs_cache_put(
                        handle,
                        cSess,
                        UInt64(chunkIndex),
                        basePtr,
                        rawBuffer.count,
                        Int32(acceleration)
                    )
                }
            }
        }
    }
    
    /// Retrieves decompressed chunk: returns from RAM if present, otherwise reads from disk spill and decompresses via LZ4.
    public func get(sessionId: String, chunkIndex: Int) -> Data? {
        let key = "\(sessionId):\(chunkIndex)"
        let expectedSize = lock.withLock {
            rawSizeCache[key] ?? (1024 * 1024)
        }
        
        if let handle = nativeHandle {
            return CUnsafeBufferAdapter.withCString(sessionId) { cSess -> Data? in
                guard let cSess = cSess else { return nil }
                var outputData = Data(count: max(expectedSize, 64 * 1024))
                var outLen: Int = 0
                
                var status = outputData.withUnsafeMutableBytes { outBuf -> CTTZipBridge.TTZipStatus in
                    guard let basePtr = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return TTZIP_STATUS_ERR_INVALID_PARAM
                    }
                    return ttzip_rust_vfs_cache_get(
                        handle,
                        cSess,
                        UInt64(chunkIndex),
                        basePtr,
                        outBuf.count,
                        &outLen
                    )
                }
                
                // Retry if initial capacity was smaller than decompressed chunk
                if status == TTZIP_STATUS_ERR_INVALID_PARAM && outputData.count < 32 * 1024 * 1024 {
                    outputData = Data(count: 32 * 1024 * 1024)
                    status = outputData.withUnsafeMutableBytes { outBuf -> CTTZipBridge.TTZipStatus in
                        guard let basePtr = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return TTZIP_STATUS_ERR_INVALID_PARAM
                        }
                        return ttzip_rust_vfs_cache_get(
                            handle,
                            cSess,
                            UInt64(chunkIndex),
                            basePtr,
                            outBuf.count,
                            &outLen
                        )
                    }
                }
                
                if status == TTZIP_STATUS_OK && outLen > 0 {
                    outputData.count = outLen
                    return outputData
                }
                return nil
            }
        }
        
        return nil
    }
    
    /// Checks if a given chunk is present in the cache pool.
    public func contains(sessionId: String, chunkIndex: Int) -> Bool {
        return get(sessionId: sessionId, chunkIndex: chunkIndex) != nil
    }
    
    /// Prefetches a chunk into cache if missing using the provided asynchronous data loader.
    public func prefetchChunk(sessionId: String, chunkIndex: Int, provider: @escaping @Sendable () async throws -> Data) async {
        let key = "\(sessionId):\(chunkIndex)"
        let isCached = lock.withLock {
            rawSizeCache[key] != nil
        }
        guard !isCached else { return }
        
        if let data = try? await provider(), !data.isEmpty {
            put(sessionId: sessionId, chunkIndex: chunkIndex, rawData: data)
        }
    }
    
    /// Prefetches multiple contiguous or strided chunks concurrently.
    public func prefetchChunks(sessionId: String, indices: [Int], provider: @escaping @Sendable (Int) async throws -> Data) async {
        await withTaskGroup(of: Void.self) { group in
            for idx in indices {
                group.addTask {
                    await self.prefetchChunk(sessionId: sessionId, chunkIndex: idx) {
                        try await provider(idx)
                    }
                }
            }
        }
    }
    
    /// Stores entry preview/payload data in VFS session cache.
    public func cacheEntry(archivePath: String, entryPath: String, data: Data) {
        let chunkIdx = Int(truncatingIfNeeded: UInt64(bitPattern: Int64(entryPath.hashValue)) & 0x7FFF_FFFF_FFFF_FFFF)
        put(sessionId: archivePath, chunkIndex: chunkIdx, rawData: data)
    }
    
    /// Retrieves cached entry preview/payload data from VFS session cache.
    public func getCachedEntry(archivePath: String, entryPath: String) -> Data? {
        let chunkIdx = Int(truncatingIfNeeded: UInt64(bitPattern: Int64(entryPath.hashValue)) & 0x7FFF_FFFF_FFFF_FFFF)
        return get(sessionId: archivePath, chunkIndex: chunkIdx)
    }
    
    /// Clears all cached chunks associated with a specific session ID.
    public func clearSession(sessionId: String) {
        let prefix = "\(sessionId):"
        lock.withLock {
            rawSizeCache = rawSizeCache.filter { !$0.key.hasPrefix(prefix) }
        }
        
        if let handle = nativeHandle {
            CUnsafeBufferAdapter.withCString(sessionId) { cSess in
                guard let cSess = cSess else { return }
                _ = ttzip_rust_vfs_cache_clear_session(handle, cSess)
            }
        }
    }
    
    /// Returns pool allocation and occupancy metrics.
    public func getStats() -> (ramCount: Int, diskCount: Int, ramBytes: Int) {
        if let handle = nativeHandle {
            var rCnt: Int = 0
            var dCnt: Int = 0
            var rBytes: Int = 0
            ttzip_rust_vfs_cache_get_stats(handle, &rCnt, &dCnt, &rBytes)
            return (rCnt, dCnt, rBytes)
        }
        return (0, 0, 0)
    }
}
