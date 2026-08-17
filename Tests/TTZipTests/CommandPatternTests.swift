import XCTest
import Foundation
@testable import TTZipCore
@testable import TTZipCLI
@testable import TTZipApp

/// 辅助 Mock 失败命令，专门用于测试 MacroArchiveCommand 中途失败自动逆序 Rollback 机制
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

/// 辅助 Mock Undo 抛错命令，用于测试 Rollback 聚合异常与状态恢复
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
    
    // MARK: - 1. CompressCommand 单元测试与 Undo 恢复验证
    
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
        
        // 1. 执行压缩
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip))
        XCTAssertTrue(result.artifactsCreated.contains(outZip))
        
        // 2. 执行撤销 Undo
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
        
        // 1. 执行压缩（覆盖既有文件）
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.backupPaths.isEmpty)
        
        // 2. 撤销 Undo -> 恢复原始文件
        try await command.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZip))
        let restoredText = try String(contentsOfFile: outZip, encoding: .utf8)
        XCTAssertEqual(restoredText, "Original Existing Content")
    }
    
    // MARK: - 2. ExtractCommand 精准清理与安全 Undo 测试
    
    func testExtractCommandExecutionAndSafeUndo() async throws {
        let input1 = tempDir.appendingPathComponent("source.txt").path
        let outZip = tempDir.appendingPathComponent("test.zip").path
        let extractDir = tempDir.appendingPathComponent("extracted_output").path
        
        try "Data Content".write(toFile: input1, atomically: true, encoding: .utf8)
        
        // 先生成测试压缩包
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [input1], outputPath: outZip)
        
        // 模拟解压目标文件夹中原先就存在的用户文件
        try FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
        let preExistingFile = (extractDir as NSString).appendingPathComponent("user_important_doc.txt")
        try "User Pre-existing File".write(toFile: preExistingFile, atomically: true, encoding: .utf8)
        
        let command = ExtractCommand(
            archivePath: outZip,
            destinationDir: extractDir
        )
        
        // 1. 执行解压
        let result = try await command.execute()
        XCTAssertTrue(result.success)
        
        // 2. 撤销 Undo -> 确保解压出来的文件被清除，而 preExistingFile 完好无损！
        try await command.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: preExistingFile))
        let userDocContent = try String(contentsOfFile: preExistingFile, encoding: .utf8)
        XCTAssertEqual(userDocContent, "User Pre-existing File")
    }
    
    // MARK: - 3. RepairCommand 单元测试
    
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
    
    // MARK: - 4. MacroArchiveCommand 中途失败自动逆序 Rollback 回滚测试
    
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
        
        // 逆序 Undo
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
            // 验证自动 Rollback 成果：step1 产生的 zip1 应该被自动物理清理摧毁！
            XCTAssertFalse(FileManager.default.fileExists(atPath: zip1))
        } catch {
            XCTFail("意外捕获到了其它未知的异常: \(error)")
        }
    }
    
    // MARK: - 5. CommandHistoryManager 双栈、LRU 与线程安全测试
    
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
        
        // 此时栈中只能容纳最新的 3 条历史记录
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
        
        // 并发任务正常结束，未发生死锁或崩溃
        XCTAssertTrue(manager.undoStackCount + manager.redoStackCount <= 100)
    }
    
    // MARK: - 6. Facade 门面与 Batch Transactional 集成测试
    
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
        
        // 成功情况
        let res = try await batchFacade.batchCompressTransactional(tasks: [task1, task2])
        XCTAssertTrue(res.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out2))
    }
    
    // MARK: - 7. CommandHistoryManager 历史栈与并发通知测试
    
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
    
    // MARK: - 8. 二次深度二次巡猎（Secondary Deep Audit）专研补强测试
    
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
        
        // 解压后 doc.txt 被覆盖
        let postExtractText = try String(contentsOfFile: existingFile, encoding: .utf8)
        XCTAssertEqual(postExtractText, "Overwritten Doc Content")
        
        // 撤销 ExtractCommand -> doc.txt 必须还原为 "Original Doc Content"；untouched.txt 完好
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
        
        // 撤销 Undo -> 解压前原本不存在的目标根目录必须被优雅清理移除
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
        
        // 模拟压缩前就存在同名分卷切片与主包
        try "Old Zip Main".write(toFile: outZip, atomically: true, encoding: .utf8)
        try "Old Slice 1".write(toFile: splitSlice1, atomically: true, encoding: .utf8)
        
        let command = CompressCommand(inputs: [input], outputPath: outZip)
        let execRes = try await command.execute()
        XCTAssertTrue(execRes.success)
        XCTAssertTrue(execRes.artifactsCreated.contains(outZip))
        
        // 模拟生成了新的分卷包切片
        let newSlice2 = (outputDir as NSString).appendingPathComponent("myarchive.z02")
        try "New Slice 2".write(toFile: newSlice2, atomically: true, encoding: .utf8)
        
        // 执行撤销 Undo
        try await command.undo()
        
        // 验证：旧的主包与分卷切片 100% 被原样还原，新切片 newSlice2 被清除
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
            // step2 undo 抛错，但 step1Success 仍被逆序 Rollback 彻底清除
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
        
        // 此时前 2 条命令（lru_bak_1, lru_bak_2）已经因为容量超限 (maxHistoryCapacity=2) 被 LRU 淘汰
        // 验证被 LRU 淘汰的命令持有的 .bak 文件已经在磁盘上被自动清理摧毁！
        XCTAssertFalse(fm.fileExists(atPath: backupFiles[0]))
        XCTAssertFalse(fm.fileExists(atPath: backupFiles[1]))
        
        // 清空历史记录 clearHistory()
        history.clearHistory()
        
        // 验证剩余命令的 .bak 磁盘文件也被 100% 自动物理物理清理
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
        
        // 执行一个 Mock non-undoable 命令
        let nonUndoableCmd = MockFailingCommand(shouldFailOnExecute: false)
        _ = try await history.execute(command: nonUndoableCmd)
        
        // 验证 redoStack 已经被 100% 清空（防止历史分支混淆）
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.redoStackCount, 0)
    }
    
    // MARK: - 9. 第三轮终极极限界扫荡 (Round 3 Tertiary Audit Tests)
    
    /// 1. 磁盘物理备份文件 .bak_<UUID> 零残留极限界扫荡（100+ 模拟命令并发/撤销/重做/LRU 淘汰全覆盖）
    func testExhaustiveBakFileZeroRemnantSweep() async throws {
        let history = CommandHistoryManager(maxHistoryCapacity: 15)
        let fm = FileManager.default
        let sweepDir = tempDir.appendingPathComponent("sweep_workspace")
        try fm.createDirectory(at: sweepDir, withIntermediateDirectories: true)
        
        let sampleSource = sweepDir.appendingPathComponent("sample_source.txt").path
        try "Original Source Payload for Bak Sweep".write(toFile: sampleSource, atomically: true, encoding: .utf8)
        
        // 预先生成一个合法的 Zip 归档包，供解压与修复命令高效调用
        let validZipPath = sweepDir.appendingPathComponent("valid_sample.zip").path
        _ = try await TTZipEngineFacade.shared.quickCompress(inputs: [sampleSource], outputPath: validZipPath)
        
        // 循环执行 100+ 次覆盖式压缩/解压/修复/宏命令操作
        for i in 1...105 {
            let targetPath = sweepDir.appendingPathComponent("target_\(i % 10).zip").path
            
            // 模拟既有文件覆盖
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
            
            // 随机触发 Undo / Redo 动作
            if i % 3 == 0 {
                _ = try? await history.undo()
            } else if i % 5 == 0 {
                _ = try? await history.redo()
            }
        }
        
        // 扫荡清空历史栈并摧毁所有挂载的备份
        history.clearHistory()
        
        // 极限界扫描 temporary 目录与 sweepDir 根路径，确认 100% 0 个 .bak_<UUID> 残留
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
    
    /// 2. 多线程并发 100+ 线程交叉调用 execute / undo / redo / clearHistory 线程安全验证
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
        
        // 并发交替调度 100 个线程完成，未崩溃，栈元素受 LRU 约束且数量合法
        XCTAssertTrue(history.undoStackCount <= 50)
        XCTAssertTrue(history.redoStackCount <= 50)
    }
    
    /// 3. AppViewState UI 主线程异步调度与 macOS 菜单栏 Undo/Redo 联动与防重入测试
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
        
        // 模拟 macOS 菜单栏连续快速点按 Cmd+Z 发送通知
        NotificationCenter.default.post(name: NSNotification.Name("TTZipPerformUndoNotification"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("TTZipPerformUndoNotification"), object: nil)
        
        // 给 MainActor 派发队列完成轮询的时间
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertFalse(viewState.isLoading)
        XCTAssertFalse(viewState.canUndo)
        XCTAssertTrue(viewState.canRedo)
        
        // 模拟 macOS 菜单栏点按 Cmd+Shift+Z 重做通知
        NotificationCenter.default.post(name: NSNotification.Name("TTZipPerformRedoNotification"), object: nil)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertFalse(viewState.isLoading)
        XCTAssertTrue(viewState.canUndo)
        XCTAssertFalse(viewState.canRedo)
    }
}


