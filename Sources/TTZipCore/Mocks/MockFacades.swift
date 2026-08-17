import Foundation

/// 自动化测试与外部模块依赖解耦的 Mock 安全门面
public final class MockArchiveSecurityFacade: ArchiveSecurityFacading, @unchecked Sendable {
    public var auditResult: SecurityReport?
    public var validatePathResult: Bool = true
    public var scanEntriesResult: SecurityReport?
    
    public init(
        auditResult: SecurityReport? = nil,
        validatePathResult: Bool = true,
        scanEntriesResult: SecurityReport? = nil
    ) {
        self.auditResult = auditResult
        self.validatePathResult = validatePathResult
        self.scanEntriesResult = scanEntriesResult
    }
    
    public func auditArchive(archivePath: String, password: String?, autoVaultUnlock: Bool) async throws -> SecurityReport {
        if let result = auditResult {
            return result
        }
        return SecurityReport(isSafe: true, suspiciousFileNames: [], hasZipSlipRisk: false, detailMessage: "Mock Audit Passed", riskLevel: .safe)
    }
    
    public func validateExtractPath(entryPath: String, destinationDir: String) -> Bool {
        return validatePathResult
    }
    
    public func scanEntries(_ entries: [ArchiveEntry]) -> SecurityReport {
        if let result = scanEntriesResult {
            return result
        }
        return SecurityReport(isSafe: true, suspiciousFileNames: [], hasZipSlipRisk: false, detailMessage: "Mock Scan Passed", riskLevel: .safe)
    }
}

/// 自动化测试与外部模块依赖解耦的 Mock 批处理门面
public final class MockArchiveBatchFacade: ArchiveBatchFacading, @unchecked Sendable {
    public var batchCompressResults: [BatchTaskResult] = []
    public var batchExtractResults: [BatchTaskResult] = []
    
    public init(
        batchCompressResults: [BatchTaskResult] = [],
        batchExtractResults: [BatchTaskResult] = []
    ) {
        self.batchCompressResults = batchCompressResults
        self.batchExtractResults = batchExtractResults
    }
    
    public func batchCompress(
        tasks: [BatchCompressTask],
        maxConcurrent: Int,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async -> [BatchTaskResult] {
        if !batchCompressResults.isEmpty {
            return batchCompressResults
        }
        return tasks.enumerated().map { (idx, task) in
            progress?(idx + 1, tasks.count)
            return BatchTaskResult(id: task.id, success: true, targetPath: task.outputPath, durationSeconds: 0.01)
        }
    }
    
    public func batchExtract(
        tasks: [BatchExtractTask],
        maxConcurrent: Int,
        autoVaultUnlock: Bool,
        progress: (@Sendable (Int, Int) -> Void)?
    ) async -> [BatchTaskResult] {
        if !batchExtractResults.isEmpty {
            return batchExtractResults
        }
        return tasks.enumerated().map { (idx, task) in
            progress?(idx + 1, tasks.count)
            return BatchTaskResult(id: task.id, success: true, targetPath: task.destinationDir, durationSeconds: 0.01)
        }
    }
    
    public func batchExecuteMacro(
        commands: [ArchiveCommandProtocol],
        description: String? = nil
    ) async throws -> CommandResult {
        let macro = MacroArchiveCommand(description: description, commands: commands)
        return try await macro.execute()
    }
    
    public func batchCompressTransactional(tasks: [BatchCompressTask]) async throws -> CommandResult {
        let commands = tasks.map { CompressCommand(inputs: $0.inputs, outputPath: $0.outputPath, format: $0.format, level: $0.level, password: $0.password, splitSize: $0.splitSize) }
        return try await batchExecuteMacro(commands: commands)
    }
    
    public func batchExtractTransactional(tasks: [BatchExtractTask], autoVaultUnlock: Bool = true) async throws -> CommandResult {
        let commands = tasks.map { ExtractCommand(archivePath: $0.archivePath, destinationDir: $0.destinationDir, password: $0.password, autoVaultUnlock: autoVaultUnlock) }
        return try await batchExecuteMacro(commands: commands)
    }
}

/// 自动化测试与外部模块依赖解耦的 Mock 性能基准门面
public final class MockArchiveBenchmarkFacade: ArchiveBenchmarkFacading, @unchecked Sendable {
    public var quickBenchmarkResult: BenchmarkResult?
    public var suiteResults: [BenchmarkResult] = []
    public var cleanCacheCalled: Bool = false
    
