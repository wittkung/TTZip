// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
@testable import TTZipApp

final class MementoPatternTests: XCTestCase {
    private var tempDirURL: URL!
    
    override func setUp() {
        super.setUp()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipMementoTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let tempDir = tempDirURL {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }
    
    // MARK: - 1. PresetEditorMemento & Caretaker Tests
    
    @MainActor
    func testPresetEditorMementoCreationAndRestore() {
        let vm = PresetWorkspaceViewModel()
        let initialPresetID = UUID()
        
        let memento = PresetEditorMemento(
            presetID: initialPresetID,
            name: "极限 7z 备份方案",
            format: .sevenZip,
            level: .ultra,
            splitVolumeSizeBytes: 1024 * 1024 * 100,
            skipMacJunk: true,
            skipGitDirectory: true,
            defaultPassword: "SecretPassword123"
        )
        
        vm.restoreMemento(memento)
        
        XCTAssertEqual(vm.editorName, "极限 7z 备份方案")
        XCTAssertEqual(vm.editorFormat, .sevenZip)
        XCTAssertEqual(vm.editorLevel, .ultra)
        XCTAssertEqual(vm.editorSplitVolumeOption, 1024 * 1024 * 100)
        XCTAssertTrue(vm.editorSkipMacJunk)
        XCTAssertTrue(vm.editorSkipGitDirectory)
        XCTAssertEqual(vm.editorDefaultPassword, "SecretPassword123")
        
        let exported = vm.createMemento()
        XCTAssertEqual(exported.name, "极限 7z 备份方案")
        XCTAssertEqual(exported.format, .sevenZip)
        XCTAssertEqual(exported.level, .ultra)
        XCTAssertEqual(exported.splitVolumeSizeBytes, 1024 * 1024 * 100)
    }
    
    func testPresetEditorCaretakerDualStackUndoRedo() {
        let caretaker = PresetEditorCaretaker(maxDepth: 10)
        let presetID = UUID()
        
        let memento1 = PresetEditorMemento(presetID: presetID, name: "Draft 1", format: .zip, level: .fast)
        let memento2 = PresetEditorMemento(presetID: presetID, name: "Draft 2", format: .zip, level: .normal)
        let memento3 = PresetEditorMemento(presetID: presetID, name: "Draft 3", format: .sevenZip, level: .ultra)
        
        caretaker.saveMemento(memento1)
        caretaker.saveMemento(memento2)
        caretaker.saveMemento(memento3)
        
        XCTAssertTrue(caretaker.canUndo)
        XCTAssertFalse(caretaker.canRedo)
        
        let undoResult1 = caretaker.undo()
        XCTAssertNotNil(undoResult1)
        XCTAssertEqual(undoResult1?.name, "Draft 2")
        XCTAssertTrue(caretaker.canRedo)
        
        let undoResult2 = caretaker.undo()
        XCTAssertNotNil(undoResult2)
        XCTAssertEqual(undoResult2?.name, "Draft 1")
        
        // Stack at bottom (only 1 item left in undo stack), canUndo should be false
        XCTAssertFalse(caretaker.canUndo)
        XCTAssertNil(caretaker.undo())
        
        // Redo test
        let redoResult1 = caretaker.redo()
        XCTAssertNotNil(redoResult1)
        XCTAssertEqual(redoResult1?.name, "Draft 2")
        
        let redoResult2 = caretaker.redo()
        XCTAssertNotNil(redoResult2)
        XCTAssertEqual(redoResult2?.name, "Draft 3")
        XCTAssertFalse(caretaker.canRedo)
    }
    
    func testPresetEditorCaretakerMaxDepthOverflow() {
        let caretaker = PresetEditorCaretaker(maxDepth: 5)
        let presetID = UUID()
        
        for i in 1...20 {
            let memento = PresetEditorMemento(presetID: presetID, name: "Draft \(i)", format: .zip, level: .normal)
            caretaker.saveMemento(memento)
        }
        
        XCTAssertEqual(caretaker.historyCount, 5)
        XCTAssertEqual(caretaker.peekUndo()?.name, "Draft 20")
    }
    
    func testPresetEditorCaretakerIdenticalMementoDeduplication() {
        let caretaker = PresetEditorCaretaker(maxDepth: 10)
        let presetID = UUID()
        let memento = PresetEditorMemento(presetID: presetID, name: "Duplicate Draft", format: .zip, level: .normal)
        
        caretaker.saveMemento(memento)
        caretaker.saveMemento(memento)
        caretaker.saveMemento(memento)
        
        XCTAssertEqual(caretaker.historyCount, 1)
    }
    
    func testPresetEditorCaretakerClear() {
        let caretaker = PresetEditorCaretaker(maxDepth: 10)
        let presetID = UUID()
        let memento1 = PresetEditorMemento(presetID: presetID, name: "Draft 1", format: .zip, level: .normal)
        let memento2 = PresetEditorMemento(presetID: presetID, name: "Draft 2", format: .zip, level: .normal)
        
        caretaker.saveMemento(memento1)
        caretaker.saveMemento(memento2)
        XCTAssertEqual(caretaker.historyCount, 2)
        
        caretaker.clear()
        XCTAssertEqual(caretaker.historyCount, 0)
        XCTAssertFalse(caretaker.canUndo)
        XCTAssertFalse(caretaker.canRedo)
    }
    
    // MARK: - 2. AppViewStateMemento & Caretaker Tests
    
    @MainActor
    func testAppViewStateMementoExportAndLoad() {
        let state = AppViewState()
        
        state.activeTab = .vault
        state.currentArchivePath = "/Users/test/archive.7z"
        state.searchQuery = "password"
        
        let snapshot = state.createMemento()
        XCTAssertEqual(snapshot.activeTab, .vault)
        XCTAssertEqual(snapshot.currentArchivePath, "/Users/test/archive.7z")
        XCTAssertEqual(snapshot.searchQuery, "password")
        
        state.activeTab = .home
        state.currentArchivePath = nil
        state.searchQuery = ""
        
        state.restoreMemento(snapshot)
        
        XCTAssertEqual(state.activeTab, .vault)
        XCTAssertEqual(state.currentArchivePath, "/Users/test/archive.7z")
        XCTAssertEqual(state.searchQuery, "password")
    }
    
    func testAppViewStateCaretakerUndoRedo() {
        let caretaker = AppViewStateCaretaker(maxDepth: 10)
        
        let snap1 = AppViewStateMemento(activeTab: .home, currentArchivePath: nil)
        let snap2 = AppViewStateMemento(activeTab: .compressWorkspace, currentArchivePath: nil)
        let snap3 = AppViewStateMemento(activeTab: .presets, currentArchivePath: "/path/to/archive.zip")
        
        caretaker.saveMemento(snap1)
        caretaker.saveMemento(snap2)
        caretaker.saveMemento(snap3)
        
        XCTAssertTrue(caretaker.canUndo)
        XCTAssertEqual(caretaker.undo()?.activeTab, .compressWorkspace)
        XCTAssertEqual(caretaker.undo()?.activeTab, .home)
        XCTAssertFalse(caretaker.canUndo)
        
        XCTAssertEqual(caretaker.redo()?.activeTab, .compressWorkspace)
        XCTAssertEqual(caretaker.redo()?.activeTab, .presets)
        XCTAssertFalse(caretaker.canRedo)
    }
    
    func testAppViewStateCaretakerClearAndPeek() {
        let caretaker = AppViewStateCaretaker(maxDepth: 10)
        let snap1 = AppViewStateMemento(activeTab: .home, currentArchivePath: nil)
        let snap2 = AppViewStateMemento(activeTab: .benchmark, currentArchivePath: nil)
        
        caretaker.saveMemento(snap1)
        caretaker.saveMemento(snap2)
        
        XCTAssertEqual(caretaker.currentSnapshot?.activeTab, .benchmark)
        XCTAssertEqual(caretaker.peekUndo()?.activeTab, .benchmark)
        
        _ = caretaker.undo()
        XCTAssertEqual(caretaker.peekRedo()?.activeTab, .benchmark)
        
        caretaker.clear()
        XCTAssertNil(caretaker.currentSnapshot)
        XCTAssertFalse(caretaker.canUndo)
        XCTAssertFalse(caretaker.canRedo)
    }
    
    // MARK: - 3. TaskCheckpointMemento & Caretaker Disk Persistence Tests
    
    func testTaskCheckpointMementoJSONSerialization() throws {
        let taskID = UUID()
        let memento = TaskCheckpointMemento(
            taskID: taskID,
            taskName: "BruteForceRecovery",
            stateName: "Running",
            processedBytes: 5000,
            totalBytes: 100000,
            dictionaryOffset: 5000,
            throughputTPS: 1250.5,
            checksum: "CRC32-5000"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(memento)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TaskCheckpointMemento.self, from: data)
        
        XCTAssertEqual(decoded.taskID, taskID)
        XCTAssertEqual(decoded.taskName, "BruteForceRecovery")
        XCTAssertEqual(decoded.stateName, "Running")
        XCTAssertEqual(decoded.processedBytes, 5000)
        XCTAssertEqual(decoded.totalBytes, 100000)
        XCTAssertEqual(decoded.dictionaryOffset, 5000)
        XCTAssertEqual(decoded.throughputTPS, 1250.5)
        XCTAssertEqual(decoded.checksum, "CRC32-5000")
    }
    
    func testTaskCheckpointCaretakerDiskPersistence() {
        let caretaker = TaskCheckpointCaretaker(customDirectory: tempDirURL)
        let taskID = UUID()
        
        let checkpoint = TaskCheckpointMemento(
            taskID: taskID,
            taskName: "EncryptedZipRecovery",
            stateName: "Paused",
            processedBytes: 4200,
            totalBytes: 10000,
            dictionaryOffset: 4200,
            throughputTPS: 850.0,
            checksum: "PAUSE-4200"
        )
        
        caretaker.saveCheckpoint(checkpoint)
        
        // Reload from disk caretaker instance
        let newCaretakerInstance = TaskCheckpointCaretaker(customDirectory: tempDirURL)
        let loaded = newCaretakerInstance.loadCheckpoint(taskID: taskID)
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.taskID, taskID)
        XCTAssertEqual(loaded?.taskName, "EncryptedZipRecovery")
        XCTAssertEqual(loaded?.stateName, "Paused")
        XCTAssertEqual(loaded?.processedBytes, 4200)
        XCTAssertEqual(loaded?.dictionaryOffset, 4200)
        XCTAssertEqual(loaded?.checksum, "PAUSE-4200")
    }
    
