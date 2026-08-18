// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Throttled event publisher aligning high-frequency engine events to display refresh rates.
public final class ThrottledProgressPublisher: @unchecked Sendable {
    public let intervalNanoseconds: UInt64
    private let lock = NSLock()
    private var lastEmittedTimestamp: UInt64 = 0
    
    /// Initializes throttler with maximum frequency (Hz), defaulting to 60.0Hz (~16.6ms).
    public init(maxFrequencyHz: Double = 60.0) {
        let clampedHz = max(1.0, min(120.0, maxFrequencyHz))
        self.intervalNanoseconds = UInt64(1_000_000_000.0 / clampedHz)
    }
    
    /// Evaluates whether current timestamp qualifies for frame emission.
    public func shouldEmit(now: UInt64 = DispatchTime.now().uptimeNanoseconds) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if lastEmittedTimestamp == 0 || (now >= lastEmittedTimestamp && (now - lastEmittedTimestamp) >= intervalNanoseconds) {
            lastEmittedTimestamp = now
            return true
        }
        return false
    }
    
    /// Forces emission timestamp update.
    public func forceEmit(now: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        lock.lock()
        defer { lock.unlock() }
        lastEmittedTimestamp = now
    }
    
    /// Resets throttler state.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastEmittedTimestamp = 0
    }
}
