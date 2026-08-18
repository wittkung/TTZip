// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Priority-based archive task dispatcher managing 4 distinct priority queues.
public final class ArchiveTaskDispatcher: @unchecked Sendable {
    private var criticalQueue: [any ArchiveWorkItemProtocol] = []
    private var userInitiatedQueue: [any ArchiveWorkItemProtocol] = []
    private var utilityQueue: [any ArchiveWorkItemProtocol] = []
    private var backgroundQueue: [any ArchiveWorkItemProtocol] = []

    private var cancelledIDs: Set<String> = []
    private let lock = NSLock()

    public init() {}

    /// Submits a single work item for execution.
    public func submit(_ item: any ArchiveWorkItemProtocol) {
        lock.lock()
        defer { lock.unlock() }

        guard !cancelledIDs.contains(item.itemID) else { return }

        switch item.priority {
        case .critical:
            criticalQueue.append(item)
        case .userInitiated:
            userInitiatedQueue.append(item)
        case .utility:
            utilityQueue.append(item)
        case .background:
            backgroundQueue.append(item)
        }
    }

    /// Submits a batch of work items for execution.
    public func submitBatch(_ items: [any ArchiveWorkItemProtocol]) {
        lock.lock()
        defer { lock.unlock() }

        for item in items {
            guard !cancelledIDs.contains(item.itemID) else { continue }
            switch item.priority {
            case .critical:
                criticalQueue.append(item)
            case .userInitiated:
                userInitiatedQueue.append(item)
            case .utility:
                utilityQueue.append(item)
            case .background:
                backgroundQueue.append(item)
            }
        }
    }

    /// Dequeues the next item in descending priority order (.critical -> .userInitiated -> .utility -> .background).
    public func popHighestPriorityItem() -> (any ArchiveWorkItemProtocol)? {
        lock.lock()
        defer { lock.unlock() }

        while true {
            var selectedItem: (any ArchiveWorkItemProtocol)?

            if !criticalQueue.isEmpty {
                selectedItem = criticalQueue.removeFirst()
            } else if !userInitiatedQueue.isEmpty {
                selectedItem = userInitiatedQueue.removeFirst()
            } else if !utilityQueue.isEmpty {
                selectedItem = utilityQueue.removeFirst()
            } else if !backgroundQueue.isEmpty {
                selectedItem = backgroundQueue.removeFirst()
            } else {
                return nil
            }

            if let item = selectedItem {
                if cancelledIDs.contains(item.itemID) {
                    cancelledIDs.remove(item.itemID)
                    continue
                }
                return item
            }
        }
    }

    /// Cancels a pending work item by identifier.
    public func cancel(itemID: String) {
        lock.lock()
        defer { lock.unlock() }

        cancelledIDs.insert(itemID)
    }

    /// Cancels all pending work items in dispatcher queues.
    public func cancelAll() {
        lock.lock()
        defer { lock.unlock() }

        for item in criticalQueue { cancelledIDs.insert(item.itemID) }
        for item in userInitiatedQueue { cancelledIDs.insert(item.itemID) }
        for item in utilityQueue { cancelledIDs.insert(item.itemID) }
        for item in backgroundQueue { cancelledIDs.insert(item.itemID) }

        criticalQueue.removeAll()
        userInitiatedQueue.removeAll()
        utilityQueue.removeAll()
        backgroundQueue.removeAll()
    }

    /// Checks if a work item has been marked cancelled.
    public func isCancelled(itemID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledIDs.contains(itemID)
    }

    /// Total count of pending items across all priority queues.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return criticalQueue.count + userInitiatedQueue.count + utilityQueue.count + backgroundQueue.count
    }

    public var isEmpty: Bool {
        return count == 0
    }

    /// Count of pending items for a specific priority tier.
    public func pendingCount(for priority: TaskPriorityLevel) -> Int {
        lock.lock()
        defer { lock.unlock() }
        switch priority {
        case .critical:
            return criticalQueue.count
        case .userInitiated:
            return userInitiatedQueue.count
        case .utility:
            return utilityQueue.count
        case .background:
            return backgroundQueue.count
        }
    }

    /// Clears all queues and resets cancellation sets.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        criticalQueue.removeAll()
        userInitiatedQueue.removeAll()
        utilityQueue.removeAll()
        backgroundQueue.removeAll()
        cancelledIDs.removeAll()
    }
}