    func testTaskCheckpointCaretakerCorruptedJSONFaultTolerance() throws {
        let caretaker = TaskCheckpointCaretaker(customDirectory: tempDirURL)
        let taskID = UUID()
        
        let fileURL = tempDirURL.appendingPathComponent("checkpoint_\(taskID.uuidString).json")
        let corruptedData = "{ \"taskID\": \"invalid-json-content-bad-structure...".data(using: .utf8)!
        try corruptedData.write(to: fileURL)
        
        let result = caretaker.loadCheckpoint(taskID: taskID)
        XCTAssertNil(result, "Corrupted JSON should fail gracefully returning nil without crashing")
    }
    
    func testTaskCheckpointCaretakerListAndDelete() {
        let caretaker = TaskCheckpointCaretaker(customDirectory: tempDirURL)
        let taskID1 = UUID()
        let taskID2 = UUID()
        
        let cp1 = TaskCheckpointMemento(taskID: taskID1, taskName: "Task 1", stateName: "Running", processedBytes: 10, totalBytes: 100, dictionaryOffset: 10)
        let cp2 = TaskCheckpointMemento(taskID: taskID2, taskName: "Task 2", stateName: "Running", processedBytes: 20, totalBytes: 200, dictionaryOffset: 20)
        
        caretaker.saveCheckpoint(cp1)
        caretaker.saveCheckpoint(cp2)
        
        let list = caretaker.listCheckpoints()
        XCTAssertEqual(list.count, 2)
        
        caretaker.deleteCheckpoint(taskID: taskID1)
        let listAfterDelete = caretaker.listCheckpoints()
        XCTAssertEqual(listAfterDelete.count, 1)
        XCTAssertEqual(listAfterDelete.first?.taskID, taskID2)
        
        caretaker.clearAllCheckpoints()
        XCTAssertEqual(caretaker.listCheckpoints().count, 0)
    }
    
