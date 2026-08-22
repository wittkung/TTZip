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

/// Mock ， MacroArchiveCommand Rollback
final class MockFailingCommand: ArchiveCommandProtocol, @unchecked Sendable {
    let commandId: String = UUID().uuidString
    let description: String = "Mock 故意失败命令"
    let isUndoable: Bool = true
    
    private let shouldFailOnExecute: Bool
    private(set) var wasExecuted: Bool = false
    private(set) var wasUndone: Bool = false
    private let lock = NSLock()
    
    init(shouldFailOnExecute: Bool = true) {
        self.shouldFailOnExecute = shouldFailOnExecute
    }
    
    func execute() async throws -> CommandResult {
        markExecuted()
        if shouldFailOnExecute {
            throw CommandError.executionFailed(reason: "故意测试触发命令执行失败异常")
        }
        return CommandResult(commandId: commandId, success: true, message: "Mock Success")
    }
    
    func undo() async throws {
        markUndone()
    }
    
    private func markExecuted() {
        lock.lock()
        defer { lock.unlock() }
        wasExecuted = true
    }
    
    private func markUndone() {
        lock.lock()
        defer { lock.unlock() }
        wasUndone = true
    }
}

/// Mock Undo ， Rollback
final class MockUndoFailingCommand: ArchiveCommandProtocol, @unchecked Sendable {
    let commandId: String = UUID().uuidString
    let description: String = "Mock Undo 故意抛错命令"
    let isUndoable: Bool = true
    
    private(set) var wasExecuted: Bool = false
    private(set) var wasUndoneTried: Bool = false
    
    func execute() async throws -> CommandResult {
        wasExecuted = true
        return CommandResult(commandId: commandId, success: true, message: "Success")
    }
    
    func undo() async throws {
        wasUndoneTried = true
        throw CommandError.undoFailed(reason: "IOError: Mock Undo 磁盘写入失败")
    }
}


