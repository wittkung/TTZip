// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Task cancellation observer protocol.
public protocol TaskCancellationObserverProtocol: AnyObject, Sendable {
    func onTaskCancelled(taskId: String)
}

/// Task cancellation notification and state registry coordinating cross-module async task abort signals.
public final class TaskCancellationObserverCenter: @unchecked Sendable {
    public static let shared = TaskCancellationObserverCenter()
    
    private var cancelledTaskIds: Set<String> = []
    private var observers: [String: [WeakObserverWrapper]] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Registers a task ID.
    public func registerTask(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelledTaskIds.remove(taskId)
    }
    
    /// Marks a task finished and clears observer bindings to prevent memory leaks.
    public func finishTask(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelledTaskIds.remove(taskId)
        observers.removeValue(forKey: taskId)
    }
    
    /// Requests cancellation for a specific task and broadcasts to attached observers.
    public func cancelTask(_ taskId: String) {
        lock.lock()
        cancelledTaskIds.insert(taskId)
        let taskObservers = observers[taskId] ?? []
        let validObservers = taskObservers.filter { $0.isAlive }
        if validObservers.isEmpty {
            observers.removeValue(forKey: taskId)
        } else {
            observers[taskId] = validObservers
        }
        lock.unlock()
        
        for wrapper in validObservers {
            wrapper.invoke { (observer: TaskCancellationObserverProtocol) in
                observer.onTaskCancelled(taskId: taskId)
            }
        }
    }
    
    /// Queries whether a task has been cancelled.
    public func isTaskCancelled(_ taskId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledTaskIds.contains(taskId)
    }
    
    /// Adds cancellation observer for a specific task.
    public func addObserver(
        _ observer: TaskCancellationObserverProtocol,
        forTask taskId: String,
        dispatchQueue: DispatchQueue? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        var list = observers[taskId] ?? []
        list.removeAll { !$0.isAlive }
        let wrapper = WeakObserverWrapper(observer, dispatchQueue: dispatchQueue)
        if let idx = list.firstIndex(where: { $0.observer === observer }) {
            list[idx] = wrapper
        } else {
            list.append(wrapper)
        }
        observers[taskId] = list
    }
    
    /// Removes cancellation observer for a specific task.
    public func removeObserver(_ observer: TaskCancellationObserverProtocol, forTask taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if var list = observers[taskId] {
            list.removeAll { $0.observer === observer || !$0.isAlive }
            if list.isEmpty {
                observers.removeValue(forKey: taskId)
            } else {
                observers[taskId] = list
            }
        }
    }
    
    /// Prunes dead observer wrappers.
    public func prune() {
        lock.lock()
        defer { lock.unlock() }
        
        for (taskId, list) in observers {
            let valid = list.filter { $0.isAlive }
            if valid.isEmpty {
                observers.removeValue(forKey: taskId)
            } else {
                observers[taskId] = valid
            }
        }
    }
    
    public var registeredObserverTaskCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return observers.keys.count
    }
    
    public func observerCount(forTask taskId: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let list = observers[taskId] else { return 0 }
        let valid = list.filter { $0.isAlive }
        if valid.isEmpty {
            observers.removeValue(forKey: taskId)
            return 0
        }
        observers[taskId] = valid
        return valid.count
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        cancelledTaskIds.removeAll()
        observers.removeAll()
    }
}
