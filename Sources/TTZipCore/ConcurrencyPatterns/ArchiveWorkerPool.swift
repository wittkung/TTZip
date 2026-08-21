// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Reusable asynchronous worker pool coordinating bounded concurrency to prevent thread explosion.
///
/// Supports dynamic worker scaling, prioritization tiers, and zero-polling event-driven dispatching.
public final class ArchiveWorkerPool: @unchecked Sendable {
    public static let shared = ArchiveWorkerPool()

    internal var targetWorkerCount: Int
    internal let dispatcher: ArchiveTaskDispatcher
    internal var currentState: WorkerPoolState = .idle

    internal var workerTasks: [UUID: Task<Void, Never>] = [:]
    internal var activeWorkers: Int = 0

    internal var completedTasksCount: Int64 = 0
    internal var failedTasksCount: Int64 = 0

    internal var continuations: [String: CheckedContinuation<Result<any Sendable, Error>, Never>] = [:]
    internal var cancelledPoolItemIDs: Set<String> = []
    internal let lock = NSLock()
    internal let signaler = ArchiveWorkerPoolSignaler()

    private convenience init() {
        self.init(
            maxWorkers: ProcessInfo.processInfo.activeProcessorCount,
            dispatcher: ArchiveTaskDispatcher()
        )
    }

    internal init(
        maxWorkers: Int = ProcessInfo.processInfo.activeProcessorCount,
        dispatcher: ArchiveTaskDispatcher = ArchiveTaskDispatcher()
    ) {
        self.targetWorkerCount = max(1, maxWorkers)
        self.dispatcher = dispatcher
    }

    public var maxWorkers: Int {
        lock.lock()
        defer { lock.unlock() }
        return targetWorkerCount
    }

    public var state: WorkerPoolState {
        lock.lock()
        defer { lock.unlock() }
        return currentState
    }

    public var activeWorkerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeWorkers
    }

    public var completedTaskCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return completedTasksCount
    }

    public var failedTaskCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return failedTasksCount
    }

    public var pendingTaskCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return dispatcher.count
    }

    // MARK: - Dynamic Worker Scaling

    /// Dynamically sets the concurrency limit of the worker pool.
    public func setWorkerCount(_ count: Int) {
        lock.lock()
        let newCount = max(1, count)
        self.targetWorkerCount = newCount
        let running = currentState == .running
        lock.unlock()

        if running {
            adjustWorkers()
            signaler.notifyWorkAvailable()
        }
    }

    // MARK: - Lifecycle Management

    /// Starts the worker pool loop.
    public func start() {
        lock.lock()
        guard currentState == .idle || currentState == .paused else {
            lock.unlock()
            return
        }
        currentState = .running
        lock.unlock()

        adjustWorkers()
        signaler.notifyWorkAvailable()
    }

    /// Suspends task dequeue while keeping existing workers alive.
    public func pause() {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .running {
            currentState = .paused
        }
        signaler.notifyWorkAvailable()
    }

    /// Resumes task dequeue on paused worker pool.
    public func resume() {
        lock.lock()
        guard currentState == .paused else {
            lock.unlock()
            return
        }
        currentState = .running
        lock.unlock()

        adjustWorkers()
        signaler.notifyWorkAvailable()
    }

    /// Drains all pending tasks gracefully before transitioning back to idle.
    public func drain() async {
        guard startDrain() else { return }

        adjustWorkers()
        signaler.notifyWorkAvailable()

        while true {
            if isDrainCompleted() {
                break
            }
            await signaler.waitForDrain()
        }

        finishDrain()
    }

    internal func startDrain() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .shutdown {
            return false
        }
        currentState = .draining
        return true
    }

    internal func finishDrain() {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .draining {
            currentState = .idle
            stopAllWorkerTasks()
        }
    }

    internal func isDrainCompleted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let isDone = dispatcher.isEmpty && activeWorkers == 0
        let isShutdown = currentState == .shutdown
        return isDone || isShutdown
    }

    /// Shuts down the worker pool immediately, cancelling pending tasks.
    public func shutdown() {
        lock.lock()
        currentState = .shutdown
        dispatcher.cancelAll()

        let pendingContinuations = Array(continuations.values)
        continuations.removeAll()

        stopAllWorkerTasks()
        lock.unlock()

        signaler.wakeAll()

        for cont in pendingContinuations {
            cont.resume(returning: .failure(CancellationError()))
        }
    }

    // MARK: - Task Submission API

    public func submit(_ item: any ArchiveWorkItemProtocol) {
        lock.lock()
        let isIdle = currentState == .idle
        dispatcher.submit(item)
        lock.unlock()

        if isIdle {
            start()
        } else {
            adjustWorkers()
        }
        signaler.notifyWorkAvailable()
    }

    public func submitBatch(_ items: [any ArchiveWorkItemProtocol]) {
        lock.lock()
        let isIdle = currentState == .idle
        dispatcher.submitBatch(items)
        lock.unlock()

        if isIdle {
            start()
        } else {
            adjustWorkers()
        }
        signaler.notifyWorkAvailable()
    }

    @discardableResult
    public func submit(
        priority: TaskPriorityLevel = .userInitiated,
        itemID: String = UUID().uuidString,
        _ block: @escaping @Sendable () async throws -> any Sendable
    ) -> String {
        let item = ArchiveWorkItem(itemID: itemID, priority: priority, block: block)
        submit(item)
        return itemID
    }

    /// Submits work item and awaits its asynchronous completion.
    public func executeAndAwait(_ item: any ArchiveWorkItemProtocol) async throws -> any Sendable {
        let itemID = item.itemID

        return try await withCheckedContinuation { continuation in
            lock.lock()
            if cancelledPoolItemIDs.contains(itemID) || dispatcher.isCancelled(itemID: itemID) {
                cancelledPoolItemIDs.remove(itemID)
                lock.unlock()
                continuation.resume(returning: Result<any Sendable, Error>.failure(CancellationError()))
                return
            }
            continuations[itemID] = continuation
            lock.unlock()

            submit(item)
        }.get()
    }

    public func executeAndAwait(
        priority: TaskPriorityLevel = .userInitiated,
        itemID: String = UUID().uuidString,
        _ block: @escaping @Sendable () async throws -> any Sendable
    ) async throws -> any Sendable {
        let item = ArchiveWorkItem(itemID: itemID, priority: priority, block: block)
        return try await executeAndAwait(item)
    }

    public func cancel(itemID: String) {
        lock.lock()
        cancelledPoolItemIDs.insert(itemID)
        let cont = continuations.removeValue(forKey: itemID)
        dispatcher.cancel(itemID: itemID)
        lock.unlock()

        cont?.resume(returning: .failure(CancellationError()))
    }

    public func cancelAll() {
        lock.lock()
        for itemID in continuations.keys {
            cancelledPoolItemIDs.insert(itemID)
        }
        let allConts = Array(continuations.values)
        continuations.removeAll()
        dispatcher.cancelAll()
        lock.unlock()

        for cont in allConts {
            cont.resume(returning: .failure(CancellationError()))
        }
    }
}
