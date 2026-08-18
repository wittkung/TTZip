// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Reusable asynchronous worker pool coordinating bounded concurrency to prevent thread explosion.
///
/// Supports dynamic worker scaling, prioritization tiers, and structured lifecycle state transitions.
public final class ArchiveWorkerPool: @unchecked Sendable {
    public static let shared = ArchiveWorkerPool()

    private var targetWorkerCount: Int
    private let dispatcher: ArchiveTaskDispatcher
    private var currentState: WorkerPoolState = .idle

    private var workerTasks: [UUID: Task<Void, Never>] = [:]
    private var activeWorkers: Int = 0

    private var completedTasksCount: Int64 = 0
    private var failedTasksCount: Int64 = 0

    private var continuations: [String: CheckedContinuation<Result<any Sendable, Error>, Never>] = [:]
    private var cancelledPoolItemIDs: Set<String> = []
    private let lock = NSLock()

    private convenience init() {
        self.init(maxWorkers: ProcessInfo.processInfo.activeProcessorCount, dispatcher: ArchiveTaskDispatcher())
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
    }

    /// Suspends task dequeue while keeping existing workers alive.
    public func pause() {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .running {
            currentState = .paused
        }
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
    }

    /// Drains all pending tasks gracefully before transitioning back to idle.
    public func drain() async {
        guard startDrain() else { return }

        adjustWorkers()

        while true {
            if isDrainCompleted() {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        finishDrain()
    }

    private func startDrain() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .shutdown {
            return false
        }
        currentState = .draining
        return true
    }

    private func finishDrain() {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .draining {
            currentState = .idle
            stopAllWorkerTasks()
        }
    }

    private func isDrainCompleted() -> Bool {
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

    // MARK: - Internal Worker Management

    private func stopAllWorkerTasks() {
        for task in workerTasks.values {
            task.cancel()
        }
        workerTasks.removeAll()
    }

    private func removeWorkerTask(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        workerTasks.removeValue(forKey: id)
    }

    private func adjustWorkers() {
        lock.lock()
        defer { lock.unlock() }

        guard currentState == .running || currentState == .draining else { return }

        workerTasks = workerTasks.filter { !$0.value.isCancelled }

        let currentCount = workerTasks.count
        let target = targetWorkerCount

        if currentCount > target {
            let surplusCount = currentCount - target
            let keysToCancel = Array(workerTasks.keys.prefix(surplusCount))
            for key in keysToCancel {
                if let task = workerTasks.removeValue(forKey: key) {
                    task.cancel()
                }
            }
        } else if currentCount < target {
            let toCreate = target - currentCount
            for _ in 0..<toCreate {
                let taskID = UUID()
                let task = Task { [weak self] in
                    defer {
                        self?.removeWorkerTask(id: taskID)
                    }
                    guard let self = self else { return }
                    await self.runWorkerLoop()
                }
                workerTasks[taskID] = task
            }
        }
    }

    private func checkWorkerLoopStatus() -> (shouldExit: Bool, isPaused: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if currentState == .shutdown || currentState == .idle {
            return (shouldExit: true, isPaused: false)
        }
        if currentState == .paused {
            return (shouldExit: false, isPaused: true)
        }
        if Task.isCancelled {
            return (shouldExit: true, isPaused: false)
        }
        return (shouldExit: false, isPaused: false)
    }

    private func popTaskForWorker() -> (item: (any ArchiveWorkItemProtocol)?, shouldExitDraining: Bool) {
        lock.lock()
        defer { lock.unlock() }

        let st = currentState
        if let item = dispatcher.popHighestPriorityItem() {
            activeWorkers += 1
            return (item: item, shouldExitDraining: false)
        }

        if st == .draining {
            return (item: nil, shouldExitDraining: true)
        }

        return (item: nil, shouldExitDraining: false)
    }

    private func markWorkerTaskFinished(itemID: String, success: Bool) -> CheckedContinuation<Result<any Sendable, Error>, Never>? {
        lock.lock()
        defer { lock.unlock() }

        activeWorkers -= 1
        if success {
            completedTasksCount += 1
        } else {
            failedTasksCount += 1
        }
        return continuations.removeValue(forKey: itemID)
    }

    private func runWorkerLoop() async {
        while true {
            let status = checkWorkerLoopStatus()
            if status.shouldExit {
                break
            }
            if status.isPaused {
                try? await Task.sleep(nanoseconds: 20_000_000)
                continue
            }

            let popResult = popTaskForWorker()
            if popResult.shouldExitDraining {
                break
            }

            guard let item = popResult.item else {
                try? await Task.sleep(nanoseconds: 10_000_000)
                continue
            }

            let itemID = item.itemID
            let result: Result<any Sendable, Error>
            var isSuccess = false

            if dispatcher.isCancelled(itemID: itemID) {
                result = .failure(CancellationError())
            } else {
                do {
                    let output = try await item.execute()
                    result = .success(output)
                    isSuccess = true
                } catch {
                    result = .failure(error)
                }
            }

            let cont = markWorkerTaskFinished(itemID: itemID, success: isSuccess)
            cont?.resume(returning: result)
        }
    }
}
