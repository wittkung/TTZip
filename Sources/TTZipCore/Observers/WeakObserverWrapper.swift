// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

private final class WeakBox: @unchecked Sendable {
    weak var value: AnyObject?
    init(_ value: AnyObject?) {
        self.value = value
    }
}

/// Weak observer wrapper preventing retain cycles and memory leaks in observer registries.
public final class WeakObserverWrapper: @unchecked Sendable {
    public weak var observer: AnyObject?
    
    public init(_ observer: AnyObject) {
        self.observer = observer
    }
    
    public var isAlive: Bool {
        return observer != nil
    }
    
    /// Safely invokes closure on target observer.
    public func invoke<Observer>(_ closure: @escaping (Observer) -> Void) {
        guard let target = observer as? Observer else { return }
        closure(target)
    }
}
