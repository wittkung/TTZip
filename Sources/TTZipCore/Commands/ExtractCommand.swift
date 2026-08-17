import Foundation

/// 归档解压具体命令 (Concrete Command for Extraction)
/// 封装解压逻辑；在撤销 (Undo) 时精准清理解压衍生出来的文件树，绝不误删目标目录中已存在的用户原有文件
public final class ExtractCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool { true }
    
    public let archivePath: String
    public let destinationDir: String
    public let password: String?
    public let autoVaultUnlock: Bool
    public let progress: (@Sendable (ArchiveProgress) -> Void)?
    
    private let engineFacade: TTZipEngineFacading
    private let lock = NSLock()
    
    private var newlyCreatedFileTree: [String] = []
    private var preExistingDirExisted: Bool = false
    private var backupDirPath: String? = nil
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.commandId = commandId
        self.archivePath = archivePath
        self.destinationDir = destinationDir
        self.password = password
        self.autoVaultUnlock = autoVaultUnlock
        self.progress = progress
        self.engineFacade = engineFacade
        
        let archiveName = (archivePath as NSString).lastPathComponent
        let destName = (destinationDir as NSString).lastPathComponent
        self.description = description ?? "解压 [\(archiveName)] 至 [\(destName)]"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        // 1. 解压前快照：检查目标目录是否存在，并递归收集原有全部文件与目录集合
        let dirExistedBefore = fm.fileExists(atPath: destinationDir)
        let preExistingPaths = scanDirectorySet(dirPath: destinationDir)
        
        // 备份目标目录已存在的内容（若有），防范解压过程中覆盖原有同名文件
        var backupMade: String? = nil
        if dirExistedBefore && !preExistingPaths.isEmpty {
            let tempBackup = "\(destinationDir).bak_\(UUID().uuidString)"
            try? fm.copyItem(atPath: destinationDir, toPath: tempBackup)
            backupMade = tempBackup
        }
        
        // 2. 执行解压操作（若引擎抛错，立刻清理刚才创建的备份目录，防止磁盘残留！）
        let extractResult = try await {
            do {
                return try await engineFacade.quickExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: password,
                    autoVaultUnlock: autoVaultUnlock,
                    progress: progress
                )
            } catch {
                if let bDir = backupMade, fm.fileExists(atPath: bDir) {
                    try? fm.removeItem(atPath: bDir)
                }
                throw error
            }
        }()
        
        // 3. 解压后快照：计算差集得出本次解压新增的文件/目录
        let postExistingPaths = scanDirectorySet(dirPath: destinationDir)
        let newlyCreated = postExistingPaths.subtracting(preExistingPaths)
        
        // 按路径深度降序排列，保证先删除最内层子文件/子目录，最后删除空文件夹
        let sortedCreated = newlyCreated.sorted {
            $0.components(separatedBy: "/").count > $1.components(separatedBy: "/").count
        }
        
        saveExecutionState(created: sortedCreated, preExisted: dirExistedBefore, backupDir: backupMade)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        var backupDict: [String: String] = [:]
        if let b = backupMade {
            backupDict[destinationDir] = b
        }
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "解压完成，释放文件至 \(destinationDir)",
            artifactsCreated: sortedCreated,
            backupPaths: backupDict,
            executionDuration: duration,
            metadata: ["unlockedPassword": extractResult.unlockedPassword ?? ""]
        )
    }
    
    public func undo() async throws {
        let (executed, createdTree, preExisted, backupDir) = getUndoStateSnapshot()
        guard executed else {
            throw CommandError.invalidState(reason: "解压命令尚未执行，无法撤销")
        }
        
        let fm = FileManager.default
        
        // 1. 精准清理解压产生的衍生文件/目录
        for path in createdTree {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
        
        // 2. 如果之前存在覆盖备份，还原目标目录原有文件
        var backupRestoreFailed = false
        if let backupDir = backupDir, fm.fileExists(atPath: backupDir) {
            let backupPaths = scanDirectorySet(dirPath: backupDir)
            for bPath in backupPaths {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: bPath, isDirectory: &isDir), !isDir.boolValue {
                    let relPath = String(bPath.dropFirst(backupDir.count + 1))
                    let origPath = (destinationDir as NSString).appendingPathComponent(relPath)
                    if fm.fileExists(atPath: origPath) {
                        try? fm.removeItem(atPath: origPath)
                    }
                    let parentDir = (origPath as NSString).deletingLastPathComponent
                    try? fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                    if (try? fm.copyItem(atPath: bPath, toPath: origPath)) == nil {
                        backupRestoreFailed = true
                    }
                }
            }
            if !backupRestoreFailed {
                try? fm.removeItem(atPath: backupDir)
            }
        }
        
        // 3. 若解压前目标目录本不存在且当前已被清空，则清理空的目标根目录
        if !preExisted && fm.fileExists(atPath: destinationDir) {
            if let contents = try? fm.contentsOfDirectory(atPath: destinationDir), contents.isEmpty {
                try? fm.removeItem(atPath: destinationDir)
            }
        }
        
        if backupRestoreFailed {
            throw CommandError.undoFailed(reason: "解压还原备份出现异常")
        } else {
            resetExecutionStateOnUndoSuccess()
        }
    }
    
    public func purgeBackupResources() {
        lock.lock()
        let bDir = self.backupDirPath
        self.backupDirPath = nil
        lock.unlock()
        
        if let bDir = bDir, FileManager.default.fileExists(atPath: bDir) {
            try? FileManager.default.removeItem(atPath: bDir)
        }
    }
    
    // MARK: - 内部锁辅助方法
    
    private func saveExecutionState(created: [String], preExisted: Bool, backupDir: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.newlyCreatedFileTree = created
        self.preExistingDirExisted = preExisted
        self.backupDirPath = backupDir
        self.isExecutedState = true
    }
    
    private func getUndoStateSnapshot() -> (executed: Bool, createdTree: [String], preExisted: Bool, backupDir: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (self.isExecutedState, self.newlyCreatedFileTree, self.preExistingDirExisted, self.backupDirPath)
    }
    
    private func resetExecutionStateOnUndoSuccess() {
        lock.lock()
        defer { lock.unlock() }
        self.isExecutedState = false
        self.newlyCreatedFileTree.removeAll()
        self.backupDirPath = nil
    }

    
    // MARK: - 私有辅助扫描函数
    
    private func scanDirectorySet(dirPath: String) -> Set<String> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dirPath) else { return [] }
        
        var result = Set<String>()
        if let enumerator = fm.enumerator(atPath: dirPath) {
            while let relativePath = enumerator.nextObject() as? String {
                let fullPath = (dirPath as NSString).appendingPathComponent(relativePath)
                result.insert(fullPath)
            }
        }
        return result
    }
}
