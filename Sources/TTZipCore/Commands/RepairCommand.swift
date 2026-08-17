import Foundation

/// 归档修复具体命令 (Concrete Command for Repair)
/// 封装归档包扫描与修复逻辑；支持撤销清理修复产物及还原原始损坏文件备份
public final class RepairCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool { true }
    
    public let damagedPath: String
    public let outputPath: String
    private let engineFacade: TTZipEngineFacading
    private let lock = NSLock()
    
    private var createdArtifacts: [String] = []
    private var backupFilePath: String? = nil
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        damagedPath: String,
        outputPath: String,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.commandId = commandId
        self.damagedPath = damagedPath
        self.outputPath = outputPath
        self.engineFacade = engineFacade
        
        let file = (damagedPath as NSString).lastPathComponent
        self.description = description ?? "修复损坏归档包 [\(file)]"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        // 1. 如果修复输出目标文件已存在或覆盖原文件，先进行备份
        let backupPathCandidate = "\(outputPath).bak_\(UUID().uuidString)"
        var backupMade: String? = nil
        if fm.fileExists(atPath: outputPath) {
            try? fm.copyItem(atPath: outputPath, toPath: backupPathCandidate)
            backupMade = backupPathCandidate
        }
        
        // 2. 执行归档修复引擎（若引擎抛错，立刻清理刚才创建的备份文件，防止磁盘残留！）
        let recoveredCount: Int
        do {
            recoveredCount = try await engineFacade.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
        } catch {
            if let b = backupMade, fm.fileExists(atPath: b) {
                try? fm.removeItem(atPath: b)
            }
            throw error
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        var artifacts: [String] = []
        if fm.fileExists(atPath: outputPath) {
            artifacts.append(outputPath)
        }
        
        saveExecutionState(artifacts: artifacts, backupPath: backupMade)
        
        var backupDict: [String: String] = [:]
        if let b = backupMade {
            backupDict[outputPath] = b
        }
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "归档包修复成功，恢复了 \(recoveredCount) 个数据块",
            artifactsCreated: artifacts,
            backupPaths: backupDict,
            executionDuration: duration,
            metadata: ["recoveredCount": "\(recoveredCount)"]
        )
    }
    
    public func undo() async throws {
        let (executed, artifacts, backup) = getUndoStateSnapshot()
        guard executed else {
            throw CommandError.invalidState(reason: "修复命令尚未执行，无法撤销")
        }
        
        let fm = FileManager.default
        
        // 1. 清理修复后生成的文件
        for path in artifacts {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
        
        // 2. 还原备份
        if let backup = backup, fm.fileExists(atPath: backup) {
            if fm.fileExists(atPath: outputPath) {
                try? fm.removeItem(atPath: outputPath)
            }
            do {
                try fm.moveItem(atPath: backup, toPath: outputPath)
            } catch {
                throw CommandError.undoFailed(reason: "修复备份还原失败: \(error.localizedDescription)")
            }
        }
        
        resetExecutionStateOnUndoSuccess()
    }
    
    public func purgeBackupResources() {
        lock.lock()
        let b = self.backupFilePath
        self.backupFilePath = nil
        lock.unlock()
        
        if let b = b, FileManager.default.fileExists(atPath: b) {
            try? FileManager.default.removeItem(atPath: b)
        }
    }
    
    // MARK: - 内部锁辅助方法

    
    private func saveExecutionState(artifacts: [String], backupPath: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.createdArtifacts = artifacts
        self.backupFilePath = backupPath
        self.isExecutedState = true
    }
    
    private func getUndoStateSnapshot() -> (executed: Bool, artifacts: [String], backup: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (self.isExecutedState, self.createdArtifacts, self.backupFilePath)
    }
    
    private func resetExecutionStateOnUndoSuccess() {
        lock.lock()
        defer { lock.unlock() }
        self.isExecutedState = false
        self.createdArtifacts.removeAll()
        self.backupFilePath = nil
    }
}
