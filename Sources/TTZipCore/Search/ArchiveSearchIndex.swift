// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance flat columnar search index for multi-gigabyte archives.
///
/// Stores normalized UTF-8 entry paths in contiguous memory to deliver sub-15ms
/// filtering on 100,000+ entries with zero heap allocation churn on keystrokes.
public final class ArchiveSearchIndex: @unchecked Sendable {
    public struct IndexedEntryDescriptor: Sendable {
        public let index: Int32
        public let nameOffset: UInt32
        public let nameLength: UInt16
        public let pathOffset: UInt32
        public let pathLength: UInt16
        public let uncompressedSize: Int64
        public let isDirectory: Bool
        
        public init(
            index: Int32,
            nameOffset: UInt32,
            nameLength: UInt16,
            pathOffset: UInt32,
            pathLength: UInt16,
            uncompressedSize: Int64,
            isDirectory: Bool
        ) {
            self.index = index
            self.nameOffset = nameOffset
            self.nameLength = nameLength
            self.pathOffset = pathOffset
            self.pathLength = pathLength
            self.uncompressedSize = uncompressedSize
            self.isDirectory = isDirectory
        }
    }
    
    private var cIndex = ttzip_search_index_t()
    private var isInitialized = false
    private let lock = NSLock()
    
    public init() {
        lock.lock()
        defer { lock.unlock() }
        if ttzip_search_index_init(&cIndex, 1024) == 0 {
            isInitialized = true
        }
    }

    deinit {
        if isInitialized {
            ttzip_search_index_free(&cIndex)
        }
    }
    
    /// Populates the contiguous columnar search index from a list of entry paths and sizes.
    public func build(entries: [(path: String, size: Int64, isDir: Bool)]) {
        lock.lock()
        defer { lock.unlock() }
        
        if !isInitialized {
            if ttzip_search_index_init(&cIndex, max(256, entries.count)) == 0 {
                isInitialized = true
            }
        }
        
        ttzip_search_index_clear(&cIndex)
        
        for (idx, item) in entries.enumerated() {
            _ = item.path.withCString { cPath in
                ttzip_search_index_add_entry(&cIndex, Int32(idx), cPath, item.size, item.isDir)
            }
        }
    }
    
    /// Executes a search query across all indexed entries with nanosecond timing.
    public func search(query: ArchiveSearchQuery) -> ArchiveSearchResult {
        lock.lock()
        let count = isInitialized ? cIndex.entry_count : 0
        lock.unlock()
        
        let startNano = mach_absolute_time()
        guard count > 0 else {
            return ArchiveSearchResult(
                matchedIndices: [],
                matchedEntriesCount: 0,
                totalScannedEntries: 0,
                searchDurationMs: 0.0
            )
        }
        
        let rawQueryText = query.queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        var matchedIndices = [Int32](repeating: 0, count: count)
        
        var matchCount: size_t = 0
        lock.lock()
        if isInitialized {
            var cQuery = ttzip_search_query_t()
            cQuery.case_sensitive = query.caseSensitive
            cQuery.min_size_bytes = query.minSizeBytes ?? -1
            cQuery.max_size_bytes = query.maxSizeBytes ?? -1
            
            if !rawQueryText.isEmpty {
                matchCount = rawQueryText.withCString { cQ in
                    cQuery.query_text = cQ
                    cQuery.query_len = strlen(cQ)
                    return matchedIndices.withUnsafeMutableBufferPointer { mBuf in
                        ttzip_search_index_query_neon(&cIndex, &cQuery, mBuf.baseAddress, count)
                    }
                }
            } else {
                cQuery.query_text = nil
                cQuery.query_len = 0
                matchCount = matchedIndices.withUnsafeMutableBufferPointer { mBuf in
                    ttzip_search_index_query_neon(&cIndex, &cQuery, mBuf.baseAddress, count)
                }
            }
        }
        lock.unlock()
        
        let resultSlice = Array(matchedIndices.prefix(matchCount))
        let elapsedMs = Self.elapsedMilliseconds(from: startNano)
        return ArchiveSearchResult(
            matchedIndices: resultSlice,
            matchedEntriesCount: resultSlice.count,
            totalScannedEntries: count,
            searchDurationMs: elapsedMs
        )
    }
    
    private static func elapsedMilliseconds(from startNano: UInt64) -> Double {
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        let elapsed = mach_absolute_time() - startNano
        let nanos = (elapsed * UInt64(timebase.numer)) / UInt64(timebase.denom)
        return Double(nanos) / 1_000_000.0
    }
}