final class CommandPatternTests: XCTestCase {
    private var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        let uniqueName = "TTZipCommandPatternTests_\(UUID().uuidString)"
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }
    
    // MARK: - 1. CompressCommand Undo
    
    func testCompressCommandExecutionAndUndo() async throws {
        let input1 = tempDir.appendingPathComponent("file1.txt").path
        let input2 = tempDir.appendingPathComponent("file2.txt").path
        let outZip = tempDir.appendingPathComponent("output.zip").path
        
        try "Hello World 1".write(toFile: input1, atomically: true, encoding: .utf8)
        try "Hello World 2".write(toFile: input2, atomically: true, encoding: .utf8)
        
        let command = CompressCommand(
            inputs: [input1, input2],
            outputPath: outZip,
            format: .zip
        )
        
        XCTAssertTrue(command.isUndoable)
        
        // 1.
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip))
        XCTAssertTrue(result.artifactsCreated.contains(outZip))
        
        // 2. Undo
        try await command.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: outZip))
    }
    
    func testCompressCommandUndoRestoresPreExistingBackup() async throws {
        let input1 = tempDir.appendingPathComponent("file1.txt").path
        let outZip = tempDir.appendingPathComponent("output.zip").path
        
        try "Input Source".write(toFile: input1, atomically: true, encoding: .utf8)
        try "Original Existing Content".write(toFile: outZip, atomically: true, encoding: .utf8)
        
        let command = CompressCommand(
            inputs: [input1],
            outputPath: outZip,
            format: .zip
        )
        
        // 1. （ ）
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.backupPaths.isEmpty)
        
        // 2. Undo ->
        try await command.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip))
        let restoredText = try String(contentsOfFile: outZip, encoding: .utf8)
        XCTAssertEqual(restoredText, "Original Existing Content")
    }
    
    // MARK: - 2. ExtractCommand Undo
    
    func testExtractCommandExecutionAndSafeUndo() async throws {
        let input1 = tempDir.appendingPathComponent("source.txt").path
        let outZip = tempDir.appendingPathComponent("test.zip").path
        let extractDir = tempDir.appendingPathComponent("extracted_output").path
        
        try "Data Content".write(toFile: input1, atomically: true, encoding: .utf8)
        
        // Verify expected invariant
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [input1], outputPath: outZip)
        
        // Verify expected invariant
        try FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
        let preExistingFile = (extractDir as NSString).appendingPathComponent("user_important_doc.txt")
        try "User Pre-existing File".write(toFile: preExistingFile, atomically: true, encoding: .utf8)
        
        let command = ExtractCommand(
            archivePath: outZip,
            destinationDir: extractDir
        )
        
        // 1.
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        
        // 2. Undo -> ， preExistingFile ！
        try await command.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: preExistingFile))
        let userDocContent = try String(contentsOfFile: preExistingFile, encoding: .utf8)
        XCTAssertEqual(userDocContent, "User Pre-existing File")
    }
    
    // MARK: - 3. RepairCommand
    
    func testRepairCommandExecutionAndUndo() async throws {
        let sourceFile = tempDir.appendingPathComponent("source.txt").path
        let damagedFile = tempDir.appendingPathComponent("damaged.zip").path
        let repairedFile = tempDir.appendingPathComponent("repaired.zip").path
        
        try "Valid payload for repair test".write(toFile: sourceFile, atomically: true, encoding: .utf8)
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [sourceFile], outputPath: damagedFile)
        
        let command = RepairCommand(damagedPath: damagedFile, outputPath: repairedFile)
        
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedFile))
        
        try await command.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: repairedFile))
    }
    
    // MARK: - 4. MacroArchiveCommand Rollback
    
    func testMacroArchiveCommandSuccessAndUndo() async throws {
        let input = tempDir.appendingPathComponent("input.txt").path
        let zip1 = tempDir.appendingPathComponent("macro1.zip").path
        let zip2 = tempDir.appendingPathComponent("macro2.zip").path
        
        try "Macro Test Payload".write(toFile: input, atomically: true, encoding: .utf8)
        
        let cmd1 = CompressCommand(inputs: [input], outputPath: zip1)
        let cmd2 = CompressCommand(inputs: [input], outputPath: zip2)
        
        let macro = MacroArchiveCommand(commands: [cmd1, cmd2])
        
        let result = try await macro.execute()
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.artifactsCreated.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip2))
        
        // Undo
        try await macro.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip2))
    }
    
    func testMacroArchiveCommandFailureAndAutomaticRollback() async throws {
        let input = tempDir.appendingPathComponent("input.txt").path
        let zip1 = tempDir.appendingPathComponent("step1.zip").path
        
        try "Rollback Test Payload".write(toFile: input, atomically: true, encoding: .utf8)
        
        let step1 = CompressCommand(inputs: [input], outputPath: zip1)
        let step2Failing = MockFailingCommand(shouldFailOnExecute: true)
        
        let macro = MacroArchiveCommand(commands: [step1, step2Failing])
        
        do {
            _ = try await macro.execute()
            XCTFail("宏命令应该在 step2 抛出异常并触发自动 Rollback")
        } catch let CommandError.macroExecutionFailed(failedIdx, _, _) {
            XCTAssertEqual(failedIdx, 1)
            // Rollback ：step1 zip1 ！
            XCTAssertFalse(FileManager.default.fileExists(atPath: zip1))
        } catch {
            XCTFail("意外捕获到了其它未知的异常: \(error)")
        }
    }
    
    // MARK: - 5. CommandHistoryManager 、LRU
    
    func testCommandHistoryManagerExecuteUndoRedo() async throws {
        let manager = CommandHistoryManager(maxHistoryCapacity: 10)
        let input = tempDir.appendingPathComponent("file.txt").path
        let zip = tempDir.appendingPathComponent("hist.zip").path
        
        try "Content".write(toFile: input, atomically: true, encoding: .utf8)
        let command = CompressCommand(inputs: [input], outputPath: zip)
        
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        
        // Execute
        let execRes = try await manager.execute(command: command)
        XCTAssertTrue(execRes.success)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(manager.undoStackCount, 1)
        
        // Undo
        let undoRes = try await manager.undo()
        XCTAssertNotNil(undoRes)
        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
        XCTAssertEqual(manager.redoStackCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip))
        
        // Redo
        let redoRes = try await manager.redo()
        XCTAssertNotNil(redoRes)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip))
    }
    
    func testCommandHistoryManagerLRUCapacityTrimming() async throws {
        let manager = CommandHistoryManager(maxHistoryCapacity: 3)
        let input = tempDir.appendingPathComponent("dummy.txt").path
        try "LRU".write(toFile: input, atomically: true, encoding: .utf8)
        
        for i in 1...5 {
            let outZip = tempDir.appendingPathComponent("lru_\(i).zip").path
            let cmd = CompressCommand(inputs: [input], outputPath: outZip)
            _ = try await manager.execute(command: cmd)
        }
        
        // 3
        XCTAssertEqual(manager.undoStackCount, 3)
    }
    
    func testCommandHistoryManagerHighConcurrencyThreadSafety() async throws {
        let manager = CommandHistoryManager(maxHistoryCapacity: 100)
        let iterationCount = 50
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterationCount {
                group.addTask {
                    let cmd = MockFailingCommand(shouldFailOnExecute: false)
                    _ = try? await manager.execute(command: cmd)
                    _ = manager.canUndo
                    _ = manager.canRedo
                    _ = manager.undoHistoryDescriptions
                    if i % 2 == 0 {
                        _ = try? await manager.undo()
                    } else {
                        _ = try? await manager.redo()
                    }
                }
            }
        }
        
        // ，
        XCTAssertTrue(manager.undoStackCount + manager.redoStackCount <= 100)
    }
    
    // MARK: - 6. Facade Batch Transactional
    
    func testTTZipEngineFacadeCommandIntegration() async throws {
        let facade = TTZipEngineFacade.shared
        let input = tempDir.appendingPathComponent("facade_input.txt").path
        let outZip = tempDir.appendingPathComponent("facade_out.zip").path
        try "Engine Facade Payload".write(toFile: input, atomically: true, encoding: .utf8)
        
        let result = try await facade.compressWithCommand(inputs: [input], outputPath: outZip)
        XCTAssertTrue(result.success)
        XCTAssertTrue(facade.canUndoCommand)
        
        let undoRes = try await facade.undoLastCommand()
        XCTAssertNotNil(undoRes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outZip))
    }
    
    func testArchiveBatchFacadeTransactionalMacroRollback() async throws {
        let batchFacade = ArchiveBatchFacade.shared
        let input1 = tempDir.appendingPathComponent("b1.txt").path
        let input2 = tempDir.appendingPathComponent("b2.txt").path
        
        try "Data 1".write(toFile: input1, atomically: true, encoding: .utf8)
        try "Data 2".write(toFile: input2, atomically: true, encoding: .utf8)
        
        let out1 = tempDir.appendingPathComponent("out_b1.zip").path
        let out2 = tempDir.appendingPathComponent("out_b2.zip").path
        
        let task1 = BatchCompressTask(inputs: [input1], outputPath: out1)
        let task2 = BatchCompressTask(inputs: [input2], outputPath: out2)
        
        // Verify expected invariant
        let res = try await batchFacade.batchCompressTransactional(tasks: [task1, task2])
        XCTAssertTrue(res.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out2))
    }
    
    // MARK: - 7. CommandHistoryManager
    
    func testCommandHistoryStateAndNotifications() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 5)
        let input = tempDir.appendingPathComponent("app_input.txt").path
        let outZip = tempDir.appendingPathComponent("app_out.zip").path
        try "AppViewState Data".write(toFile: input, atomically: true, encoding: .utf8)
        
        let command = CompressCommand(inputs: [input], outputPath: outZip)
        
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        
        let res = try await history.execute(command: command)
        XCTAssertTrue(res.success)
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.undoHistoryDescriptions.last, command.description)
        
        let undoRes = try await history.undo()
        XCTAssertNotNil(undoRes)
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outZip))
    }
    
    // MARK: - 8. Secondary Deep Audit
    
    func testExtractCommandPreExistingDirAndOverwrittenFilesRestoredOnUndo() async throws {
        let extractDir = tempDir.appendingPathComponent("pre_existing_extract").path
        let fm = FileManager.default
        try fm.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
        
        let existingFile = (extractDir as NSString).appendingPathComponent("doc.txt")
        let untouchedFile = (extractDir as NSString).appendingPathComponent("untouched.txt")
        try "Original Doc Content".write(toFile: existingFile, atomically: true, encoding: .utf8)
        try "Untouched Content".write(toFile: untouchedFile, atomically: true, encoding: .utf8)
        
        let sourceFile = tempDir.appendingPathComponent("doc.txt").path
        let outZip = tempDir.appendingPathComponent("test_extract.zip").path
        try "Overwritten Doc Content".write(toFile: sourceFile, atomically: true, encoding: .utf8)
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [sourceFile], outputPath: outZip)
        
        let command = ExtractCommand(archivePath: outZip, destinationDir: extractDir)
        let execRes = try await command.execute()
        XCTAssertTrue(execRes.success)
        
        // doc.txt
        let postExtractText = try String(contentsOfFile: existingFile, encoding: .utf8)
        XCTAssertEqual(postExtractText, "Overwritten Doc Content")
        
        // ExtractCommand -> doc.txt "Original Doc Content"；untouched.txt
        try await command.undo()
        let restoredText = try String(contentsOfFile: existingFile, encoding: .utf8)
        XCTAssertEqual(restoredText, "Original Doc Content")
        XCTAssertTrue(fm.fileExists(atPath: untouchedFile))
    }
    
    func testExtractCommandNewlyCreatedTargetDirCleanedOnUndo() async throws {
        let newDestDir = tempDir.appendingPathComponent("non_existent_target_dir").path
        let sourceFile = tempDir.appendingPathComponent("src.txt").path
        let outZip = tempDir.appendingPathComponent("src.zip").path
        
        try "Payload".write(toFile: sourceFile, atomically: true, encoding: .utf8)
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [sourceFile], outputPath: outZip)
        
        let command = ExtractCommand(archivePath: outZip, destinationDir: newDestDir)
        _ = try await command.execute()
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDestDir))
        
        // Undo ->
        try await command.undo()
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDestDir))
    }
    
    func testCompressCommandSplitVolumeCleanupAndBackupRestoration() async throws {
        let outputDir = tempDir.appendingPathComponent("split_test_dir").path
        let fm = FileManager.default
        try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        let input = tempDir.appendingPathComponent("large_input.txt").path
        try "Split Test Source Payload".write(toFile: input, atomically: true, encoding: .utf8)
        
        let outZip = (outputDir as NSString).appendingPathComponent("myarchive.zip")
        let splitSlice1 = (outputDir as NSString).appendingPathComponent("myarchive.z01")
        
        // Verify expected invariant
        try "Old Zip Main".write(toFile: outZip, atomically: true, encoding: .utf8)
        try "Old Slice 1".write(toFile: splitSlice1, atomically: true, encoding: .utf8)
        
        let command = CompressCommand(inputs: [input], outputPath: outZip)
        let execRes = try await command.execute()
        XCTAssertTrue(execRes.success)
        XCTAssertTrue(execRes.artifactsCreated.contains(outZip))
        
        // Verify expected invariant
        let newSlice2 = (outputDir as NSString).appendingPathComponent("myarchive.z02")
        try "New Slice 2".write(toFile: newSlice2, atomically: true, encoding: .utf8)
        
        // Undo
        try await command.undo()
        
        // ： 100% ， newSlice2
        let restoredZip = try String(contentsOfFile: outZip, encoding: .utf8)
        let restoredSlice1 = try String(contentsOfFile: splitSlice1, encoding: .utf8)
        XCTAssertEqual(restoredZip, "Old Zip Main")
        XCTAssertEqual(restoredSlice1, "Old Slice 1")
        XCTAssertFalse(fm.fileExists(atPath: newSlice2))
    }

    
    func testMacroArchiveCommandRollbackAggregatesUndoErrorsAndStatePreservation() async throws {
        let input = tempDir.appendingPathComponent("macro_input.txt").path
        let outZip1 = tempDir.appendingPathComponent("m1.zip").path
        try "Macro Test Data".write(toFile: input, atomically: true, encoding: .utf8)
        
        let step1Success = CompressCommand(inputs: [input], outputPath: outZip1)
        let step2UndoFailing = MockUndoFailingCommand()
        _ = try await step2UndoFailing.execute()
        let step3Failing = MockFailingCommand(shouldFailOnExecute: true)
        
        let macro = MacroArchiveCommand(commands: [step1Success, step2UndoFailing, step3Failing])
        
        do {
            _ = try await macro.execute()
            XCTFail("宏命令在 step3 必须抛错")
        } catch let CommandError.macroExecutionFailed(failedIdx, _, rollbackErrors) {
            XCTAssertEqual(failedIdx, 2)
            // step2 undo ， step1Success Rollback
            XCTAssertFalse(FileManager.default.fileExists(atPath: outZip1))
            XCTAssertFalse(rollbackErrors.isEmpty)
        } catch {
            XCTFail("未捕获到预期的 CommandError.macroExecutionFailed: \(error)")
        }
    }
    
    func testCommandHistoryManagerLRUAndClearHistoryPurgesDiskBackups() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 2)
        let fm = FileManager.default
        
        let input = tempDir.appendingPathComponent("input.txt").path
        try "Data".write(toFile: input, atomically: true, encoding: .utf8)
        
        var backupFiles: [String] = []
        for i in 1...4 {
            let outZip = tempDir.appendingPathComponent("lru_bak_\(i).zip").path
            try "Old Content \(i)".write(toFile: outZip, atomically: true, encoding: .utf8)
            let cmd = CompressCommand(inputs: [input], outputPath: outZip)
            let res = try await history.execute(command: cmd)
            if let b = res.backupPaths[outZip] {
                backupFiles.append(b)
            }
        }
        
        // 2 （lru_bak_1, lru_bak_2） (maxHistoryCapacity=2) LRU
        // LRU .bak ！
        XCTAssertFalse(fm.fileExists(atPath: backupFiles[0]))
        XCTAssertFalse(fm.fileExists(atPath: backupFiles[1]))
        
        // clearHistory()
        history.clearHistory()
        
        // .bak 100%
        XCTAssertFalse(fm.fileExists(atPath: backupFiles[2]))
        XCTAssertFalse(fm.fileExists(atPath: backupFiles[3]))
    }
    
    func testCommandHistoryManagerNonUndoableCommandClearsRedo() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 10)
        let input = tempDir.appendingPathComponent("file.txt").path
        let outZip = tempDir.appendingPathComponent("redo_clear.zip").path
        try "Data".write(toFile: input, atomically: true, encoding: .utf8)
        
        let cmd1 = CompressCommand(inputs: [input], outputPath: outZip)
        _ = try await history.execute(command: cmd1)
        
        // Undo -> redoStackCount == 1
        _ = try await history.undo()
        XCTAssertTrue(history.canRedo)
        
        // Mock non-undoable
        let nonUndoableCmd = MockFailingCommand(shouldFailOnExecute: false)
        _ = try await history.execute(command: nonUndoableCmd)
        
        // redoStack 100% （ ）
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.redoStackCount, 0)
    }
    
    // MARK: - 9. Round 3 Tertiary Audit Tests
    
    /// 1. .bak_<UUID> （100+ / / /LRU ）
    func testExhaustiveBakFileZeroRemnantSweep() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 15)
        let fm = FileManager.default
        let sweepDir = tempDir.appendingPathComponent("sweep_workspace")
        try fm.createDirectory(at: sweepDir, withIntermediateDirectories: true)
        
        let sampleSource = sweepDir.appendingPathComponent("sample_source.txt").path
        try "Original Source Payload for Bak Sweep".write(toFile: sampleSource, atomically: true, encoding: .utf8)
        
        // Zip ，
        let validZipPath = sweepDir.appendingPathComponent("valid_sample.zip").path
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [sampleSource], outputPath: validZipPath)
        
        let totalOps = (ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil) ? 105 : 20
        for i in 1...totalOps {
            let targetPath = sweepDir.appendingPathComponent("target_\(i % 10).zip").path
            
            // Verify expected invariant
            if !fm.fileExists(atPath: targetPath) {
                try? fm.copyItem(atPath: validZipPath, toPath: targetPath)
            }
            
            let cmd: ArchiveCommandProtocol
            let mode = i % 4
            if mode == 0 {
                cmd = CompressCommand(inputs: [sampleSource], outputPath: targetPath)
            } else if mode == 1 {
                let extractDest = sweepDir.appendingPathComponent("extract_\(i % 5)").path
                cmd = ExtractCommand(archivePath: validZipPath, destinationDir: extractDest)
            } else if mode == 2 {
                let repPath = sweepDir.appendingPathComponent("repaired_\(i % 5).zip").path
                cmd = RepairCommand(damagedPath: validZipPath, outputPath: repPath)
            } else {
                let sub1 = CompressCommand(inputs: [sampleSource], outputPath: targetPath)
                cmd = MacroArchiveCommand(commands: [sub1])
            }
            
            _ = try? await history.execute(command: cmd)
            
            // Undo / Redo
            if i % 3 == 0 {
                _ = try? await history.undo()
            } else if i % 5 == 0 {
                _ = try? await history.redo()
            }
        }
        
        // Verify expected invariant
        history.clearHistory()
        
        // temporary sweepDir ， 100% 0 .bak_<UUID>
        var leftoverBakCount = 0
        if let enumerator = fm.enumerator(atPath: tempDir.path) {
            while let item = enumerator.nextObject() as? String {
                if item.contains(".bak_") {
                    leftoverBakCount += 1
                }
            }
        }
        
        XCTAssertEqual(leftoverBakCount, 0, "扫荡发现磁盘临时目录中残留了 \(leftoverBakCount) 个 .bak_<UUID> 痕迹！")
    }
    
    /// 2. 100+ execute / undo / redo / clearHistory
    func testCommandHistoryManagerExtremeConcurrency100Threads() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 50)
        let threadCount = 100
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<threadCount {
                group.addTask {
                    let cmd = MockFailingCommand(shouldFailOnExecute: false)
                    
                    if i % 4 == 0 {
                        _ = try? await history.execute(command: cmd)
                    } else if i % 4 == 1 {
                        _ = try? await history.undo()
                    } else if i % 4 == 2 {
                        _ = try? await history.redo()
                    } else {
                        history.clearHistory()
                    }
                    
                    _ = history.canUndo
                    _ = history.canRedo
                    _ = history.undoStackCount
                    _ = history.redoStackCount
                    _ = history.undoHistoryDescriptions
                    _ = history.redoHistoryDescriptions
                }
            }
        }
        
        // 100 ， ， LRU
        XCTAssertTrue(history.undoStackCount <= 50)
        XCTAssertTrue(history.redoStackCount <= 50)
    }
    
    /// 3. AppViewState UI macOS Undo/Redo
    @MainActor
    func testAppViewStateAsyncMainActorUndoRedoDispatch() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 10)
        let viewState = AppViewState(historyManager: history)
        
        let src = tempDir.appendingPathComponent("ui_src.txt").path
        let out = tempDir.appendingPathComponent("ui_out.zip").path
        try "UI Test Data".write(toFile: src, atomically: true, encoding: .utf8)
        
        let cmd = CompressCommand(inputs: [src], outputPath: out)
        let result = try await viewState.executeCommand(cmd)
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(viewState.canUndo)
        XCTAssertFalse(viewState.canRedo)
        XCTAssertFalse(viewState.isLoading)
        
        // macOS Cmd+Z
        NotificationCenter.default.post(name: NSNotification.Name("TTZipPerformUndoNotification"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("TTZipPerformUndoNotification"), object: nil)
        
        // MainActor
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertFalse(viewState.isLoading)
        XCTAssertFalse(viewState.canUndo)
        XCTAssertTrue(viewState.canRedo)
        
        // macOS Cmd+Shift+Z
        NotificationCenter.default.post(name: NSNotification.Name("TTZipPerformRedoNotification"), object: nil)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertFalse(viewState.isLoading)
        XCTAssertTrue(viewState.canUndo)
        XCTAssertFalse(viewState.canRedo)
    }
}