    func testTaskCheckpointCaretakerCustomDirectoryIsolation() {
        let customSubDir = tempDirURL.appendingPathComponent("CustomCheckpointsSubDir")
        let caretaker = TaskCheckpointCaretaker(customDirectory: customSubDir)
        let taskID = UUID()
        
        let cp = TaskCheckpointMemento(taskID: taskID, taskName: "IsolatedTask", stateName: "Completed", processedBytes: 100, totalBytes: 100, dictionaryOffset: 100)
        caretaker.saveCheckpoint(cp)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: customSubDir.appendingPathComponent("checkpoint_\(taskID.uuidString).json").path))
    }
    
    // MARK: - 4. Concurrency & Thread Safety Tests (100+ Threads)
    
    @MainActor
    func testHighConcurrency100ThreadsSnapshotCreation() async {
        let caretaker = PresetEditorCaretaker(maxDepth: 200)
        let checkpointCaretaker = TaskCheckpointCaretaker(customDirectory: tempDirURL, maxDepth: 200)
        let presetID = UUID()
        
        let exp = expectation(description: "100 Concurrent Threads Memento Access")
        exp.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            let memento = PresetEditorMemento(
                presetID: presetID,
                name: "Concurrent Preset \(iteration)",
                format: iteration % 2 == 0 ? .sevenZip : .zip,
                level: .normal
            )
            caretaker.saveMemento(memento)
            _ = caretaker.canUndo
            _ = caretaker.peekUndo()
            
            let cp = TaskCheckpointMemento(
                taskID: UUID(),
                taskName: "ConcurrentTask_\(iteration)",
                stateName: "Running",
                processedBytes: Int64(iteration * 100),
                totalBytes: 10000,
                dictionaryOffset: Int64(iteration * 100)
            )
            checkpointCaretaker.saveCheckpoint(cp)
            _ = checkpointCaretaker.canUndo
            
            exp.fulfill()
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        XCTAssertGreaterThan(caretaker.historyCount, 0)
        XCTAssertGreaterThan(checkpointCaretaker.listCheckpoints().count, 0)
    }
    
    // MARK: - 5. Integration Workflow Tests
    
    @MainActor
    func testPresetWorkspaceViewModelDraftOperations() {
        let vm = PresetWorkspaceViewModel()
        
        vm.editorName = "Test Preset Draft 1"
        vm.saveDraftSnapshot()
        
        vm.editorName = "Test Preset Draft 2"
        vm.saveDraftSnapshot()
        
        XCTAssertTrue(vm.canUndoDraft)
        vm.undoDraft()
        XCTAssertEqual(vm.editorName, "Test Preset Draft 1")
        
        XCTAssertTrue(vm.canRedoDraft)
        vm.redoDraft()
        XCTAssertEqual(vm.editorName, "Test Preset Draft 2")
    }
    
    @MainActor
    func testAppViewStateSnapshotWorkflow() {
        let appState = AppViewState()
        
        appState.activeTab = .benchmark
        appState.saveWorkspaceSnapshot()
        
        appState.activeTab = .vault
        appState.saveWorkspaceSnapshot()
        
        appState.restoreWorkspaceSnapshot()
        XCTAssertEqual(appState.activeTab, .benchmark)
    }
    
    func testPasswordRecoveryEngineCheckpointAutoSaveAndRestore() async throws {
        let checkpointCaretaker = TaskCheckpointCaretaker(customDirectory: tempDirURL)
        let engine = PasswordRecoveryEngine(checkpointCaretaker: checkpointCaretaker)
        let taskID = UUID()
        let sm = ArchiveTaskStateMachine(id: taskID, taskName: "IntegrationTestTask", totalBytes: 50)
        
        let testDir = tempDirURL.appendingPathComponent("TestArchiveDir")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let archiveFile = testDir.appendingPathComponent("test_mock.7z").path
        
        FileManager.default.createFile(atPath: archiveFile, contents: Data("MOCK".utf8))
        
        let dictionary = (1...25).map { "pwd\($0)" }
        
        _ = try? await engine.recoverPassword(archivePath: archiveFile, dictionary: dictionary, stateMachine: sm)
        
        let checkpoints = checkpointCaretaker.listCheckpoints()
        XCTAssertGreaterThan(checkpoints.count, 0, "Checkpoints should be saved automatically during execution")
        
        if let lastCheckpoint = checkpointCaretaker.loadCheckpoint(taskID: taskID) {
            XCTAssertEqual(lastCheckpoint.taskID, taskID)
            XCTAssertGreaterThan(lastCheckpoint.processedBytes, 0)
        }
    }
}
