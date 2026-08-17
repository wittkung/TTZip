import Foundation

/// 组合命令/宏命令 (Macro / Composite Command)
/// 组装并顺序执行一组命令；支持多步骤联动，并在中途任意步骤失败时，自动触发逆序 Rollback 撤销回滚
public final class MacroArchiveCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool {
        commands.allSatisfy { $0.isUndoable }
    }
    
    public let commands: [ArchiveCommandProtocol]
    private let lock = NSLock()
    
    private var executedSubCommands: [ArchiveCommandProtocol] = []
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        commands: [ArchiveCommandProtocol]
    ) {
        self.commandId = commandId
        self.commands = commands
        self.description = description ?? "宏命令 (包含 \(commands.count) 个原子步骤)"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        clearExecutedList()
        
        var combinedArtifacts: [String] = []
        var combinedBackups: [String: String] = [:]
        
        for (index, command) in commands.enumerated() {
            do {
                let subResult = try await command.execute()
                
                appendExecutedCommand(command)
                
                combinedArtifacts.append(contentsOf: subResult.artifactsCreated)
                for (k, v) in subResult.backupPaths {
                    combinedBackups[k] = v
                }
            } catch {
                // ⚠️ 捕获到中途步骤失败：自动触发逆序 Rollback 回滚
                let rollbackErrors = await performRollback()
                
                throw CommandError.macroExecutionFailed(
                    failedIndex: index,
                    underlyingError: error.localizedDescription,
                    rollbackErrors: rollbackErrors
                )
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        markAsExecuted()
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "宏命令顺利执行完成 (\(commands.count) 个子步骤)",
            artifactsCreated: combinedArtifacts,
            backupPaths: combinedBackups,
            executionDuration: duration
        )
    }
    
    public func undo() async throws {
        let (executed, toUndo) = getUndoStateAndReset()
        guard executed || !toUndo.isEmpty else {
            throw CommandError.invalidState(reason: "宏命令尚未执行，无法撤销")
        }
        
        var undoErrors: [String] = []
        var remainingCommands = toUndo
        
        for command in toUndo.reversed() {
            do {
                if command.isUndoable {
                    try await command.undo()
                }
                _ = remainingCommands.popLast()
            } catch {
                undoErrors.append("撤销 [\(command.description)] 失败: \(error.localizedDescription)")
            }
        }
        
        if !undoErrors.isEmpty {
            // 撤销部分步骤发生失败，还原剩余未完成撤销的子命令状态以备后置重试
            restoreUnfinishedState(remainingCommands)
            throw CommandError.undoFailed(reason: undoErrors.joined(separator: "; "))
        }
    }
    
    public func purgeBackupResources() {
        for command in commands {
            command.purgeBackupResources()
        }
    }
    
    // MARK: - 内部 Rollback 辅助方法
    
    private func performRollback() async -> [String] {
        let toRollback = getExecutedListAndReset()
        
        var rollbackErrors: [String] = []
        for command in toRollback.reversed() {
            do {
                if command.isUndoable {
                    try await command.undo()
                }
            } catch {
                rollbackErrors.append("回滚命令 [\(command.description)] 失败: \(error.localizedDescription)")
            }
        }
        
        return rollbackErrors
    }
    
    // MARK: - 内部同步锁辅助函数
    
    private func clearExecutedList() {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands.removeAll()
        isExecutedState = false
    }
    
    private func appendExecutedCommand(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands.append(command)
    }
    
    private func markAsExecuted() {
        lock.lock()
        defer { lock.unlock() }
        isExecutedState = true
    }
    
    private func restoreUnfinishedState(_ unfinished: [ArchiveCommandProtocol]) {
        lock.lock()
        defer { lock.unlock() }
        executedSubCommands = unfinished
        isExecutedState = !unfinished.isEmpty
    }
    
    private func getExecutedListAndReset() -> [ArchiveCommandProtocol] {
        lock.lock()
        defer { lock.unlock() }
        let list = executedSubCommands
        executedSubCommands.removeAll()
        isExecutedState = false
        return list
    }
    
    private func getUndoStateAndReset() -> (executed: Bool, list: [ArchiveCommandProtocol]) {
        lock.lock()
        defer { lock.unlock() }
        let wasExecuted = isExecutedState
        let list = executedSubCommands
        isExecutedState = false
        executedSubCommands.removeAll()
        return (wasExecuted, list)
    }
}

