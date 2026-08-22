// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Shared byte count formatted string provider with caching.
public final class ByteCountFormatterCache: @unchecked Sendable {
    public static let shared = ByteCountFormatterCache()

    private let lock = NSLock()
    private var stringCache: [Int64: String] = [:]

    private let formatter: ByteCountFormatter = {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useAll]
        fmt.countStyle = .file
        return fmt
    }()

    private let maxCacheSize = 20_000

    private init() {
        for bytes in Int64(0)...Int64(1024) {
            stringCache[bytes] = formatter.string(fromByteCount: bytes)
        }
    }

    public func string(fromByteCount bytes: Int64) -> String {
        let targetBytes = max(0, bytes)

        lock.lock()
        defer { lock.unlock() }
        if let cached = stringCache[targetBytes] {
            return cached
        }

        let formatted = formatter.string(fromByteCount: targetBytes)
        if stringCache.count < maxCacheSize {
            stringCache[targetBytes] = formatted
        }
        return formatted
    }

    public static func string(fromByteCount byteCount: Int64) -> String {
        return shared.string(fromByteCount: byteCount)
    }

    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        stringCache.removeAll(keepingCapacity: false)
        for bytes in Int64(0)...Int64(1024) {
            stringCache[bytes] = formatter.string(fromByteCount: bytes)
        }
    }
}

public typealias ByteCountFormatterFlyweight = ByteCountFormatterCache
