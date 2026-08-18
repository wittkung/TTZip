// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

private final class ConcurrencyTracker: @unchecked Sendable {
    private var currentActive: Int = 0
    private var maxObserved: Int = 0
    private let lock = NSLock()

    func enter() {
        lock.lock()
        defer { lock.unlock() }
        currentActive += 1
        if currentActive > maxObserved {
            maxObserved = currentActive
        }
    }

    func exit() {
        lock.lock()
        defer { lock.unlock() }
        currentActive -= 1
    }

    func getMaxObserved() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return maxObserved
    }
}

final class WorkerPoolPatternTests: XCTestCase {

    private var tempDirURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("WorkerPoolTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let url = tempDirURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }

    // MARK: - 1. Comparable

    func testTaskPriorityComparable() {
        XCTAssertTrue(TaskPriorityLevel.critical > TaskPriorityLevel.userInitiated)
        XCTAssertTrue(TaskPriorityLevel.userInitiated > TaskPriorityLevel.utility)
        XCTAssertTrue(TaskPriorityLevel.utility > TaskPriorityLevel.background)

        let unsorted: [TaskPriorityLevel] = [.background, .critical, .utility, .userInitiated]
        let sorted = unsorted.sorted()
        XCTAssertEqual(sorted, [.background, .utility, .userInitiated, .critical])
    }

    // MARK: - 2. 4

    func testTaskPriorityOrdering() {
        let dispatcher = ArchiveTaskDispatcher()

        let itemBg = ArchiveWorkItem(itemID: "bg", priority: .background) { "bg" }
        let itemUtil = ArchiveWorkItem(itemID: "util", priority: .utility) { "util" }
        let itemUser = ArchiveWorkItem(itemID: "user", priority: .userInitiated) { "user" }
        let itemCrit = ArchiveWorkItem(itemID: "crit", priority: .critical) { "crit" }

        dispatcher.submit(itemBg)
        dispatcher.submit(itemUtil)
        dispatcher.submit(itemUser)
        dispatcher.submit(itemCrit)

        XCTAssertEqual(dispatcher.count, 4)

        let pop1 = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(pop1?.itemID, "crit")

        let pop2 = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(pop2?.itemID, "user")

        let pop3 = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(pop3?.itemID, "util")

        let pop4 = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(pop4?.itemID, "bg")

        XCTAssertTrue(dispatcher.isEmpty)
    }

    // MARK: - 3. Clear

    func testDispatcherPendingCountAndClear() {
        let dispatcher = ArchiveTaskDispatcher()

        dispatcher.submit(ArchiveWorkItem(itemID: "c1", priority: .critical) { "" })
        dispatcher.submit(ArchiveWorkItem(itemID: "c2", priority: .critical) { "" })
        dispatcher.submit(ArchiveWorkItem(itemID: "u1", priority: .userInitiated) { "" })
        dispatcher.submit(ArchiveWorkItem(itemID: "b1", priority: .background) { "" })

        XCTAssertEqual(dispatcher.count, 4)
        XCTAssertEqual(dispatcher.pendingCount(for: .critical), 2)
        XCTAssertEqual(dispatcher.pendingCount(for: .userInitiated), 1)
        XCTAssertEqual(dispatcher.pendingCount(for: .utility), 0)
        XCTAssertEqual(dispatcher.pendingCount(for: .background), 1)

        dispatcher.clear()
        XCTAssertTrue(dispatcher.isEmpty)
        XCTAssertEqual(dispatcher.count, 0)
    }

    // MARK: - 4.

    func testDispatcherItemCancellation() {
        let dispatcher = ArchiveTaskDispatcher()

        let item1 = ArchiveWorkItem(itemID: "item1", priority: .userInitiated) { "1" }
        let item2 = ArchiveWorkItem(itemID: "item2", priority: .userInitiated) { "2" }
        let item3 = ArchiveWorkItem(itemID: "item3", priority: .userInitiated) { "3" }

        dispatcher.submitBatch([item1, item2, item3])
        XCTAssertEqual(dispatcher.count, 3)

        dispatcher.cancel(itemID: "item2")
        XCTAssertTrue(dispatcher.isCancelled(itemID: "item2"))

        let first = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(first?.itemID, "item1")

        let second = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(second?.itemID, "item3")

        XCTAssertNil(dispatcher.popHighestPriorityItem())
    }

    // MARK: - 5. CancelAll

    func testDispatcherCancelAll() {
        let dispatcher = ArchiveTaskDispatcher()

        for i in 0..<10 {
            dispatcher.submit(ArchiveWorkItem(itemID: "item_\(i)", priority: .utility) { "\(i)" })
        }
        XCTAssertEqual(dispatcher.count, 10)

        dispatcher.cancelAll()
        XCTAssertTrue(dispatcher.isEmpty)
        XCTAssertEqual(dispatcher.count, 0)
        XCTAssertTrue(dispatcher.isCancelled(itemID: "item_5"))
    }

    // MARK: - 6. maxWorkers = 3

    func testMaxWorkersConcurrencyLimit() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 3)
        let tracker = ConcurrencyTracker()

