import Foundation

/// 任务断点快照备忘录 (Task Checkpoint Memento)
/// 记录长耗时任务（密码爆破/修复）断点快照（任务ID、任务名、状态名、已处理字节、总字节、字典 Offset、TPS 算力、校验和）
public struct TaskCheckpointMemento: ArchiveMementoProtocol, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    
    public let taskID: UUID
    public let taskName: String
    public let stateName: String
    public let processedBytes: Int64
    public let totalBytes: Int64
    public let dictionaryOffset: Int64
    public let throughputTPS: Double
    public let checksum: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskID: UUID,
        taskName: String,
        stateName: String,
        processedBytes: Int64,
        totalBytes: Int64,
        dictionaryOffset: Int64,
        throughputTPS: Double = 0.0,
        checksum: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
        self.taskName = taskName
        self.stateName = stateName
        self.processedBytes = processedBytes
        self.totalBytes = totalBytes
        self.dictionaryOffset = dictionaryOffset
        self.throughputTPS = throughputTPS
        self.checksum = checksum
    }
}

/// 任务断点快照管理者 (Task Checkpoint Caretaker)
/// 支持断点快照到磁盘 JSON 文件 (~/Library/Caches/TTZip/Checkpoints/) 的序列化与反序列化，实现程序退出/崩溃无缝断点续传
public final class TaskCheckpointCaretaker: ArchiveCaretakerProtocol, @unchecked Sendable {
    private var historyStack: [TaskCheckpointMemento] = []
    private var redoStack: [TaskCheckpointMemento] = []
    private let lock = NSRecursiveLock()
    
    public let checkpointsDirectory: URL
    public var maxDepth: Int
    
    public init(customDirectory: URL? = nil, maxDepth: Int = 50) {
        self.maxDepth = maxDepth
        if let customDir = customDirectory {
            self.checkpointsDirectory = customDir
        } else {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.checkpointsDirectory = cachesDir.appendingPathComponent("TTZip/Checkpoints", isDirectory: true)
        }
        ensureDirectoryExists()
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: checkpointsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func saveMemento(_ memento: TaskCheckpointMemento) {
        saveCheckpoint(memento)
    }
    
    /// 保存任务断点快照，同步写入内存历史与磁盘 JSON
    public func saveCheckpoint(_ memento: TaskCheckpointMemento) {
        lock.lock()
        defer { lock.unlock() }
        
        historyStack.append(memento)
        redoStack.removeAll()
        
        if historyStack.count > maxDepth {
            historyStack.removeFirst(historyStack.count - maxDepth)
        }
        
        // 序列化至磁盘 JSON 文件
        persistToDisk(memento)
    }
    
    private func checkpointFileURL(taskID: UUID) -> URL {
        checkpointsDirectory.appendingPathComponent("checkpoint_\(taskID.uuidString).json")
    }
    
    private func persistToDisk(_ memento: TaskCheckpointMemento) {
        ensureDirectoryExists()
        let fileURL = checkpointFileURL(taskID: memento.taskID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(memento)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 写入失败降级防护
        }
    }
    
    /// 从磁盘加载特定 taskID 的断点快照
    public func loadCheckpoint(taskID: UUID) -> TaskCheckpointMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = checkpointFileURL(taskID: taskID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let memento = try decoder.decode(TaskCheckpointMemento.self, from: data)
            return memento
        } catch {
            // JSON 损坏/解析失败容错
            return nil
        }
    }
    
    /// 删除磁盘上的 taskID 断点快照
    public func deleteCheckpoint(taskID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        let fileURL = checkpointFileURL(taskID: taskID)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// 列出磁盘上保存的所有断点快照
    public func listCheckpoints() -> [TaskCheckpointMemento] {
        lock.lock()
        defer { lock.unlock() }
        
        ensureDirectoryExists()
        guard let files = try? FileManager.default.contentsOfDirectory(at: checkpointsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var results: [TaskCheckpointMemento] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for file in files where file.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: file),
               let memento = try? decoder.decode(TaskCheckpointMemento.self, from: data) {
                results.append(memento)
            }
        }
        return results.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func undo() -> TaskCheckpointMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard historyStack.count > 1 else { return nil }
        let current = historyStack.removeLast()
        redoStack.append(current)
        return historyStack.last
    }
    
    public func redo() -> TaskCheckpointMemento? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let next = redoStack.popLast() else { return nil }
        historyStack.append(next)
        return next
    }
    
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return historyStack.count > 1
    }
    
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }
    
    public func clearAllCheckpoints() {
        lock.lock()
        defer { lock.unlock() }
        
        historyStack.removeAll()
        redoStack.removeAll()
        
        if let files = try? FileManager.default.contentsOfDirectory(at: checkpointsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
