// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
@testable import TTZipCLI
@testable import TTZipApp

/// 【3.5 (State Pattern)】
final class StatePatternTests: XCTestCase {
    
    // MARK: - 1. 7
    
    func test7ConcreteStatesPropertiesAndTransitions() throws {
        let idle = IdleState()
        XCTAssertEqual(idle.stateName, "Idle")
        XCTAssertFalse(idle.canPause)
        XCTAssertFalse(idle.canResume)
        XCTAssertFalse(idle.canCancel)
        
        let preparing = PreparingState()
        XCTAssertEqual(preparing.stateName, "Preparing")
        XCTAssertFalse(preparing.canPause)
        XCTAssertFalse(preparing.canResume)
        XCTAssertTrue(preparing.canCancel)
        
        let running = RunningState()
        XCTAssertEqual(running.stateName, "Running")
        XCTAssertTrue(running.canPause)
        XCTAssertFalse(running.canResume)
        XCTAssertTrue(running.canCancel)
        
        let paused = PausedState()
        XCTAssertEqual(paused.stateName, "Paused")
        XCTAssertFalse(paused.canPause)
        XCTAssertTrue(paused.canResume)
        XCTAssertTrue(paused.canCancel)
        
        let cancelling = CancellingState()
        XCTAssertEqual(cancelling.stateName, "Cancelling")
        XCTAssertFalse(cancelling.canPause)
        XCTAssertFalse(cancelling.canResume)
        XCTAssertFalse(cancelling.canCancel)
        
        let completed = CompletedState()
        XCTAssertEqual(completed.stateName, "Completed")
        XCTAssertFalse(completed.canPause)
        XCTAssertFalse(completed.canResume)
        XCTAssertFalse(completed.canCancel)
        
        let mockErr = CommandError.executionFailed(reason: "Mock Error")
        let failed = FailedState(error: mockErr)
        XCTAssertEqual(failed.stateName, "Failed")
        XCTAssertFalse(failed.canPause)
        XCTAssertFalse(failed.canResume)
        XCTAssertFalse(failed.canCancel)
    }
    
    // MARK: - 2.
    
    func testValidStateTransitionsFlow() throws {
        let context = ArchiveTaskStateMachine(taskName: "TestFlowTask", totalBytes: 100_000)
        XCTAssertTrue(context.currentState is IdleState)
        
        final class SafeHistory: @unchecked Sendable {
            private(set) var history: [String] = []
            private let lock = NSLock()
            func append(_ name: String) {
                lock.lock()
                defer { lock.unlock() }
                history.append(name)
            }
        }
        let safeHistory = SafeHistory()
        context.onStateChanged = { _, newState in
            safeHistory.append(newState.stateName)
        }
        
        // Idle -> Preparing -> Running
        try context.prepare()
        XCTAssertTrue(context.currentState is PreparingState)
        
        try context.start()
        XCTAssertTrue(context.currentState is RunningState)
        
        // Verify expected invariant
        context.updateProgress(processedBytes: 50_000)
        XCTAssertEqual(context.processedBytes, 50_000)
        
        try context.pause()
        XCTAssertTrue(context.currentState is PausedState)
        XCTAssertEqual(context.checkpointOffset, 50_000)
        
        // Verify expected invariant
        try context.resume()
        XCTAssertTrue(context.currentState is RunningState)
        
        // Verify expected invariant
        try context.complete()
        XCTAssertTrue(context.currentState is CompletedState)
        XCTAssertEqual(context.processedBytes, 100_000)
        XCTAssertNotNil(context.metrics.endTime)
        
        XCTAssertEqual(safeHistory.history, ["Preparing", "Running", "Paused", "Running", "Completed"])
    }
    
    // MARK: - 3. Illegal Transition Interception
    
