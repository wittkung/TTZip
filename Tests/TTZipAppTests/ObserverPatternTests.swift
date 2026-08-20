// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp
@testable import TTZipCLI

final class MockProgressObserver: ArchiveProgressObserverProtocol, @unchecked Sendable {
    var progressHistory: [ArchiveProgressInfo] = []
    var batchProgressHistory: [BatchProgressInfo] = []
    private let lock = NSLock()
    
    func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        lock.lock()
        progressHistory.append(progress)
        lock.unlock()
    }
    
    func onBatchProgressUpdated(_ progress: BatchProgressInfo) {
        lock.lock()
        batchProgressHistory.append(progress)
        lock.unlock()
    }
    
    var receivedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return progressHistory.count
    }
    
    var receivedBatchCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return batchProgressHistory.count
    }
}

final class MockEventObserver: ArchiveEventObserverProtocol, @unchecked Sendable {
    var receivedEvents: [ArchiveEvent] = []
    private let lock = NSLock()
    
    func onArchiveEvent(_ event: ArchiveEvent) {
        lock.lock()
        receivedEvents.append(event)
        lock.unlock()
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return receivedEvents.count
    }
}

final class MockCancellationObserver: TaskCancellationObserverProtocol, @unchecked Sendable {
    var cancelledTasks: [String] = []
    private let lock = NSLock()
    
    func onTaskCancelled(taskId: String) {
        lock.lock()
        cancelledTasks.append(taskId)
        lock.unlock()
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cancelledTasks.count
    }
}

