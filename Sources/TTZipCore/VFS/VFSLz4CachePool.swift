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
        lock.lock()
        rawSizeCache[key] = rawData.count
        lock.unlock()
        
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
        lock.lock()
        let expectedSize = rawSizeCache[key] ?? (1024 * 1024)
        lock.unlock()
        
        if let handle = nativeHandle {
            return CUnsafeBufferAdapter.withCString(sessionId) { cSess -> Data? in
                guard let cSess = cSess else { return nil }
                var outputData = Data(count: max(expectedSize, 64 * 1024))
                var outLen: Int = 0
                
                let status = outputData.withUnsafeMutableBytes { outBuf -> CTTZipBridge.TTZipStatus in
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
                
                if status == TTZIP_STATUS_OK && outLen > 0 {
                    outputData.count = outLen
                    return outputData
                }
                return nil
            }
        }
        
        return nil
    }
    
    /// Clears all cached chunks associated with a specific session ID.
    public func clearSession(sessionId: String) {
        lock.lock()
        let prefix = "\(sessionId):"
        rawSizeCache = rawSizeCache.filter { !$0.key.hasPrefix(prefix) }
        lock.unlock()
        
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
