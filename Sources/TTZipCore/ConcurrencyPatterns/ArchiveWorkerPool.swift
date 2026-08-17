import Foundation

/// 可复用并发线程池 (Archive Worker Pool)
/// 默认 maxWorkers = ProcessInfo.processInfo.activeProcessorCount，防止 Thread Explosion
/// 支持动态扩展 API setWorkerCount，支持 start/pause/resume/drain/shutdown 完整生命周期管控
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

    /// 当前线程池上限 Workers 数量
    public var maxWorkers: Int {
        lock.lock()
        defer { lock.unlock() }
        return targetWorkerCount
    }

    /// 当前线程池运行状态
    public var state: WorkerPoolState {
        lock.lock()
        defer { lock.unlock() }
        return currentState
    }

    /// 当前正在并发执行任务的 Worker 数量
    public var activeWorkerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeWorkers
    }

    /// 已完成任务累计数
    public var completedTaskCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return completedTasksCount
    }

    /// 失败任务累计数
    public var failedTaskCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return failedTasksCount
    }

    /// 待处理任务总数
    public var pendingTaskCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return dispatcher.count
    }

    // MARK: - 动态调整 Worker 数量

    /// 动态设置并发 Worker 线程池上限 (如针对 Apple Silicon 性能核 P-Core / 能效核 E-Core 调优)
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

    // MARK: - 生命周期管控 API

    /// 启动线程池
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

    /// 挂起暂停线程池 (Worker 保持挂起状态，暂停出队新任务)
    public func pause() {
        lock.lock()
        defer { lock.unlock() }
        if currentState == .running {
            currentState = .paused
        }
    }

    /// 恢复运行线程池
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

    /// 排干并平滑关闭 (暂停接收新任务，等待现有任务及队列表任务全部执行完毕后回到 idle)
    public func drain() async {
        guard startDrain() else { return }

        adjustWorkers()

        // 轮询等待调度器清空且活动 Worker 归零
        while true {
            if isDrainCompleted() {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
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

    /// 立即强制关闭线程池 (取消所有待处理及活动任务)
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

    // MARK: - 任务提交与同步等待 API

    /// 提交单个任务到调度器
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

    /// 批量提交任务到调度器
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

    /// 便捷提交 Task 闭包
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

    /// 提交任务并异步等待结果返回
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

    /// 提交闭包任务并异步等待结果返回
    public func executeAndAwait(
        priority: TaskPriorityLevel = .userInitiated,
        itemID: String = UUID().uuidString,
        _ block: @escaping @Sendable () async throws -> any Sendable
    ) async throws -> any Sendable {
        let item = ArchiveWorkItem(itemID: itemID, priority: priority, block: block)
        return try await executeAndAwait(item)
    }

    /// 取消特定任务
    public func cancel(itemID: String) {
        lock.lock()
        cancelledPoolItemIDs.insert(itemID)
        let cont = continuations.removeValue(forKey: itemID)
        dispatcher.cancel(itemID: itemID)
        lock.unlock()

        cont?.resume(returning: .failure(CancellationError()))
    }

    /// 取消全部任务
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

    // MARK: - 内部 Worker 调整与同步锁辅助函数

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

        // 清理已结束/已取消的 Worker Task 句柄
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
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                continue
            }

            let popResult = popTaskForWorker()
            if popResult.shouldExitDraining {
                break
            }

            guard let item = popResult.item else {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
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
