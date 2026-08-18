// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Swift 6 actor-isolated global operations scheduler and priority queue.
///
/// Features dynamic concurrency throttling (1~8 workers), priority queueing,
/// cooperative cancellation, and real-time AsyncStream telemetry event broadcasting.
public actor GlobalOperationsQueue {
    public static let shared = GlobalOperationsQueue()
    
    private struct ScheduledWorkItem: Sendable {
        var operation: QueuedArchiveOperation
        let executeBlock: @Sendable () async throws -> Void
    }
    
    private var maxConcurrentTasks: Int
    private var pendingQueue: [ScheduledWorkItem] = []
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private var operationsState: [UUID: QueuedArchiveOperation] = [:]
    
    private var eventContinuations: [UUID: AsyncStream<GlobalOperationsQueueEvent>.Continuation] = [:]
    
    public init(maxConcurrentTasks: Int = 4) {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        self.maxConcurrentTasks = max(1, min(8, maxConcurrentTasks > 0 ? maxConcurrentTasks : cores))
    }
    
    /// Sets maximum active concurrent operations.
    public func setMaxConcurrentTasks(_ count: Int) {
        self.maxConcurrentTasks = max(1, min(8, count))
        drainQueue()
    }
    
    /// Subscribes to real-time operations queue lifecycle and telemetry event stream.
    public func observeEvents() -> AsyncStream<GlobalOperationsQueueEvent> {
        let streamId = UUID()
        return AsyncStream { continuation in
            self.eventContinuations[streamId] = continuation
            
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(streamId: streamId)
                }
            }
        }
    }
    
    private func removeContinuation(streamId: UUID) {
        eventContinuations.removeValue(forKey: streamId)
    }
    
    private func broadcast(event: GlobalOperationsQueueEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }
    
    /// Enqueues a new asynchronous archive operation into the priority queue.
    @discardableResult
    public func enqueue(
        name: String,
        operationType: ArchiveOperationType,
        priority: TaskPriorityLevel = .userInitiated,
        totalBytes: Int64 = 0,
        execute: @escaping @Sendable () async throws -> Void
    ) -> UUID {
        let taskModel = QueuedArchiveOperation(
            name: name,
            operationType: operationType,
            priority: priority,
            createdAt: Date(),
            state: .queued,
            bytesProcessed: 0,
            totalBytes: totalBytes,
            throughputMBs: 0.0,
            errorMessage: nil
        )
        
        let workItem = ScheduledWorkItem(operation: taskModel, executeBlock: execute)
        operationsState[taskModel.id] = taskModel
        
        // Priority insert: higher priority first, then earlier creation time
        if let insertIndex = pendingQueue.firstIndex(where: {
            $0.operation.priority.rawValue < taskModel.priority.rawValue
        }) {
            pendingQueue.insert(workItem, at: insertIndex)
        } else {
            pendingQueue.append(workItem)
        }
        
        broadcast(event: taskModel.toTelemetryEvent())
        drainQueue()
        return taskModel.id
    }
    
    /// Cancels a running or pending task by UUID.
    public func cancel(taskId: UUID) {
        if let index = pendingQueue.firstIndex(where: { $0.operation.id == taskId }) {
            var item = pendingQueue.remove(at: index)
            item.operation.state = .cancelled
            operationsState[taskId] = item.operation
            broadcast(event: item.operation.toTelemetryEvent())
            return
        }
        
        if let runningTask = runningTasks.removeValue(forKey: taskId) {
            runningTask.cancel()
            if var op = operationsState[taskId] {
                op.state = .cancelled
                operationsState[taskId] = op
                broadcast(event: op.toTelemetryEvent())
            }
            drainQueue()
        }
    }
    
    /// Updates progress of an active operation.
    public func updateProgress(taskId: UUID, bytesProcessed: Int64, totalBytes: Int64, throughputMBs: Double) {
        guard var op = operationsState[taskId] else { return }
        op.bytesProcessed = bytesProcessed
        op.totalBytes = max(totalBytes, op.totalBytes)
        op.throughputMBs = throughputMBs
        operationsState[taskId] = op
        broadcast(event: op.toTelemetryEvent())
    }
    
    /// Returns snapshot of all active, queued, and finished tasks.
    public func getAllTasks() -> [QueuedArchiveOperation] {
        return Array(operationsState.values).sorted { $0.createdAt < $1.createdAt }
    }
    
    private func drainQueue() {
        while runningTasks.count < maxConcurrentTasks && !pendingQueue.isEmpty {
            let workItem = pendingQueue.removeFirst()
            let taskId = workItem.operation.id
            
            var runningOp = workItem.operation
            runningOp.state = .running
            operationsState[taskId] = runningOp
            broadcast(event: runningOp.toTelemetryEvent())
            
            let task = Task { [weak self] in
                do {
                    try await workItem.executeBlock()
                    await self?.finishTask(taskId: taskId, error: nil)
                } catch {
                    await self?.finishTask(taskId: taskId, error: error)
                }
            }
            
            runningTasks[taskId] = task
        }
    }
    
    private func finishTask(taskId: UUID, error: Error?) {
        runningTasks.removeValue(forKey: taskId)
        
        if var op = operationsState[taskId] {
            if let err = error {
                if (err as? CancellationError) != nil {
                    op.state = .cancelled
                } else {
                    op.state = .failed
                    op.errorMessage = err.localizedDescription
                }
            } else {
                op.state = .completed
                op.bytesProcessed = op.totalBytes
            }
            operationsState[taskId] = op
            broadcast(event: op.toTelemetryEvent())
        }
        
        drainQueue()
    }
}
