// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

private struct EventSubscription: Sendable {
    let wrapper: WeakObserverWrapper
    let filterEvents: Set<ArchiveEventType>?
}

/// Global event publish-subscribe event center leveraging weak references to prevent retain cycles.
public final class ArchiveEventCenter: ArchiveEventCenterProtocol, @unchecked Sendable {
    public static let shared = ArchiveEventCenter()
    
    private var subscriptions: [EventSubscription] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// Subscribes to global system events.
    /// - Parameters:
    ///   - observer: Observer conforming to `ArchiveEventObserverProtocol`.
    ///   - events: Target event types filter (or nil for all events).
    ///   - dispatchQueue: Target dispatch queue for callbacks.
    public func addObserver(
        _ observer: ArchiveEventObserverProtocol,
        forEvents events: Set<ArchiveEventType>? = nil,
        dispatchQueue: DispatchQueue? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll { !$0.wrapper.isAlive }
        
        let wrapper = WeakObserverWrapper(observer, dispatchQueue: dispatchQueue)
        let newSub = EventSubscription(wrapper: wrapper, filterEvents: events)
        if let idx = subscriptions.firstIndex(where: { $0.wrapper.observer === observer }) {
            subscriptions[idx] = newSub
        } else {
            subscriptions.append(newSub)
        }
    }
    
    /// Unregisters an event observer.
    public func removeObserver(_ observer: ArchiveEventObserverProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll { $0.wrapper.observer === observer || !$0.wrapper.isAlive }
    }
    
    /// Removes all registered observers.
    public func removeAllObservers() {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll()
    }
    
    /// Count of currently active subscribers.
    public var observerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll { !$0.wrapper.isAlive }
        return subscriptions.count
    }
    
    /// Posts a system event to all matching subscribers.
    public func post(event: ArchiveEvent) {
        lock.lock()
        subscriptions.removeAll { !$0.wrapper.isAlive }
        let validSubscriptions = subscriptions
        lock.unlock()
        
        let targetType = event.eventType
        for sub in validSubscriptions {
            if let filter = sub.filterEvents, !filter.contains(targetType) {
                continue
            }
            sub.wrapper.invoke { (observer: ArchiveEventObserverProtocol) in
                observer.onArchiveEvent(event)
            }
        }
    }
    
    // MARK: - Convenience Event Dispatchers
    
    public func postArchiveCompleted(
        archivePath: String,
        operationType: ArchiveOperationType,
        duration: TimeInterval,
        totalBytes: Int64
    ) {
        post(event: .archiveCompleted(
            archivePath: archivePath,
            operationType: operationType,
            duration: duration,
            totalBytes: totalBytes
        ))
    }
    
    public func postExtractionFailed(archivePath: String, error: String) {
        post(event: .extractionFailed(archivePath: archivePath, error: error))
    }
    
    public func postSecurityThreatIntercepted(archivePath: String, threatDescription: String) {
        post(event: .securityThreatIntercepted(archivePath: archivePath, threatDescription: threatDescription))
    }
    
    public func postPasswordVaultUnlocked(archivePath: String, password: String, isVaultUnlocked: Bool) {
        post(event: .passwordVaultUnlocked(archivePath: archivePath, password: password, isVaultUnlocked: isVaultUnlocked))
    }
    
    public func postPresetChanged(oldPresetName: String?, newPresetName: String) {
        post(event: .presetChanged(oldPresetName: oldPresetName, newPresetName: newPresetName))
    }
    
    public func postTaskStateChanged(taskId: UUID, oldState: String, newState: String) {
        post(event: .taskStateChanged(taskId: taskId, oldState: oldState, newState: newState))
    }
}
