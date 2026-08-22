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

// MARK: - Date Formatter Cache

//
//


/// Thread-safe global DateFormatter cache avoiding redundant instance allocations during UI rendering.
public final class DateFormatterCache: @unchecked Sendable {
    public static let shared = DateFormatterCache()
    
    private var formatters: [String: DateFormatter] = [:]
    private let lock = NSLock()
    
    private let shortDateTimeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()
    
    private init() {}
    
    public func string(fromShortDateTime date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return shortDateTimeFormatter.string(from: date)
    }
    
    public func string(from date: Date, format: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter = getFormatter(for: format)
        return formatter.string(from: date)
    }
    
    public func date(from string: String, format: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let formatter = getFormatter(for: format)
        return formatter.date(from: string)
    }
    
    public func formatter(for format: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        return getFormatter(for: format)
    }
    
    private func getFormatter(for format: String) -> DateFormatter {
        if let existing = formatters[format] {
            return existing
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
}
