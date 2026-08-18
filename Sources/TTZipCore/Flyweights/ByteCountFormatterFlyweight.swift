// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Flyweight Pattern: Shared byte count formatted string pool with quantized caching.
///
/// Eliminates high-frequency `ByteCountFormatter` allocations and redundant string heap
/// churn when rendering large directories in UI and CLI lists.
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
    
    private var internalHitCount: Int = 0
    private var internalMissCount: Int = 0
    private let maxCacheSize = 20_000
    
    private init() {
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
    
    /// Formats byte count using quantized cache and dictionary pool (100% thread-safe).
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
    
    /// Quantized formatting: rounds large byte counts to 64KB/1MB boundaries for higher hit ratios.
    public func quantizedString(fromByteCount bytes: Int64, chunkSize: Int64 = 64 * 1024) -> String {
        let targetBytes = max(0, bytes)
        if targetBytes < 1024 * 1024 {
            return string(fromByteCount: targetBytes)
        }
        let quantized = (targetBytes / chunkSize) * chunkSize
        return string(fromByteCount: quantized)
    }
    
    // MARK: - Stats & Maintenance
    
    public func clearPool() {
        clearCache()
    }

    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        stringCache.removeAll(keepingCapacity: false)
        internalHitCount = 0
        internalMissCount = 0
        
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
