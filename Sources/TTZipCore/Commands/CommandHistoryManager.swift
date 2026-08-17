import Foundation

/// 命令历史记录管理器与 Invoker (Command History Manager & Invoker)
/// 提供命令执行、Undo/Redo 历史双栈管理、容量上限 (LRU 丢弃)、并发线程安全及仓储持久化 (Pattern 4.4 Repository Pattern)
public final class CommandHistoryManager: @unchecked Sendable {
    public static let shared = CommandHistoryManager()
    
    /// 历史栈容量上限（默认 50 条）
    public let maxHistoryCapacity: Int
    public var historyRepository: any ArchiveHistoryRepositoryProtocol
    
    private var undoStack: [ArchiveCommandProtocol] = []
    private var redoStack: [ArchiveCommandProtocol] = []
    private let lock = NSLock()
    private var currentOperationTask: Task<Void, Never>? = nil
    
    private convenience init() {
        self.init(maxHistoryCapacity: 50, historyRepository: JSONFileArchiveHistoryRepository())
    }
    
    internal init(
        maxHistoryCapacity: Int = 50,
        historyRepository: any ArchiveHistoryRepositoryProtocol = JSONFileArchiveHistoryRepository()
    ) {
        self.maxHistoryCapacity = maxHistoryCapacity
        self.historyRepository = historyRepository
    }
    
    /// 统一串行化异步操作执行管线（通过同步 helper 函数进行锁隔离与 Task 链接）
    private func chainTask<T: Sendable>(_ block: @escaping @Sendable () async throws -> T) -> Task<T, Error> {
        lock.lock()
        defer { lock.unlock() }
        let previousTask = currentOperationTask
        
        let newTask = Task<T, Error> {
            _ = await previousTask?.result
            return try await block()
        }
        
        currentOperationTask = Task {
            _ = await newTask.result
        }
        
        return newTask
    }
    
    private func runSerialized<T: Sendable>(_ block: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = chainTask(block)
        return try await task.value
    }
    
    /// 当前是否可以进行撤销操作
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !undoStack.isEmpty
    }
    
    /// 当前是否可以进行重做操作
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }
    
    /// 撤销栈中的命令数量
    public var undoStackCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.count
    }
    
    /// 重做栈中的命令数量
    public var redoStackCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.count
    }
    
    /// 获取可撤销历史命令描述列表（最近命令排在最后）
    public var undoHistoryDescriptions: [String] {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.map { $0.description }
    }
    
    /// 获取可重做历史命令描述列表
    public var redoHistoryDescriptions: [String] {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.map { $0.description }
    }
    
    /// 获取仓储持有的持久化归档任务历史记录
    public func getHistoryRecords() throws -> [ArchiveTaskRecord] {
        return try historyRepository.fetchAll()
    }
    
    /// 获取最近的前 N 条持久化归档任务历史记录
    public func getRecentHistoryRecords(limit: Int) throws -> [ArchiveTaskRecord] {
        return try historyRepository.fetchRecent(limit: limit)
    }
    
    /// 统一执行命令，并在成功后自动压入撤销栈（若支持 Undo），同时 100% 清空重做栈分支与写入仓储
    /// - Parameter command: 符合 ArchiveCommandProtocol 的原子/宏命令
    /// - Returns: 执行产物状态
    public func execute(command: ArchiveCommandProtocol) async throws -> CommandResult {
        try await runSerialized {
            let result = try await command.execute()
            
            self.clearRedoStack()
            if command.isUndoable {
                self.pushUndo(command)
            }
            
            // 写入仓储持久化记录
            let record = ArchiveTaskRecord(
                id: UUID(),
                commandName: command.description,
                archivePath: "archive_\(command.commandId.prefix(8)).zip",
                targetPath: "/tmp/TTZip/Output",
                isSuccess: result.success,
                timestamp: Date(),
                fileSizeByte: 1024
            )
            try? self.historyRepository.save(record)
            
            return result
        }
    }
    
    /// 撤销上一次执行的命令 (Undo)
    /// - Returns: 撤销结果描述，若栈空则返回 nil
    @discardableResult
    public func undo() async throws -> CommandResult? {
        try await runSerialized {
            guard let command = self.popUndo() else {
                return nil
            }
            
            do {
                try await command.undo()
                self.pushRedo(command)
                
                return CommandResult(
                    commandId: command.commandId,
                    success: true,
                    message: "成功撤销: [\(command.description)]"
                )
            } catch {
                // 如果 Undo 过程失败，重新压回 undoStack 维持一致性
                self.restoreUndoOnFailure(command)
                throw error
            }
        }
    }
    
    /// 重做上一次撤销的命令 (Redo)
    /// - Returns: 重做执行产物状态，若栈空则返回 nil
    @discardableResult
    public func redo() async throws -> CommandResult? {
        try await runSerialized {
            guard let command = self.popRedo() else {
                return nil
            }
            
            do {
                let result = try await command.execute()
                self.pushUndo(command)
                return result
            } catch {
                // 如果 Redo 失败，重新压回 redoStack
                self.restoreRedoOnFailure(command)
                throw error
            }
        }
    }
    
    /// 清空所有 Undo 与 Redo 历史记录，并自动清理丢弃命令持有的磁盘备份资源
    public func clearHistory() {
        var discarded: [ArchiveCommandProtocol] = []
        lock.lock()
        discarded.append(contentsOf: undoStack)
        discarded.append(contentsOf: redoStack)
        undoStack.removeAll()
        redoStack.removeAll()
        lock.unlock()
        
        for cmd in discarded {
            cmd.purgeBackupResources()
        }
    }
    
    // MARK: - 内部同步锁辅助方法
    
    private func pushUndo(_ command: ArchiveCommandProtocol) {
        var discarded: [ArchiveCommandProtocol] = []
        lock.lock()
        undoStack.append(command)
        discarded.append(contentsOf: redoStack)
        redoStack.removeAll()
        
        while undoStack.count > maxHistoryCapacity {
            discarded.append(undoStack.removeFirst())
        }
        lock.unlock()
        
        for cmd in discarded {
            cmd.purgeBackupResources()
        }
    }
    
    private func clearRedoStack() {
        var discarded: [ArchiveCommandProtocol] = []
        lock.lock()
        discarded.append(contentsOf: redoStack)
        redoStack.removeAll()
        lock.unlock()
        
        for cmd in discarded {
            cmd.purgeBackupResources()
        }
    }
    
    private func popUndo() -> ArchiveCommandProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.popLast()
    }
    
    private func pushRedo(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        redoStack.append(command)
    }
    
    private func popRedo() -> ArchiveCommandProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.popLast()
    }
    
    private func restoreUndoOnFailure(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        undoStack.append(command)
    }
    
    private func restoreRedoOnFailure(_ command: ArchiveCommandProtocol) {
        lock.lock()
        defer { lock.unlock() }
        redoStack.append(command)
    }
}