    public init(
        quickBenchmarkResult: BenchmarkResult? = nil,
        suiteResults: [BenchmarkResult] = []
    ) {
        self.quickBenchmarkResult = quickBenchmarkResult
        self.suiteResults = suiteResults
    }
    
    public func runQuickBenchmark(size: BenchmarkDataSize, profile: BenchmarkDatasetProfile) async throws -> BenchmarkResult {
        if let res = quickBenchmarkResult {
            return res
        }
        return BenchmarkResult(
            dataSizeMB: size.sizeMB,
            elapsedSeconds: 0.05,
            throughputMBs: 100.0,
            decompressionThroughputMBs: 150.0,
            originalSizeBytes: size.bytes,
            compressedSizeBytes: size.bytes / 2,
            compressionRatioPercent: 50.0,
            nativeMacOsSeconds: 0.10,
            speedupMultiplier: 2.0,
            installedCompetitorScores: [],
            chipName: "Apple M1",
            usedCores: 8,
            formatName: "ZIP",
            datasetProfileName: profile.rawValue,
            efficiencyScore: 95,
            recommendationBadge: "RECOMMENDED"
        )

    }
    
    public func runAllPresetsSuite(size: BenchmarkDataSize) async throws -> [BenchmarkResult] {
        return suiteResults
    }
    
    public func cleanCache() {
        cleanCacheCalled = true
    }
}

/// 自动化测试与外部模块依赖解耦的 Mock 主引擎门面
public final class MockTTZipEngineFacade: TTZipEngineFacading, @unchecked Sendable {
    public var historyManager: CommandHistoryManager = CommandHistoryManager()
    public var quickCompressResult: ArchiveOperationResult?
    public var quickExtractResult: ExtractResult?
    public var inspectionResult: ArchiveInspectionResult?
    public var hashResult: HashVerificationResult?
    public var repairCount: Int = 1
    public var recoveryResult: PasswordRecoveryResult?
    public var shouldThrowError: Error?
    
    public init() {}
    
    public func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult {
        if let err = shouldThrowError { throw err }
        return try await historyManager.execute(command: command)
    }
    
    public func undoCommand() async throws -> CommandResult? {
        if let err = shouldThrowError { throw err }
        return try await historyManager.undo()
    }
    
    public func redoCommand() async throws -> CommandResult? {
        if let err = shouldThrowError { throw err }
        return try await historyManager.redo()
    }
    
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String?,
        splitSize: Int64?,
        filterOptions: ArchiveFilterOptions,
        advancedOptions: ArchiveAdvancedOptions?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ArchiveOperationResult {
        if let err = shouldThrowError { throw err }
        if let res = quickCompressResult { return res }
        return ArchiveOperationResult(outputPath: outputPath, originalBytes: 1024, compressedBytes: 512, durationSeconds: 0.01, throughputMBs: 100.0)
    }
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String?,
        autoVaultUnlock: Bool,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ExtractResult {
        if let err = shouldThrowError { throw err }
        if let res = quickExtractResult { return res }
        return ExtractResult(archivePath: archivePath, destinationDir: destinationDir, durationSeconds: 0.01, unlockedPassword: password, isVaultUnlocked: false)
    }
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String?
    ) async throws {
        if let err = shouldThrowError { throw err }
    }
    
    public func inspectArchive(
        archivePath: String,
        password: String?,
        autoVaultUnlock: Bool
    ) async throws -> ArchiveInspectionResult {
        if let err = shouldThrowError { throw err }
        if let res = inspectionResult { return res }
        let secReport = SecurityReport(isSafe: true, suspiciousFileNames: [], hasZipSlipRisk: false, detailMessage: "Safe", riskLevel: .safe)
        let root = ArchiveComponentTreeBuilder.buildTree(from: [])
        return ArchiveInspectionResult(archivePath: archivePath, entries: [], treeNode: root, securityReport: secReport, unlockedPassword: password)
    }

    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        if let err = shouldThrowError { throw err }
        if let res = hashResult { return res }
        return HashVerificationResult(filePath: archivePath, crc32: "12345678", sha256: "abcdef1234567890")
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        if let err = shouldThrowError { throw err }
        return repairCount
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        if let err = shouldThrowError { throw err }
        if let res = recoveryResult { return res }
        return PasswordRecoveryResult(foundPassword: nil, totalAttempts: Int64(dictionary.count), durationSeconds: 0.01)
    }
}

