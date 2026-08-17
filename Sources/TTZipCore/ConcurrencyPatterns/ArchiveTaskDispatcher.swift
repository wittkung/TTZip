import Foundation

/// 优先级任务调度器 (Archive Task Dispatcher)
/// 维护 critical, userInitiated, utility, background 4 级优先级队列表
/// 支持根据优先级出队、单个任务取消与批量任务取消
public final class ArchiveTaskDispatcher: @unchecked Sendable {
    private var criticalQueue: [any ArchiveWorkItemProtocol] = []
    private var userInitiatedQueue: [any ArchiveWorkItemProtocol] = []
    private var utilityQueue: [any ArchiveWorkItemProtocol] = []
    private var backgroundQueue: [any ArchiveWorkItemProtocol] = []

    private var cancelledIDs: Set<String> = []
    private let lock = NSLock()

    public init() {}

    /// 提交单个并发任务单元
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

    /// 批量提交并发任务单元
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

    /// 按优先级从高到低 (.critical -> .userInitiated -> .utility -> .background) 出队
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
                    continue // 已取消任务，丢弃并同步清理 cancelledIDs 记录，防范 Set 无界增长
                }
                return item
            }
        }
    }

    /// 取消指定 itemID 的任务
    public func cancel(itemID: String) {
        lock.lock()
        defer { lock.unlock() }

        cancelledIDs.insert(itemID)
    }

    /// 取消调度器中所有未执行的任务
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

    /// 检查特定任务是否已被取消
    public func isCancelled(itemID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledIDs.contains(itemID)
    }

    /// 队列中剩余待处理任务总数
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return criticalQueue.count + userInitiatedQueue.count + utilityQueue.count + backgroundQueue.count
    }

    /// 队列是否为空
    public var isEmpty: Bool {
        return count == 0
    }

    /// 获取特定优先级的待处理任务数量
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

    /// 清空调度器并重置取消记录
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
