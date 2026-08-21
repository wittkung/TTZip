// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Zero-polling asynchronous signaling mechanism for worker pool coordination.
final class ArchiveWorkerPoolSignaler: @unchecked Sendable {
    private var workWaiters: [CheckedContinuation<Void, Never>] = []
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    private let lock = NSLock()

    /// Suspends caller asynchronously until work is submitted or state changes.
    func waitForWork() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            workWaiters.append(continuation)
            lock.unlock()
        }
    }

    /// Wakes all waiting worker tasks immediately.
    func notifyWorkAvailable() {
        lock.lock()
        let waiters = workWaiters
        workWaiters.removeAll()
        lock.unlock()

        for waiter in waiters {
            waiter.resume()
        }
    }

    /// Suspends caller asynchronously until drain completion.
    func waitForDrain() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            drainWaiters.append(continuation)
            lock.unlock()
        }
    }

    /// Wakes all waiting drain callers.
    func notifyDrainIfCompleted() {
        lock.lock()
        let waiters = drainWaiters
        drainWaiters.removeAll()
        lock.unlock()

        for waiter in waiters {
            waiter.resume()
        }
    }

    /// Wakes all suspended waiters across all categories.
    func wakeAll() {
        lock.lock()
        let wWaiters = workWaiters
        workWaiters.removeAll()
        let dWaiters = drainWaiters
        drainWaiters.removeAll()
        lock.unlock()

        for waiter in wWaiters {
            waiter.resume()
        }
        for waiter in dWaiters {
            waiter.resume()
        }
    }
}