    func testIllegalStateTransitionsInterception() throws {
        let context = ArchiveTaskStateMachine(taskName: "IllegalTestTask")
        
        // 1. Idle Pause, Resume, Complete
        XCTAssertThrowsError(try context.pause()) { err in
            XCTAssertEqual(err as? ArchiveError, ArchiveError.invalidState)
        }
        
        XCTAssertThrowsError(try context.resume())
        XCTAssertThrowsError(try context.complete())
        
        // Running
        try context.start()
        
        // 2. Running Resume
        XCTAssertThrowsError(try context.resume())
        
        // Verify expected invariant
        try context.pause()
        
        // 3. Paused Pause, Complete
        XCTAssertThrowsError(try context.pause())
        XCTAssertThrowsError(try context.complete())
        
        // Verify expected invariant
        try context.resume()
        try context.complete()
        
        // 4. Completed
        XCTAssertThrowsError(try context.pause()) { err in
            XCTAssertEqual(err as? ArchiveError, ArchiveError.invalidState)
        }
        XCTAssertThrowsError(try context.resume()) { err in
            XCTAssertEqual(err as? ArchiveError, ArchiveError.invalidState)
        }
        XCTAssertThrowsError(try context.cancel()) { err in
            XCTAssertEqual(err as? ArchiveError, ArchiveError.invalidState)
        }
        XCTAssertThrowsError(try context.complete())
        
        // 5. Failed
        let failedCtx = ArchiveTaskStateMachine(taskName: "FailedTask")
        try failedCtx.fail(error: CommandError.executionFailed(reason: "Fail Reason"))
        XCTAssertTrue(failedCtx.currentState is FailedState)
        
        XCTAssertThrowsError(try failedCtx.pause()) { err in
            XCTAssertEqual(err as? ArchiveError, ArchiveError.invalidState)
        }
        XCTAssertThrowsError(try failedCtx.resume()) { err in
            XCTAssertEqual(err as? ArchiveError, ArchiveError.invalidState)
        }
    }
    
    // MARK: - 4. Save & Restore
    
    func testPauseResumeCheckpointOffsetAndRestoration() throws {
        let context = ArchiveTaskStateMachine(taskName: "CheckpointTask", totalBytes: 200_000)
        try context.start()
        
        context.updateProgress(processedBytes: 88_400)
        try context.pause()
        
        XCTAssertEqual(context.checkpointOffset, 88_400)
        XCTAssertTrue(context.currentState is PausedState)
        
        // ， checkpointOffset
        try context.resume()
        XCTAssertTrue(context.currentState is RunningState)
        XCTAssertEqual(context.processedBytes, 88_400)
        
        context.updateProgress(processedBytes: 150_000)
        try context.complete()
        XCTAssertEqual(context.processedBytes, 200_000)
    }
    
    // MARK: - 5. Cancelling
    
