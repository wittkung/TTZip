import Foundation

/// 归档压缩具体命令 (Concrete Command for Compression)
/// 封装归档压缩逻辑；在撤销 (Undo) 时能够精准清理创建的压缩包（含分卷），并还原原先可能被覆盖的文件备份
public final class CompressCommand: ArchiveCommandProtocol, @unchecked Sendable {
    public let commandId: String
    public let description: String
    public var isUndoable: Bool { true }
    
    public let inputs: [String]
    public let outputPath: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let password: String?
    public let splitSize: Int64?
    public let filterOptions: ArchiveFilterOptions
    public let advancedOptions: ArchiveAdvancedOptions?
    public let progress: (@Sendable (ArchiveProgress) -> Void)?
    
    private let engineFacade: TTZipEngineFacading
    private let lock = NSLock()
    
    private var createdArtifacts: [String] = []
    private var backupFileMap: [String: String] = [:]
    private var isExecutedState: Bool = false
    
    public init(
        commandId: String = UUID().uuidString,
        description: String? = nil,
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = ArchiveFilterOptions(),
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil,
        engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared
    ) {
        self.commandId = commandId
        self.inputs = inputs
        self.outputPath = outputPath
        self.format = format
        self.level = level
        self.password = password
        self.splitSize = splitSize
        self.filterOptions = filterOptions
        self.advancedOptions = advancedOptions
        self.progress = progress
        self.engineFacade = engineFacade
        
        let targetName = (outputPath as NSString).lastPathComponent
        self.description = description ?? "压缩文件至 [\(targetName)] (\(format.rawValue.uppercased()))"
    }
    
    deinit {
        purgeBackupResources()
    }
    
    public func execute() async throws -> CommandResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fm = FileManager.default
        
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        let baseName = (outputPath as NSString).lastPathComponent
        let baseStem = (baseName as NSString).deletingPathExtension
        
        // 1. 压缩前快照：收集输出目录已有文件集合
        let preExistingInOutputDir = scanDirectorySet(dirPath: outputDir)
        
        // 如果目标路径或相关分卷包已存在，先行制作临时备份，防止覆盖不可逆
        var backupDict: [String: String] = [:]
        if fm.fileExists(atPath: outputDir) {
            if let dirContents = try? fm.contentsOfDirectory(atPath: outputDir) {
                for item in dirContents {
                    let fullPath = (outputDir as NSString).appendingPathComponent(item)
                    if item == baseName || isSplitVolumeMatch(fileName: item, baseName: baseName, baseStem: baseStem) {
                        let backupPathCandidate = "\(fullPath).bak_\(UUID().uuidString)"
                        try? fm.copyItem(atPath: fullPath, toPath: backupPathCandidate)
                        backupDict[fullPath] = backupPathCandidate
                    }
                }
            }
        }
        
        // 2. 执行引擎层压缩（若引擎抛错，立刻清理刚才创建的备份文件，防止磁盘残留！）
        let result = try await {
            do {
                return try await engineFacade.quickCompress(
                    inputs: inputs,
                    outputPath: outputPath,
                    format: format,
                    level: level,
                    password: password,
                    splitSize: splitSize,
                    filterOptions: filterOptions,
                    advancedOptions: advancedOptions,
                    progress: progress
                )
            } catch {
                for (_, backupPath) in backupDict {
                    if fm.fileExists(atPath: backupPath) {
                        try? fm.removeItem(atPath: backupPath)
                    }
                }
                throw error
            }
        }()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // 3. 收集生成的产物文件（主压缩包及所有分卷包 .z01, .z02, .zip.001, .001 等）
        let postExistingInOutputDir = scanDirectorySet(dirPath: outputDir)
        let newlyCreated = postExistingInOutputDir.subtracting(preExistingInOutputDir)
        
        var artifactsSet = Set<String>()
        if fm.fileExists(atPath: outputPath) {
            artifactsSet.insert(outputPath)
        }
        for path in newlyCreated {
            if !path.contains(".bak_") {
                artifactsSet.insert(path)
            }
        }
        if let dirContents = try? fm.contentsOfDirectory(atPath: outputDir) {
            for item in dirContents {
                if !item.contains(".bak_") && isSplitVolumeMatch(fileName: item, baseName: baseName, baseStem: baseStem) {
                    let fullPath = (outputDir as NSString).appendingPathComponent(item)
                    artifactsSet.insert(fullPath)
                }
            }
        }
        
        let sortedArtifacts = Array(artifactsSet)
        saveExecutionState(artifacts: sortedArtifacts, backupMap: backupDict)
        
