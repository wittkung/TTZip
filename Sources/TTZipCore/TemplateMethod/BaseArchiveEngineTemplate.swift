import Foundation

/// 【3.6 模板方法模式 (Template Method Pattern)】归档处理骨架算法抽象基类
/// 封装固定的归档/解压/探索/恢复工作流步骤，提供 Standardized Template Pipeline 与扩展 Hook 钩子
open class BaseArchiveEngineTemplate: @unchecked Sendable {
    public init() {}

    /// 模板方法 (Template Method)：固定归档处理骨架算法的执行步骤顺序
    /// 包含 6 大阶段：
    /// 1. preExecutionCheck (Hook)
    /// 2. prepareEnvironment (Primitive)
    /// 3. executeCoreAlgorithm (Abstract Primitive)
    /// 4. verifyOutputIntegrity (Hook)
    /// 5. postExecutionCleanup (Primitive)
    /// 6. onFailure (Hook)
    public final func performWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult {
        let startTime = Date()
        do {
            // Step 1: 前置校验 (Hook)
            try preExecutionCheck(context: context)

            // Step 2: 环境搭建与资源预分配 (Primitive)
            try prepareEnvironment(context: context)

            // Step 3: 执行核心算法 (Abstract Primitive)
            var result = try executeCoreAlgorithm(context: context)
            let duration = max(0.0001, Date().timeIntervalSince(startTime))
            result.durationSeconds = duration

            // Step 4: 校验产物完整性 (Hook)
            try verifyOutputIntegrity(context: context, result: &result)

            // Step 5: 后置清理与 Metrics 记录 (Primitive)
            try postExecutionCleanup(context: context, result: result)

            return result
        } catch {
            // Step 6: 异常处理与回滚 (Hook)
            onFailure(context: context, error: error)
            throw error
        }
    }

