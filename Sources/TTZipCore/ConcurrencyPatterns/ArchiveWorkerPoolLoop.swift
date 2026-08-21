// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension ArchiveWorkerPool {

    // MARK: - Internal Worker Management

    internal func stopAllWorkerTasks() {
        for task in workerTasks.values {
            task.cancel()
        }
        workerTasks.removeAll()
    }

    internal func removeWorkerTask(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        workerTasks.removeValue(forKey: id)
    }

    internal func adjustWorkers() {
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

    internal func checkWorkerLoopStatus() -> (shouldExit: Bool, isPaused: Bool) {
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

    internal func popTaskForWorker() -> (item: (any ArchiveWorkItemProtocol)?, shouldExitDraining: Bool) {
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

    internal func markWorkerTaskFinished(
        itemID: String,
        success: Bool
    ) -> CheckedContinuation<Result<any Sendable, Error>, Never>? {
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

    internal func runWorkerLoop() async {
        while true {
            let status = checkWorkerLoopStatus()
            if status.shouldExit {
                break
            }
            if status.isPaused {
                await signaler.waitForWork()
                continue
            }

            let popResult = popTaskForWorker()
            if popResult.shouldExitDraining {
                break
            }

            guard let item = popResult.item else {
                let statusAfterPop = checkWorkerLoopStatus()
                if statusAfterPop.shouldExit {
                    break
                }
                await signaler.waitForWork()
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

            if isDrainCompleted() {
                signaler.notifyDrainIfCompleted()
            }
        }
    }
}