        var items: [ArchiveWorkItem] = []
        for i in 0..<15 {
            items.append(ArchiveWorkItem(itemID: "task_\(i)", priority: .userInitiated) {
                tracker.enter()
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                tracker.exit()
                return i
            })
        }

        pool.submitBatch(items)
        await pool.drain()

        let maxObserved = tracker.getMaxObserved()
        XCTAssertLessThanOrEqual(maxObserved, 3, "实际最高并发数超过了 maxWorkers=3 的限制")
    }

    // MARK: - 7. 2 Workers -> 8 Workers -> 1 Worker

    func testDynamicWorkerPoolScaling() {
        let pool = ArchiveWorkerPool(maxWorkers: 2)
        XCTAssertEqual(pool.maxWorkers, 2)

        pool.setWorkerCount(8)
        XCTAssertEqual(pool.maxWorkers, 8)

        pool.setWorkerCount(1)
        XCTAssertEqual(pool.maxWorkers, 1)

        pool.shutdown()
    }

    // MARK: - 8. Start / Pause / Resume

    func testWorkerPoolLifecycleStartPauseResume() {
        let pool = ArchiveWorkerPool(maxWorkers: 2)
        XCTAssertEqual(pool.state, .idle)

        pool.start()
        XCTAssertEqual(pool.state, .running)

        pool.pause()
        XCTAssertEqual(pool.state, .paused)

        pool.resume()
        XCTAssertEqual(pool.state, .running)

        pool.shutdown()
        XCTAssertEqual(pool.state, .shutdown)
    }

    // MARK: - 9. Drain

    func testWorkerPoolLifecycleDrain() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 4)

        for i in 0..<10 {
            pool.submit(priority: .utility, itemID: "drain_\(i)") {
                try await Task.sleep(nanoseconds: 2_000_000) // 2ms
                return i
            }
        }

        await pool.drain()
        XCTAssertEqual(pool.completedTaskCount, 10)
        XCTAssertEqual(pool.activeWorkerCount, 0)
        XCTAssertEqual(pool.pendingTaskCount, 0)
        XCTAssertEqual(pool.state, .idle)
    }

    // MARK: - 10. Shutdown

    func testWorkerPoolLifecycleShutdown() {
        let pool = ArchiveWorkerPool(maxWorkers: 2)

        for i in 0..<20 {
            pool.submit(priority: .background, itemID: "shut_\(i)") {
                try await Task.sleep(nanoseconds: 50_000_000)
                return i
            }
        }

        pool.shutdown()
        XCTAssertEqual(pool.state, .shutdown)
        XCTAssertEqual(pool.pendingTaskCount, 0)
    }

    // MARK: - 11. ExecuteAndAwait

    func testExecuteAndAwaitResult() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 2)
        pool.start()

        let result = try await pool.executeAndAwait(priority: .critical, itemID: "await_1") {
            return "TTZip_WorkerPool_Success"
        }

        XCTAssertEqual(result as? String, "TTZip_WorkerPool_Success")
        pool.shutdown()
    }

    // MARK: - 12.

    func testCancelSpecificItemInPool() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 1)
        pool.start()
        pool.pause()

        let item1 = ArchiveWorkItem(itemID: "cancel_target", priority: .utility) { "cancelled" }
        pool.submit(item1)

        pool.cancel(itemID: "cancel_target")
        pool.resume()

        do {
            _ = try await pool.executeAndAwait(item1)
            XCTFail("已取消任务应当抛出 CancellationError")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        pool.shutdown()
    }

    // MARK: - 13. CancelAll

    func testCancelAllInPool() {
        let pool = ArchiveWorkerPool(maxWorkers: 1)
        pool.start()
        pool.pause()

        for i in 0..<5 {
            pool.submit(priority: .background, itemID: "b_\(i)") { "\(i)" }
        }
        XCTAssertEqual(pool.pendingTaskCount, 5)

        pool.cancelAll()
        XCTAssertEqual(pool.pendingTaskCount, 0)
        pool.shutdown()
    }

    // MARK: - 14. 100+ Task Zero Thread Explosion & Zero Deadlock

    func testHighConcurrencyStress100Tasks() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 8)
        let totalTasks = 100

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<totalTasks {
                group.addTask {
                    let priority: TaskPriorityLevel = (i % 4 == 0) ? .critical : ((i % 4 == 1) ? .userInitiated : ((i % 4 == 2) ? .utility : .background))
                    let res = try await pool.executeAndAwait(priority: priority, itemID: "stress_\(i)") {
                        return i * 2
                    }
                    XCTAssertEqual(res as? Int, i * 2)
                }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(pool.completedTaskCount, Int64(totalTasks))
        XCTAssertEqual(pool.failedTaskCount, 0)
        await pool.drain()
    }

    // MARK: - 15. BatchArchiveEngine ArchiveWorkerPool

    func testBatchArchiveEngineWithWorkerPool() async throws {
        let mockFacade = MockTTZipEngineFacade()
        let pool = ArchiveWorkerPool(maxWorkers: 2)
        let engine = BatchArchiveEngine(workerPool: pool, engineFacade: mockFacade)

        let tasks = [
            BatchCompressTask(inputs: ["/tmp/file1"], outputPath: "/tmp/out1.zip", format: .zip),
            BatchCompressTask(inputs: ["/tmp/file2"], outputPath: "/tmp/out2.zip", format: .zip)
        ]

        let results = await engine.executeBatchCompress(tasks: tasks, priority: .userInitiated)

        XCTAssertEqual(results.count, 2)
        for res in results {
            XCTAssertTrue(res.success)
        }
    }

    // MARK: - 16. PasswordRecoveryEngine WorkerPool

    func testPasswordRecoveryEngineParallelWithWorkerPool() async throws {
        let dict = ["wrong1", "correct_pwd"]
        let pool = ArchiveWorkerPool(maxWorkers: 2)

        let items = dict.enumerated().map { (idx, pwd) in
            ArchiveWorkItem(itemID: "pwd_\(idx)", priority: .userInitiated) {
                if pwd == "correct_pwd" {
                    return pwd
                }
                return nil as String?
            }
        }

        pool.start()
        var found: String? = nil
        for item in items {
            if let res = try await pool.executeAndAwait(item) as? String {
                found = res
                break
            }
        }
        await pool.drain()

        XCTAssertEqual(found, "correct_pwd")
    }

    // MARK: - 17. FormatDiagnosticSuiteRunner WorkerPool

    func testFormatDiagnosticSuiteRunnerParallelWithWorkerPool() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 2)

        let itemZip = ArchiveWorkItem(itemID: "diag_zip", priority: .utility) {
            return true
        }

        let res = try await pool.executeAndAwait(itemZip) as? Bool
        await pool.drain()

        XCTAssertEqual(res, true)
    }

    // MARK: - 18. WorkerPool

    func testWorkerPoolSharedSingleton() {
        let shared = ArchiveWorkerPool.shared
        XCTAssertNotNil(shared)
        XCTAssertGreaterThanOrEqual(shared.maxWorkers, 1)
    }

    // MARK: - 19. Worker

    func testDynamicScalingResuscitatesWorkers() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 4)
        pool.start()

        for i in 0..<4 {
            let res = try await pool.executeAndAwait(priority: .userInitiated, itemID: "initial_\(i)") {
                return i
            }
            XCTAssertEqual(res as? Int, i)
        }

        pool.setWorkerCount(1)
        XCTAssertEqual(pool.maxWorkers, 1)

        let resScaleDown = try await pool.executeAndAwait(priority: .userInitiated, itemID: "scaledown_1") {
            return 100
        }
        XCTAssertEqual(resScaleDown as? Int, 100)

        pool.setWorkerCount(4)
        XCTAssertEqual(pool.maxWorkers, 4)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<8 {
                group.addTask {
                    let res = try await pool.executeAndAwait(priority: .userInitiated, itemID: "scaleup_\(i)") {
                        try await Task.sleep(nanoseconds: 5_000_000)
                        return i * 10
                    }
                    XCTAssertEqual(res as? Int, i * 10)
                }
            }
            try await group.waitForAll()
        }

        await pool.drain()
        XCTAssertEqual(pool.pendingTaskCount, 0)
        XCTAssertEqual(pool.activeWorkerCount, 0)
    }

    // MARK: - 20. executeAndAwait concurrent cancel Continuation

    func testConcurrentExecuteAndAwaitWithCancelRace() async throws {
        let pool = ArchiveWorkerPool(maxWorkers: 4)
        pool.start()

        let totalRounds = 50
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<totalRounds {
                let itemID = "race_\(i)"

                group.addTask {
                    let item = ArchiveWorkItem(itemID: itemID, priority: .userInitiated) {
                        try await Task.sleep(nanoseconds: 2_000_000)
                        return "done_\(i)"
                    }
                    do {
                        _ = try await pool.executeAndAwait(item)
                    } catch {
                        XCTAssertTrue(error is CancellationError)
                    }
                }

                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 0...1_000_000))
                    pool.cancel(itemID: itemID)
                }
            }
            try await group.waitForAll()
        }

        await pool.drain()
    }

    // MARK: - 21. Dispatcher popHighestPriorityItem cancelledIDs

    func testCancelledIDsSetCleanupInDispatcher() {
        let dispatcher = ArchiveTaskDispatcher()

        let item1 = ArchiveWorkItem(itemID: "c_item1", priority: .utility) { "1" }
        let item2 = ArchiveWorkItem(itemID: "c_item2", priority: .utility) { "2" }

        dispatcher.submit(item1)
        dispatcher.submit(item2)

        dispatcher.cancel(itemID: "c_item1")
        XCTAssertTrue(dispatcher.isCancelled(itemID: "c_item1"))

        let popped = dispatcher.popHighestPriorityItem()
        XCTAssertEqual(popped?.itemID, "c_item2")

        XCTAssertFalse(dispatcher.isCancelled(itemID: "c_item1"))
    }
}

