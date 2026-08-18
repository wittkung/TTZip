// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Timestamp throttler for high-frequency progress event throttling.
public final class ProgressTimestampBox: @unchecked Sendable {
    private var lastUpdate = Date.distantPast
    private let lock = NSLock()
    
    public init() {}
    
    public func shouldUpdate(now: Date, interval: TimeInterval = 0.05) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if now.timeIntervalSince(lastUpdate) >= interval {
            lastUpdate = now
            return true
        }
        return false
    }
}

/// Thread-safe string state container.
public final class StateBox: @unchecked Sendable {
    private var fileName: String
    private let lock = NSLock()
    
    public init(initialName: String) {
        self.fileName = initialName
    }
    
    public func update(file: String?) -> String {
        lock.lock()
        defer { lock.unlock() }
        if let file = file, !file.isEmpty {
            self.fileName = file
        }
        return self.fileName
    }
}

/// Thread-safe boolean state container.
public final class StateBoxBool: @unchecked Sendable {
    private var _value: Bool
    private let lock = NSLock()
    
    public init(_ initial: Bool) {
        self._value = initial
    }
    
    public var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}