/// 【3.2 (Observer Pattern)】 (`ObserverPatternTests`)
final class ObserverPatternTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        ArchiveProgressBroadcaster.shared.removeAllObservers()
        ArchiveEventCenter.shared.removeAllObservers()
        TaskCancellationObserverCenter.shared.reset()
    }
    
    override func tearDown() {
        ArchiveProgressBroadcaster.shared.removeAllObservers()
        ArchiveEventCenter.shared.removeAllObservers()
        TaskCancellationObserverCenter.shared.reset()
        super.tearDown()
    }
    
    // MARK: - 1. WeakObserver Retain Cycle & Memory Leak Defense
    
    func testWeakObserverAutoDeallocationInBroadcaster() {
        let broadcaster = ArchiveProgressBroadcaster.shared
        
        autoreleasepool {
            let observer = MockProgressObserver()
            broadcaster.addObserver(observer)
            XCTAssertEqual(broadcaster.observerCount, 1)
            
            broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: 50, totalBytes: 100))
            XCTAssertEqual(observer.receivedCount, 1)
        }
        
        // ，
        broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: 100, totalBytes: 100))
        XCTAssertEqual(broadcaster.observerCount, 0, "WeakObserver 包装器必须自动发现 nil 并从集合中剔除，消除泄露隐患")
    }
    
    func testWeakObserverAutoDeallocationInEventCenter() {
        let center = ArchiveEventCenter.shared
        
        autoreleasepool {
            let observer = MockEventObserver()
            center.addObserver(observer)
            XCTAssertEqual(center.observerCount, 1)
            
            center.postArchiveCompleted(archivePath: "/tmp/test.zip", operationType: .compress, duration: 0.5, totalBytes: 1000)
            XCTAssertEqual(observer.count, 1)
        }
        
        center.postPresetChanged(oldPresetName: "A", newPresetName: "B")
        XCTAssertEqual(center.observerCount, 0, "EventCenter 的弱引用包装器必须自动解构并释放归零")
    }
    
    // MARK: - 2. High Concurrency Thread Safety
    
    func testHighConcurrencyBroadcasterThreadSafety() {
        let broadcaster = ArchiveProgressBroadcaster.shared
        let group = DispatchGroup()
        let iterations = 100
        
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let obs = MockProgressObserver()
                broadcaster.addObserver(obs)
                broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: Int64(i), totalBytes: 1000, currentFileName: "file_\(i).txt"))
                broadcaster.removeObserver(obs)
                group.leave()
            }
        }
        
        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "高并发多线程并发注册/移除/广播不得死锁或发生内存越界")
    }
    
    func testHighConcurrencyEventCenterThreadSafety() {
        let center = ArchiveEventCenter.shared
        let group = DispatchGroup()
        let iterations = 100
        
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let obs = MockEventObserver()
                center.addObserver(obs, forEvents: [.archiveCompleted, .presetChanged])
                center.post(event: .archiveCompleted(archivePath: "test_\(i).zip", operationType: .compress, duration: 0.1, totalBytes: 100))
                center.removeObserver(obs)
                group.leave()
            }
        }
        
        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "EventCenter 在并发并发派发事件与注销时必须通过 NSLock 保护")
    }
    
    // MARK: - 3. 、
    
    func testEventFilteringInArchiveEventCenter() {
        let center = ArchiveEventCenter.shared
        let observerOnlyPreset = MockEventObserver()
        let observerAll = MockEventObserver()
        
        center.addObserver(observerOnlyPreset, forEvents: [.presetChanged])
        center.addObserver(observerAll)
        
        center.postArchiveCompleted(archivePath: "/tmp/a.zip", operationType: .compress, duration: 1.0, totalBytes: 200)
        center.postPresetChanged(oldPresetName: "Old", newPresetName: "New")
        
        XCTAssertEqual(observerOnlyPreset.count, 1, "只过滤预设变更事件的观察者不应收到归档完成事件")
        XCTAssertEqual(observerAll.count, 2, "未指定过滤器的观察者应接收到全部事件")
    }
    
    func testTaskCancellationObserverCenter() {
        let center = TaskCancellationObserverCenter.shared
        let taskId = "Task_Test_123"
        let mockObs = MockCancellationObserver()
        
        center.registerTask(taskId)
        center.addObserver(mockObs, forTask: taskId)
        XCTAssertFalse(center.isTaskCancelled(taskId))
        
        center.cancelTask(taskId)
        XCTAssertTrue(center.isTaskCancelled(taskId), "任务状态应即时标记为已取消")
        XCTAssertEqual(mockObs.count, 1, "取消监听器必须精准收到通知")
    }
    
    func testTaskCancellationAutoPruningAndFinishTask() {
        let center = TaskCancellationObserverCenter.shared
        let taskId = "Task_Prune_999"
        
        autoreleasepool {
            let mockObs = MockCancellationObserver()
            center.addObserver(mockObs, forTask: taskId)
            XCTAssertEqual(center.observerCount(forTask: taskId), 1)
            XCTAssertEqual(center.registeredObserverTaskCount, 1)
        }
        
        // ， prune
        center.prune()
        XCTAssertEqual(center.observerCount(forTask: taskId), 0)
        XCTAssertEqual(center.registeredObserverTaskCount, 0, "自动剪枝机制必须清空失效 taskId 字典键")
        
        // finishTask
        center.registerTask("Task_Finish_100")
        XCTAssertFalse(center.isTaskCancelled("Task_Finish_100"))
        center.finishTask("Task_Finish_100")
        XCTAssertEqual(center.registeredObserverTaskCount, 0)
    }
    
    func testWeakObserverDirectDispatching() {
        let broadcaster = ArchiveProgressBroadcaster.shared
        let mockObs = MockProgressObserver()
        broadcaster.addObserver(mockObs)
        
        broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: 10, totalBytes: 100))
        
        XCTAssertEqual(mockObs.receivedCount, 1, "观察者应直接收到通知")
    }
    
    // MARK: - 4. MB/s ETA 0 、NaN Infinity
    
    func testZeroDivisionThroughputAndETABoundary() {
        // 1. totalBytes == 0
        let zeroProgress = ArchiveProgressInfo(bytesProcessed: 0, totalBytes: 0, throughputMBs: 0.0)
        XCTAssertEqual(zeroProgress.fractionCompleted, 0.0, "totalBytes == 0 时 fractionCompleted 必须为 0.0，防止除零")
        
        // 2. NaN Infinity
        let nanInfo = ArchiveProgressInfo(
            bytesProcessed: -50,
            totalBytes: -100,
            throughputMBs: Double.nan,
            estimatedTimeRemaining: Double.infinity
        )
        XCTAssertEqual(nanInfo.bytesProcessed, 0, "负数 bytesProcessed 应自动兜底归零")
        XCTAssertEqual(nanInfo.totalBytes, 0, "负数 totalBytes 应自动兜底归零")
        XCTAssertEqual(nanInfo.throughputMBs, 0.0, "NaN 吞吐率必须兜底归零")
        XCTAssertNil(nanInfo.estimatedTimeRemaining, "Infinity ETA 必须兜底为 nil")
        
        // 3. BatchProgressInfo
        let nanBatch = BatchProgressInfo(
            completedTasks: -1,
            totalTasks: 0,
            throughputMBs: Double.infinity
        )
        XCTAssertEqual(nanBatch.fractionCompleted, 0.0)
        XCTAssertEqual(nanBatch.throughputMBs, 0.0)
        
        // 4. ArchiveProgressInfo.calculateETA
        let safeETA = ArchiveProgressInfo.calculateETA(bytesProcessed: 50, totalBytes: 100, throughputMBs: 10.0)
        XCTAssertNotNil(safeETA)
        
        let invalidETA1 = ArchiveProgressInfo.calculateETA(bytesProcessed: 100, totalBytes: 100, throughputMBs: 10.0)
        XCTAssertNil(invalidETA1, "已完成任务 ETA 必须返回 nil")
        
        let invalidETA2 = ArchiveProgressInfo.calculateETA(bytesProcessed: 10, totalBytes: 100, throughputMBs: 0.0)
        XCTAssertNil(invalidETA2, "吞吐率为 0 时 ETA 必须返回 nil 防止除零")
        
        let invalidETA3 = ArchiveProgressInfo.calculateETA(bytesProcessed: 10, totalBytes: 100, throughputMBs: Double.nan)
        XCTAssertNil(invalidETA3, "吞吐率为 NaN 时 ETA 必须返回 nil")
    }
    
    // MARK: - 5. Engine Facade & Batch Integration
    
    func testEngineFacadeAndBatchFacadeBroadcastIntegration() async throws {
        let broadcaster = ArchiveProgressBroadcaster.shared
        let eventCenter = ArchiveEventCenter.shared
        
        let mockObs = MockProgressObserver()
        let mockEventObs = MockEventObserver()
        
        broadcaster.addObserver(mockObs)
        eventCenter.addObserver(mockEventObs)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let file1 = (tempDir as NSString).appendingPathComponent("file1.txt")
        try "Hello Observer Pattern".write(toFile: file1, atomically: true, encoding: .utf8)
        
        let outZip = (tempDir as NSString).appendingPathComponent("output.zip")
        
        let res = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1],
            outputPath: outZip,
            format: .zip
        )
        
        XCTAssertGreaterThan(res.durationSeconds, 0)
        XCTAssertGreaterThan(mockObs.receivedCount, 0, "quickCompress 执行过程中必须向 ArchiveProgressBroadcaster 分发进度")
        XCTAssertTrue(mockEventObs.receivedEvents.contains { $0.eventType == .archiveCompleted }, "quickCompress 结束时必须发布 archiveCompleted 事件")
    }
    
    // MARK: - 6. 【 Round 3 Tertiary Audit 】
    
    func testRound31000PlusObserversHighFrequencyGCDDispatchAndLifecycleZeroLeak() {
        let broadcaster = ArchiveProgressBroadcaster.shared
        let eventCenter = ArchiveEventCenter.shared
        let cancellationCenter = TaskCancellationObserverCenter.shared
        
        let observerCountPerBatch = 1000
        let taskId = "Round3_Task_Exhaustive"
        cancellationCenter.registerTask(taskId)
        
        autoreleasepool {
            var progressObservers: [MockProgressObserver] = []
            var eventObservers: [MockEventObserver] = []
            var cancelObservers: [MockCancellationObserver] = []
            
            for _ in 0..<observerCountPerBatch {
                let pObs = MockProgressObserver()
                broadcaster.addObserver(pObs)
                progressObservers.append(pObs)
                
                let eObs = MockEventObserver()
                eventCenter.addObserver(eObs)
                eventObservers.append(eObs)
                
                let cObs = MockCancellationObserver()
                cancellationCenter.addObserver(cObs, forTask: taskId)
                cancelObservers.append(cObs)
            }
            
            XCTAssertEqual(broadcaster.observerCount, observerCountPerBatch)
            XCTAssertEqual(eventCenter.observerCount, observerCountPerBatch)
            XCTAssertEqual(cancellationCenter.observerCount(forTask: taskId), observerCountPerBatch)
            
            // Verify expected invariant
            let dispatchGroup = DispatchGroup()
            for i in 0..<50 {
                dispatchGroup.enter()
                DispatchQueue.global().async {
                    broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: Int64(i * 10), totalBytes: 1000, currentFileName: "file_\(i).dat"))
                    eventCenter.postArchiveCompleted(archivePath: "/tmp/round3_\(i).zip", operationType: .compress, duration: 0.05, totalBytes: 500)
                    dispatchGroup.leave()
                }
            }
            _ = dispatchGroup.wait(timeout: .now() + 5.0)
            
            // Verify expected invariant
            XCTAssertEqual(progressObservers.count, observerCountPerBatch)
            XCTAssertEqual(eventObservers.count, observerCountPerBatch)
            XCTAssertEqual(cancelObservers.count, observerCountPerBatch)
        }
        
        // ， observer ARC 。
        broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: 1000, totalBytes: 1000))
        eventCenter.postPresetChanged(oldPresetName: "A", newPresetName: "B")
        cancellationCenter.cancelTask(taskId)
        cancellationCenter.finishTask(taskId)
        
        // 100%
        XCTAssertEqual(broadcaster.observerCount, 0, "出作用域后 1000+ 观察者必须达到 100% 零强引用残存")
        XCTAssertEqual(eventCenter.observerCount, 0, "出作用域后 1000+ 事件观察者必须达到 100% 零残存")
        XCTAssertEqual(cancellationCenter.registeredObserverTaskCount, 0, "finishTask 清理后 taskId 映射必须 100% 归零")
    }
    
    func testRound3MultiThreadCrossRaceAddRemoveBroadcastFinishTaskConcurrency() {
        let broadcaster = ArchiveProgressBroadcaster.shared
        let eventCenter = ArchiveEventCenter.shared
        let cancellationCenter = TaskCancellationObserverCenter.shared
        
        let group = DispatchGroup()
        let iterations = 200
        
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let pObs = MockProgressObserver()
                let eObs = MockEventObserver()
                let cObs = MockCancellationObserver()
                let tId = "Task_Cross_\(i % 10)"
                
                cancellationCenter.registerTask(tId)
                
                broadcaster.addObserver(pObs)
                eventCenter.addObserver(eObs, forEvents: [.archiveCompleted])
                cancellationCenter.addObserver(cObs, forTask: tId)
                
                broadcaster.broadcastProgress(ArchiveProgressInfo(bytesProcessed: Int64(i), totalBytes: 200))
                broadcaster.broadcastBatchProgress(BatchProgressInfo(completedTasks: 1, totalTasks: 5))
                eventCenter.postArchiveCompleted(archivePath: "test_\(i).zip", operationType: .extract, duration: 0.01, totalBytes: 100)
                
                if i % 3 == 0 {
                    cancellationCenter.cancelTask(tId)
                } else if i % 5 == 0 {
                    cancellationCenter.finishTask(tId)
                }
                
                broadcaster.removeObserver(pObs)
                eventCenter.removeObserver(eObs)
                cancellationCenter.removeObserver(cObs, forTask: tId)
                
                group.leave()
            }
        }
        
        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "极端交叉多线程 register/unregister/broadcast/finishTask 必须绝对并发安全")
    }
    
    func testRound3ObserverReRegistrationWithUpdatedFilter() {
        let eventCenter = ArchiveEventCenter.shared
        let obs = MockEventObserver()
        
        eventCenter.addObserver(obs, forEvents: [.archiveCompleted])
        XCTAssertEqual(eventCenter.observerCount, 1)
        
        // filter
        eventCenter.addObserver(obs, forEvents: [.presetChanged])
        XCTAssertEqual(eventCenter.observerCount, 1, "重新注册观察者不得重复追加，必须更新现有订阅结构")
        
        eventCenter.postArchiveCompleted(archivePath: "/tmp/a.zip", operationType: .compress, duration: 0.1, totalBytes: 10)
        XCTAssertEqual(obs.count, 0, "更新 filter 后不应接收 archiveCompleted 事件")
        
        eventCenter.postPresetChanged(oldPresetName: "O", newPresetName: "N")
        XCTAssertEqual(obs.count, 1, "更新 filter 后必须接收到 presetChanged 事件")
    }

    func testPasswordVaultEventObservationViaArchiveEventCenter() throws {
        let observer = MockEventObserver()
        ArchiveEventCenter.shared.addObserver(observer)
        
        ArchiveEventCenter.shared.postPasswordVaultUnlocked(archivePath: "/tmp/test.zip", password: "pwd", isVaultUnlocked: true)
        
        let exp = expectation(description: "Event received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(observer.count, 1)
            if let evt = observer.receivedEvents.first {
                XCTAssertEqual(evt.eventType, .passwordVaultUnlocked)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