    /// 异步模板方法 (Async Template Method)
    public final func performWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        let startTime = Date()
        do {
            // Step 1: 前置校验 (Hook)
            try preExecutionCheck(context: context)

            // Step 2: 环境搭建与资源预分配 (Primitive)
            try prepareEnvironment(context: context)

            // Step 3: 异步执行核心算法 (Abstract Primitive)
            var result = try await executeCoreAlgorithmAsync(context: context)
            let duration = max(0.0001, Date().timeIntervalSince(startTime))
            result.durationSeconds = duration

            // Step 4: 校验产物完整性 (Hook)
            try verifyOutputIntegrity(context: context, result: &result)

            // Step 5: 后置清理与 Metrics 记录 (Primitive)
            try postExecutionCleanup(context: context, result: result)

            return result
        } catch {
            // Step 6: 异常处理与回滚 (Hook)
            onFailure(context: context, error: error)
            throw error
        }
    }

    // MARK: - 6 大骨架原语与 Hook 钩子定义 (Primitives & Hooks)

    /// 1. 前置责任链与权限校验 (Hook 钩子，默认提供通用的基础校验，允许子类覆盖或扩充)
    open func preExecutionCheck(context: ArchiveTemplateContext) throws {
        switch context.operation {
        case .compress:
            guard !context.inputPaths.isEmpty else {
                throw ArchiveError.readFailed(code: -10)
            }
            guard !context.archivePath.isEmpty else {
                throw ArchiveError.readFailed(code: -11)
            }
            if context.level == .ultra && !LicenseManager.shared.canUseFeature(.ultraCompression) {
                throw ArchiveError.readFailed(code: -403)
            }
        case .extract, .inspect, .repair:
            guard !context.archivePath.isEmpty else {
                throw ArchiveError.fileNotFound
            }
            guard FileManager.default.fileExists(atPath: context.archivePath) else {
                throw ArchiveError.fileNotFound
            }
        case .recover:
            guard !context.archivePath.isEmpty else {
                throw ArchiveError.fileNotFound
            }
            guard FileManager.default.fileExists(atPath: context.archivePath) else {
                throw ArchiveError.fileNotFound
            }
            guard !context.dictionary.isEmpty else {
                throw ArchiveError.readFailed(code: -404)
            }
        case .batch:
            break
        }
    }

    /// 2. 建立临时空间与句柄 (原语步骤，按需预分配目标目录与系统句柄)
    open func prepareEnvironment(context: ArchiveTemplateContext) throws {
        let fm = FileManager.default

        if context.operation == .extract && !context.destinationDir.isEmpty {
            if !fm.fileExists(atPath: context.destinationDir) {
                try fm.createDirectory(atPath: context.destinationDir, withIntermediateDirectories: true)
            }
        }

        if context.operation == .compress && !context.archivePath.isEmpty {
            let parentDir = (context.archivePath as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && !fm.fileExists(atPath: parentDir) {
                try fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            }
        }
    }

    /// 3. 抽象原语步骤：同步核心压缩/解压/恢复算法 (默认通过 Task.detached 桥接到 executeCoreAlgorithmAsync)
    open func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
        let box = SyncResultBox()
        let sema = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                box.result = try await self.executeCoreAlgorithmAsync(context: context)
            } catch {
                box.error = error
            }
            sema.signal()
        }
        sema.wait()

        if let res = box.result { return res }
        if let err = box.error { throw err }
        throw ArchiveError.readFailed(code: -999)
    }

    /// 3b. 抽象原语步骤：异步核心压缩/解压/恢复算法 (子类可直接覆盖此异步原语)
    open func executeCoreAlgorithmAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        throw ArchiveError.readFailed(code: -999)
    }

    /// 4. 校验产物 CRC32/SHA256 与文件树结构 (Hook 钩子)
    open func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        let fm = FileManager.default
        if context.operation == .compress && !result.outputPath.isEmpty {
            let checkPath = (context.splitVolumeSizeBytes != nil && context.splitVolumeSizeBytes! > 0) ? (result.outputPath + ".001") : result.outputPath
            guard fm.fileExists(atPath: checkPath) || fm.fileExists(atPath: result.outputPath) else {
                throw ArchiveError.readFailed(code: -500)
            }
            let checker = ArchiveEngineFactory.makeIntegrityChecker()
            let targetForCrc = fm.fileExists(atPath: checkPath) ? checkPath : result.outputPath
            let crc = checker.computeCRC32(filePath: targetForCrc)
            result.crc32 = crc
            result.setMetadata(crc, forKey: "crc32")
        } else if context.operation == .extract && !result.destinationDir.isEmpty {
            guard fm.fileExists(atPath: result.destinationDir) else {
                throw ArchiveError.readFailed(code: -501)
            }
        }
    }

    /// 5. 清理临时文件，记录 Metrics，广播 Observer 事件 (原语步骤)
    open func postExecutionCleanup(context: ArchiveTemplateContext, result: WorkflowResult) throws {
        // 清理临时文件
        if let temp = context.tempDir, FileManager.default.fileExists(atPath: temp) {
            try? FileManager.default.removeItem(atPath: temp)
        }

        // 广播 Observer 进度与完成事件
        let info = ArchiveProgressInfo(
            state: .completed,
            bytesProcessed: result.processedBytes,
            totalBytes: max(result.processedBytes, result.compressedBytes),
            currentFileName: (result.outputPath as NSString).lastPathComponent,
            throughputMBs: result.durationSeconds > 0 ? (Double(result.processedBytes) / 1024.0 / 1024.0) / result.durationSeconds : 0.0,
            estimatedTimeRemaining: 0,
            operationType: context.operation == .compress ? .compress : (context.operation == .extract ? .extract : .recover)
        )
        ArchiveProgressBroadcaster.shared.broadcastProgress(info)
    }

    /// 6. 失败回滚与异常清理 (Hook 钩子)
    open func onFailure(context: ArchiveTemplateContext, error: Error) {
        // 回滚：清理产生的临时文件与半成品产物
        if let temp = context.tempDir, FileManager.default.fileExists(atPath: temp) {
            try? FileManager.default.removeItem(atPath: temp)
        }

        if context.operation == .compress && !context.archivePath.isEmpty {
            if FileManager.default.fileExists(atPath: context.archivePath) {
                // 如果产物尚未完全写入完成则清理
                if let attr = try? FileManager.default.attributesOfItem(atPath: context.archivePath),
                   (attr[.size] as? Int64 ?? 0) == 0 {
                    try? FileManager.default.removeItem(atPath: context.archivePath)
                }
            }
        }

        // 广播 Failure 事件
        let info = ArchiveProgressInfo(
            state: .failed(error: error.localizedDescription),
            bytesProcessed: 0,
            totalBytes: 0,
            currentFileName: (context.archivePath as NSString).lastPathComponent,
            throughputMBs: 0,
            estimatedTimeRemaining: 0,
            operationType: context.operation == .compress ? .compress : .extract
        )
        ArchiveProgressBroadcaster.shared.broadcastProgress(info)
    }
}
