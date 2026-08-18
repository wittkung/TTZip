// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Thread-safe high-throughput progress broadcaster dispatching real-time telemetry metrics.
public final class ArchiveProgressBroadcaster: @unchecked Sendable {
    public static let shared = ArchiveProgressBroadcaster()
    
    private var observers: [WeakObserverWrapper] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// Registers a progress observer with optional dispatch queue specification.
    public func addObserver(_ observer: ArchiveProgressObserverProtocol, dispatchQueue: DispatchQueue? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll { !$0.isAlive }
        
        if let idx = observers.firstIndex(where: { $0.observer === observer }) {
            observers[idx] = WeakObserverWrapper(observer, dispatchQueue: dispatchQueue)
        } else {
            observers.append(WeakObserverWrapper(observer, dispatchQueue: dispatchQueue))
        }
    }
    
    /// Unregisters a progress observer.
    public func removeObserver(_ observer: ArchiveProgressObserverProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll { $0.observer === observer || !$0.isAlive }
    }
    
    /// Removes all registered observers.
    public func removeAllObservers() {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll()
    }
    
    /// Count of currently active registered observers.
    public var observerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll { !$0.isAlive }
        return observers.count
    }
    
    /// Broadcasts single operation progress update.
    public func broadcastProgress(_ progress: ArchiveProgressInfo) {
        lock.lock()
        observers.removeAll { !$0.isAlive }
        let currentObservers = observers
        lock.unlock()
        
        for wrapper in currentObservers {
            wrapper.invoke { (observer: ArchiveProgressObserverProtocol) in
                observer.onProgressUpdated(progress)
            }
        }
    }
    
    /// Broadcasts batch task progress update.
    public func broadcastBatchProgress(_ progress: BatchProgressInfo) {
        lock.lock()
        observers.removeAll { !$0.isAlive }
        let currentObservers = observers
        lock.unlock()
        
        for wrapper in currentObservers {
            wrapper.invoke { (observer: ArchiveProgressObserverProtocol) in
                observer.onBatchProgressUpdated(progress)
            }
        }
    }
}
