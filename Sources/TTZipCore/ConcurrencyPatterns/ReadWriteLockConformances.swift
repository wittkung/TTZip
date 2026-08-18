// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Protocol for cacheable components with read-write lock synchronization.
public protocol ReadWriteLockCacheable: Sendable {
    /// Human-readable cache identifier.
    var cacheName: String { get }
    
    /// Current count of items stored in cache.
    var cacheEntryCount: Int { get }
    
    /// Evicts all cached entries.
    func purgeCache()
}

// MARK: - ArchiveInspectionCacheProxy Conformance

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

// MARK: - CharsetDetectionStrategyContext Conformance

extension CharsetDetectionStrategyContext: ReadWriteLockCacheable {
    public var cacheName: String {
        return "CharsetDetector (Encoding & Sanitization Cache)"
    }
    
    public var cacheEntryCount: Int {
        return 0
    }
    
    public func purgeCache() {
        clearCache()
    }
}

// MARK: - PresetManager Conformance

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