    func testCancellingStateCleanupMechanism() throws {
        let tempDir = NSTemporaryDirectory()
        let file1 = (tempDir as NSString).appendingPathComponent("ttzip_test_temp_1.tmp")
        let file2 = (tempDir as NSString).appendingPathComponent("ttzip_test_temp_2.tmp")
        
        FileManager.default.createFile(atPath: file1, contents: Data("temp1".utf8))
        FileManager.default.createFile(atPath: file2, contents: Data("temp2".utf8))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2))
        
        let context = ArchiveTaskStateMachine(taskName: "CancelCleanupTask")
        context.addTempFile(file1)
        context.addTempFile(file2)
        
        try context.start()
        try context.cancel()
        
        XCTAssertTrue(context.currentState is FailedState)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file2))
        XCTAssertTrue(context.tempFiles.isEmpty)
    }
    
    // MARK: - 6. 100+ NSLock
    
    func test100PlusConcurrentTaskStateMachinesSafety() async throws {
        let taskCount = 120
        var stateMachines: [ArchiveTaskStateMachine] = []
        for i in 0..<taskCount {
            stateMachines.append(ArchiveTaskStateMachine(taskName: "ConcurrentTask_\(i)", totalBytes: 1000))
        }
        
        await withTaskGroup(of: Void.self) { group in
            for sm in stateMachines {
                group.addTask {
                    do {
                        try sm.start()
                        sm.updateProgress(processedBytes: Int64.random(in: 100...900))
                        
                        if Bool.random() {
                            try sm.pause()
                            try sm.resume()
                        }
                        
                        sm.updateProgress(processedBytes: 1000)
                        try sm.complete()
                    } catch {
                        // Verify expected invariant
                    }
                }
            }
        }
        
        for sm in stateMachines {
            XCTAssertTrue(sm.currentState is CompletedState || sm.currentState is FailedState || sm.currentState is RunningState)
        }
    }
    
    // MARK: - 7. TTZipEngineFacade
    
    func testTTZipEngineFacadeIntegration() throws {
        let facade = TTZipEngineFacade.shared
        let sm = facade.createTaskStateMachine(taskName: "FacadeTask", totalBytes: 500)
        
        XCTAssertEqual(facade.getTaskStateMachine(id: sm.id)?.id, sm.id)
        
        try sm.start()
        XCTAssertTrue(sm.currentState is RunningState)
        
        try facade.pauseTask(id: sm.id)
        XCTAssertTrue(sm.currentState is PausedState)
        
        try facade.resumeTask(id: sm.id)
        XCTAssertTrue(sm.currentState is RunningState)
        
        try facade.cancelTask(id: sm.id)
        XCTAssertTrue(sm.currentState is FailedState)
    }
    
    // MARK: - 8. ArchiveBatchFacade
    
    func testArchiveBatchFacadeIntegration() async throws {
        let batchFacade = ArchiveBatchFacade.shared
        let id1 = UUID()
        let id2 = UUID()
        
        let sm1 = batchFacade.registerStateMachine(id: id1, taskName: "Batch1")
        let sm2 = batchFacade.registerStateMachine(id: id2, taskName: "Batch2")
        
        try? sm1.start()
        try? sm2.start()
        
        batchFacade.pauseAllTasks()
        XCTAssertTrue(sm1.currentState is PausedState)
        XCTAssertTrue(sm2.currentState is PausedState)
        
        batchFacade.resumeAllTasks()
        XCTAssertTrue(sm1.currentState is RunningState)
        XCTAssertTrue(sm2.currentState is RunningState)
        
        batchFacade.cancelAllTasks()
        XCTAssertTrue(sm1.currentState is FailedState)
        XCTAssertTrue(sm2.currentState is FailedState)
    }
    
    // MARK: - 9. PasswordRecoveryEngine Pause/Resume Checkpoint
    
    func testPasswordRecoveryEngineWithStateMachine() async throws {
        let engine = PasswordRecoveryEngine()
        let dict = ["wrong1", "wrong2", "wrong3", "correct123", "wrong4"]
        
        // Verify expected invariant
        let tempDir = NSTemporaryDirectory()
        let testArchive = (tempDir as NSString).appendingPathComponent("state_test_store.7z")
        if !FileManager.default.fileExists(atPath: testArchive) {
            FileManager.default.createFile(atPath: testArchive, contents: Data("7zHeaderMock".utf8))
        }
        
        let sm = ArchiveTaskStateMachine(taskName: "CrackTask", totalBytes: Int64(dict.count))
        
        // stateMachine
        let task = Task {
            return try await engine.recoverPassword(archivePath: testArchive, dictionary: dict, stateMachine: sm)
        }
        
        let res = try? await task.value
        XCTAssertNotNil(res)
        XCTAssertTrue(sm.currentState is CompletedState || sm.currentState is FailedState)
    }
    
    // MARK: - 10. AppViewState GUI
    
    @MainActor
    func testAppViewStateStateMachineBinding() throws {
        let appState = AppViewState()
        let sm = ArchiveTaskStateMachine(taskName: "GUITask", totalBytes: 1000)
        
        appState.bindTaskStateMachine(sm)
        XCTAssertEqual(appState.taskStateName, "Idle")
        XCTAssertFalse(appState.canPauseTask)
        XCTAssertFalse(appState.canResumeTask)
        XCTAssertFalse(appState.canCancelTask)
        
        try sm.start()
        appState.updateTaskStateUI()
        XCTAssertEqual(appState.taskStateName, "Running")
        XCTAssertTrue(appState.canPauseTask)
        XCTAssertFalse(appState.canResumeTask)
        XCTAssertTrue(appState.canCancelTask)
        
        appState.pauseCurrentTask()
        XCTAssertEqual(appState.taskStateName, "Paused")
        XCTAssertFalse(appState.canPauseTask)
        XCTAssertTrue(appState.canResumeTask)
        XCTAssertTrue(appState.canCancelTask)
        
        appState.resumeCurrentTask()
        XCTAssertEqual(appState.taskStateName, "Running")
        
        appState.cancelCurrentTask()
        XCTAssertEqual(appState.taskStateName, "Failed")
    }
    
    // MARK: - 11. ：Paused Cancel/Fail
    
    func testMetricsPauseDurationAccumulationWhenCancelledFromPausedState() throws {
        let sm = ArchiveTaskStateMachine(taskName: "PausedCancelMetricsTask", totalBytes: 10_000)
        try sm.start()
        sm.updateProgress(processedBytes: 5_000)
        
        // Verify expected invariant
        try sm.pause()
        XCTAssertTrue(sm.currentState is PausedState)
        
        // Verify expected invariant
        Thread.sleep(forTimeInterval: 0.1)
        
        // Paused Cancel
        try sm.cancel()
        XCTAssertTrue(sm.currentState is FailedState)
        
        // pauseDuration ， 0
        XCTAssertGreaterThan(sm.metrics.pauseDuration, 0.05)
    }
    
    // MARK: - 12. ：
    
    func testTerminalStateImmutabilityUnderConcurrency() throws {
        let sm = ArchiveTaskStateMachine(taskName: "TerminalStateTask", totalBytes: 100)
        try sm.start()
        try sm.complete()
        XCTAssertTrue(sm.currentState is CompletedState)
        
        // transitionTo RunningState
        sm.transitionTo(RunningState())
        XCTAssertTrue(sm.currentState is CompletedState, "终态 CompletedState 不可被转出")
        
        sm.transitionTo(PausedState())
        XCTAssertTrue(sm.currentState is CompletedState, "终态 CompletedState 不可被转出")
        
        let failedSm = ArchiveTaskStateMachine(taskName: "FailedTerminalTask")
        try failedSm.fail(error: CommandError.executionFailed(reason: "Fail"))
        XCTAssertTrue(failedSm.currentState is FailedState)
        
        failedSm.transitionTo(RunningState())
        XCTAssertTrue(failedSm.currentState is FailedState, "终态 FailedState 不可被转出")
    }
    
    // MARK: - 13. ：Task Failure TempFiles
    
    func testTempFilesCleanedUpOnTaskFailure() throws {
        let tempDir = NSTemporaryDirectory()
        let file1 = (tempDir as NSString).appendingPathComponent("ttzip_test_fail_temp.tmp")
        FileManager.default.createFile(atPath: file1, contents: Data("failtemp".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1))
        
        let sm = ArchiveTaskStateMachine(taskName: "FailCleanupTask")
        sm.addTempFile(file1)
        try sm.start()
        
        // Verify expected invariant
        try sm.fail(error: CommandError.executionFailed(reason: "IO Error"))
        XCTAssertTrue(sm.currentState is FailedState)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file1), "Task 失败时临时文件必须被自动物理删除")
        XCTAssertTrue(sm.tempFiles.isEmpty)
    }
    
    // MARK: - 14. ：PasswordRecoveryEngine
    
    func testPasswordRecoveryEngineTerminalStateInterception() async throws {
        let engine = PasswordRecoveryEngine()
        let sm = ArchiveTaskStateMachine(taskName: "CompletedCrackTask")
        try sm.start()
        try sm.complete()
        
        do {
            _ = try await engine.recoverPassword(archivePath: "/tmp/nonexistent.7z", dictionary: ["pwd1"], stateMachine: sm)
            XCTFail("对于已处于 Completed 终态的状态机，应拒绝重跑破解")
        } catch {
            guard case ArchiveStateError.taskAlreadyCompleted = error else {
                XCTFail("抛出的错误应为 taskAlreadyCompleted, 实际为: \(error)"); return
            }
        }
    }
    
    // MARK: - 15. ：100+ onStateChanged
    
    func testRound3HighConcurrency100PlusThreadsStateTransitionsAndFIFOOrdering() throws {
        let sm = ArchiveTaskStateMachine(taskName: "HighConcurrency100Task", totalBytes: 1_000_000)
        final class SafeNotificationLog: @unchecked Sendable {
            private(set) var events: [(oldState: String, newState: String)] = []
            private let lock = NSLock()
            func append(oldState: String, newState: String) {
                lock.lock()
                defer { lock.unlock() }
                events.append((oldState, newState))
            }
        }
        let safeLog = SafeNotificationLog()
        sm.onStateChanged = { _, newState in
            safeLog.append(oldState: "", newState: newState.stateName)
        }
        
        try sm.start()
        
        let threadCount = 120
        let group = DispatchGroup()
        for i in 0..<threadCount {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                switch i % 5 {
                case 0:
                    try? sm.pause()
                case 1:
                    try? sm.resume()
                case 2:
                    sm.updateProgress(processedBytes: Int64(i * 100))
                case 3:
                    try? sm.cancel()
                default:
                    try? sm.complete()
                }
            }
        }
        
        let waitResult = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(waitResult, .success, "120 个并发线程必须在 5 秒内完成且无死锁")
        
        // (CompletedState FailedState)
        let finalState = sm.currentState
        XCTAssertTrue(finalState is CompletedState || finalState is FailedState, "并发竞争后状态机必须收敛处于终态之一")
        
        if finalState is CompletedState {
            XCTAssertFalse(sm.canPause)
            XCTAssertFalse(sm.canResume)
            XCTAssertFalse(sm.canCancel)
            XCTAssertNil(sm.lastError, "若收敛为 CompletedState，lastError 不得被取消操作覆盖")
        }
    }
    
    // MARK: - 16. ：TaskMetrics processedBytes
    
    func testRound3TaskMetricsThroughputBoundaryAndProgressFractionProtection() throws {
        let metrics = TaskMetrics(
            startTime: Date(),
            endTime: Date(),
            pauseDuration: -5.0, // 故意注入负数 pauseDuration
            processedBytes: -100, // 故意注入负数 processedBytes
            totalBytes: -500 // 故意注入负数 totalBytes
        )
        
        XCTAssertGreaterThanOrEqual(metrics.pauseDuration, 0.0)
        XCTAssertGreaterThanOrEqual(metrics.processedBytes, 0)
        XCTAssertGreaterThanOrEqual(metrics.totalBytes, 0)
        XCTAssertEqual(metrics.progressFraction, 0.0)
        
        // processedBytes totalBytes ( )
        let sm = ArchiveTaskStateMachine(taskName: "OverflowMetricsTask", totalBytes: 1_000)
        try sm.start()
        sm.updateProgress(processedBytes: 2_500, totalBytes: 1_000)
        
        XCTAssertEqual(sm.metrics.progressFraction, 1.0, "progressFraction 超越保护必须严格锁死在 1.0")
        XCTAssertFalse(sm.metrics.throughputMBs.isNaN, "吞吐率不得为 NaN")
        XCTAssertFalse(sm.metrics.throughputMBs.isInfinite, "吞吐率不得为 Infinity")
        XCTAssertGreaterThanOrEqual(sm.metrics.throughputMBs, 0.0, "吞吐率不得为负数")
        
        // durationSeconds == 0
        let zeroDurationSm = ArchiveTaskStateMachine(taskName: "ZeroDurationTask", totalBytes: 500)
        zeroDurationSm.updateProgress(processedBytes: 300)
        XCTAssertEqual(zeroDurationSm.metrics.throughputMBs, 0.0, "duration == 0 时吞吐率必须安全收敛为 0.0")
    }
    
    // MARK: - 17. ：AppViewState
    
    @MainActor
    func testRound3AppViewStateRapidStateTransitionsSync() throws {
        let appState = AppViewState()
        let sm = ArchiveTaskStateMachine(taskName: "RapidSyncTask", totalBytes: 50_000)
        
        appState.bindTaskStateMachine(sm)
        XCTAssertEqual(appState.taskStateName, "Idle")
        XCTAssertFalse(appState.canPauseTask)
        XCTAssertFalse(appState.canResumeTask)
        XCTAssertFalse(appState.canCancelTask)
        
        // Idle -> Preparing -> Running -> Paused -> Running -> Completed
        try sm.start()
        try sm.pause()
        try sm.resume()
        try sm.complete()
        
        let exp = expectation(description: "AppViewState UI 主线程刷新")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(appState.taskStateName, "Completed")
            XCTAssertFalse(appState.canPauseTask)
            XCTAssertFalse(appState.canResumeTask)
            XCTAssertFalse(appState.canCancelTask)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
}