        return CommandResult(
            commandId: commandId,
            success: true,
            message: "归档压缩完成: 耗时 \(String(format: "%.2f", duration))s",
            artifactsCreated: sortedArtifacts,
            backupPaths: backupDict,
            executionDuration: duration,
            metadata: ["compressedSize": "\(result.compressedBytes)", "originalSize": "\(result.originalBytes)"]
        )
    }
    
    public func undo() async throws {
        let (executed, artifacts, backups) = getUndoStateSnapshot()
        guard executed else {
            throw CommandError.invalidState(reason: "命令尚未执行，无法撤销")
        }
        
        let fm = FileManager.default
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        let baseName = (outputPath as NSString).lastPathComponent
        let baseStem = (baseName as NSString).deletingPathExtension
        
        // 1. 清理压缩生成的产物（主文件与已记录的切片包）
        for path in artifacts {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
        
        // 2. 扫荡输出目录中生成的任意分卷切片（非备份且非原本存在的衍生分卷）
        if fm.fileExists(atPath: outputDir), let dirContents = try? fm.contentsOfDirectory(atPath: outputDir) {
            for item in dirContents {
                if !item.contains(".bak_") {
                    let fullPath = (outputDir as NSString).appendingPathComponent(item)
                    if backups[fullPath] == nil && isSplitVolumeMatch(fileName: item, baseName: baseName, baseStem: baseStem) {
                        try? fm.removeItem(atPath: fullPath)
                    }
                }
            }
        }
        
        // 3. 还原原有文件覆盖备份
        var unRestoredBackups: [String: String] = [:]
        for (origPath, backupPath) in backups {
            if fm.fileExists(atPath: backupPath) {
                if fm.fileExists(atPath: origPath) {
                    try? fm.removeItem(atPath: origPath)
                }
                do {
                    try fm.moveItem(atPath: backupPath, toPath: origPath)
                } catch {
                    unRestoredBackups[origPath] = backupPath
                }
            }
        }
        
        if !unRestoredBackups.isEmpty {
            saveExecutionState(artifacts: [], backupMap: unRestoredBackups)
            throw CommandError.undoFailed(reason: "撤销部分备份还原失败，已保留剩余备份映射")
        } else {
            resetExecutionStateOnUndoSuccess()
        }
    }
    
    public func purgeBackupResources() {
        lock.lock()
        defer { lock.unlock() }
        let fm = FileManager.default
        for (_, backupPath) in backupFileMap {
            try? fm.removeItem(atPath: backupPath)
        }
        backupFileMap.removeAll()
    }
    
    // MARK: - 内部同步锁辅助方法
    
    private func saveExecutionState(artifacts: [String], backupMap: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        self.createdArtifacts = artifacts
        self.backupFileMap = backupMap
        self.isExecutedState = true
    }
    
    private func getUndoStateSnapshot() -> (executed: Bool, artifacts: [String], backups: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        return (self.isExecutedState, self.createdArtifacts, self.backupFileMap)
    }
    
    private func resetExecutionStateOnUndoSuccess() {
        lock.lock()
        defer { lock.unlock() }
        self.isExecutedState = false
        self.createdArtifacts.removeAll()
        self.backupFileMap.removeAll()
    }
    
    // MARK: - 私有辅助匹配函数
    
    private func isSplitVolumeMatch(fileName: String, baseName: String, baseStem: String) -> Bool {
        if fileName.hasPrefix(baseName + ".") { return true }
        if fileName.hasPrefix(baseStem + ".") {
            let ext = (fileName as NSString).pathExtension.lowercased()
            // 匹配 .z01, .z02 ... 或数字分卷 .001, .002 或 .part1 ...
            if ext.hasPrefix("z") && ext.dropFirst().allSatisfy({ $0.isNumber }) { return true }
            if ext.allSatisfy({ $0.isNumber }) && !ext.isEmpty { return true }
            if ext.hasPrefix("part") { return true }
        }
        return false
    }
    
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

// MARK: - Fluent Builder Extension for CompressCommand

/// CompressCommand 链式建造者 (Fluent Builder Pattern)
public struct CompressCommandBuilder: Sendable {
    public var commandId: String = UUID().uuidString
    public var description: String? = nil
    public var inputs: [String] = []
    public var outputPath: String = ""
    public var format: ArchiveCompressionFormat = .zip
    public var level: ArchiveCompressionLevel = .normal
    public var password: String? = nil
    public var splitSize: Int64? = nil
    public var filterOptions: ArchiveFilterOptions = ArchiveFilterOptions()
    public var advancedOptions: ArchiveAdvancedOptions? = nil
    public var progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    public var engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared

    public init() {}

    public func withInputs(_ inputs: [String]) -> CompressCommandBuilder {
        var copy = self
        copy.inputs = inputs
        return copy
    }

    public func withOutputPath(_ path: String) -> CompressCommandBuilder {
        var copy = self
        copy.outputPath = path
        return copy
    }

    public func withFormat(_ format: ArchiveCompressionFormat) -> CompressCommandBuilder {
        var copy = self
        copy.format = format
        return copy
    }

    public func withLevel(_ level: ArchiveCompressionLevel) -> CompressCommandBuilder {
        var copy = self
        copy.level = level
        return copy
    }

    public func withPassword(_ pwd: String?) -> CompressCommandBuilder {
        var copy = self
        copy.password = pwd
        return copy
    }

    public func withSplitSize(_ size: Int64?) -> CompressCommandBuilder {
        var copy = self
        copy.splitSize = size
        return copy
    }

    public func withFilterOptions(_ options: ArchiveFilterOptions) -> CompressCommandBuilder {
        var copy = self
        copy.filterOptions = options
        return copy
    }

    public func withAdvancedOptions(_ options: ArchiveAdvancedOptions?) -> CompressCommandBuilder {
        var copy = self
        copy.advancedOptions = options
        return copy
    }

    public func withProgress(_ progress: (@Sendable (ArchiveProgress) -> Void)?) -> CompressCommandBuilder {
        var copy = self
        copy.progress = progress
        return copy
    }

    public func build() -> CompressCommand {
        return CompressCommand(
            commandId: commandId,
            description: description,
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: filterOptions,
            advancedOptions: advancedOptions,
            progress: progress,
            engineFacade: engineFacade
        )
    }
}

public extension CompressCommand {
    static func builder() -> CompressCommandBuilder {
        return CompressCommandBuilder()
    }
}
