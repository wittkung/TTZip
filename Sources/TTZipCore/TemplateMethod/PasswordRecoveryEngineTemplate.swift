import Foundation

/// 【3.6 模板方法模式 (Template Method Pattern)】密码恢复流程骨架模板
/// 封装完整的密码解开与恢复流程骨架：密码库先验 ➔ 策略分发 ➔ 载荷解码验证 ➔ 历史库回写
public final class PasswordRecoveryEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
    public override init() {
        super.init()
    }

    // MARK: - Step 1: Hook 钩子 (前置责任链与密码破解权限校验)
    public override func preExecutionCheck(context: ArchiveTemplateContext) throws {
        try super.preExecutionCheck(context: context)
        guard FileManager.default.fileExists(atPath: context.archivePath) else {
            throw ArchiveError.fileNotFound
        }

        if let sm = context.stateMachine {
            if sm.currentState is CompletedState {
                throw ArchiveStateError.taskAlreadyCompleted
            } else if sm.currentState is FailedState {
                throw ArchiveStateError.taskAlreadyFailed(reason: sm.lastError?.localizedDescription ?? "Task already failed")
            }
        }
    }

    // MARK: - Step 2: 原语步骤 (建立 Task State Machine)
    public override func prepareEnvironment(context: ArchiveTemplateContext) throws {
        try super.prepareEnvironment(context: context)
        let sm = context.stateMachine ?? ArchiveTaskStateMachine(
            taskName: "PasswordRecovery:\((context.archivePath as NSString).lastPathComponent)",
            totalBytes: Int64(context.dictionary.count)
        )
        if sm.currentState is IdleState {
            try? sm.start()
        }
    }

    // MARK: - Step 3: 原语步骤 (执行核心 4 阶密码解开算法)
    public override func executeCoreAlgorithmAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        let archivePath = context.archivePath
        let dictionary = context.dictionary
        let sm = context.stateMachine

        // 阶段 1：密码库先验 (Password Vault Prior)
        let vaultEntries = PasswordVaultManager.shared.getEntries()
        for entry in vaultEntries {
            let isCorrect = await Self.testArchivePassword(archivePath: archivePath, password: entry.password)
            if isCorrect {
                // 阶段 4：历史库回写 (Vault Writeback)
                PasswordVaultManager.shared.recordUsage(id: entry.id)
                ArchivePasswordStore.shared.setPassword(entry.password, for: archivePath)
                ArchiveEventCenter.shared.postPasswordVaultUnlocked(archivePath: archivePath, password: entry.password, isVaultUnlocked: true)
                try? sm?.complete()
                return WorkflowResult(
                    isSuccess: true,
                    outputPath: archivePath,
                    unlockedPassword: entry.password,
                    metrics: ["recoveryPhase": "VaultPriorHit", "passwordSource": "PasswordVault"]
                )
            }
        }

        // 阶段 2：策略分发 (Strategy Dispatch)
        let startIndex = min(max(0, Int(sm?.checkpointOffset ?? 0)), dictionary.count)
        let totalCount = dictionary.count
        var attempts: Int64 = Int64(startIndex)
        var foundPassword: String? = nil

        for i in startIndex..<totalCount {
            // 响应 PausedState
            while sm?.currentState is PausedState {
                try await Task.sleep(nanoseconds: 50_000_000)
                if Task.isCancelled || sm?.currentState is CancellingState || sm?.currentState is FailedState {
                    break
                }
            }

            if Task.isCancelled || sm?.currentState is CancellingState {
                if !(sm?.currentState is FailedState) {
                    try? sm?.cancel()
                }
                throw CommandError.executionFailed(reason: "密码破解任务已被中断取消")
            }

            let pwd = dictionary[i]
            attempts += 1
            sm?.updateProgress(processedBytes: attempts, totalBytes: Int64(totalCount))
            sm?.setCheckpointOffset(attempts)

            // 阶段 3：载荷解码验证 (Payload Decode Verification)
            let isCorrect = await Self.testArchivePassword(archivePath: archivePath, password: pwd)
            if isCorrect {
                foundPassword = pwd
                break
            }
        }

        if let pwd = foundPassword {
            // 阶段 4：历史库回写 (History Vault Writeback)
            ArchivePasswordStore.shared.setPassword(pwd, for: archivePath)
            ArchiveEventCenter.shared.postPasswordVaultUnlocked(archivePath: archivePath, password: pwd, isVaultUnlocked: false)
            try? sm?.complete()
            return WorkflowResult(
                isSuccess: true,
                outputPath: archivePath,
                processedBytes: attempts,
                unlockedPassword: pwd,
                metrics: ["recoveryPhase": "DictionaryStrategySuccess", "totalAttempts": "\(attempts)"]
            )
        } else {
            let failErr = ArchiveError.readFailed(code: -404)
            try? sm?.fail(error: failErr)
            throw failErr
        }
    }

    // MARK: - Step 4: Hook 钩子 (验证产物与密码有效性)
    public override func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        guard let pwd = result.unlockedPassword, !pwd.isEmpty else {
            throw ArchiveError.readFailed(code: -404)
        }
        result.setMetadata("PasswordVerifiedValid", forKey: "password_recovery_integrity")
    }

    // MARK: - 辅助方法：载荷解码验证 (100% 进程内纯原生 C 驱动)
    private static func testArchivePassword(archivePath: String, password: String) async -> Bool {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZip_PwdTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        let ext = (archivePath as NSString).pathExtension.lowercased()
        if ext == "zip" {
            let ok = ttzip_extract_zip_c_parallel(archivePath, tempDir, false, password) == 0
            if ok {
                let items = (try? FileManager.default.contentsOfDirectory(atPath: tempDir)) ?? []
                return !items.isEmpty
            }
            return false
        } else if ext == "7z" {
            let ok = (try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: tempDir, password: password)) ?? false
            if ok {
                let items = (try? FileManager.default.contentsOfDirectory(atPath: tempDir)) ?? []
                return !items.isEmpty
            }
            return false
        } else {
            let ok = ttzip_extract_archive_advanced(archivePath, tempDir, false, password) == 0
            if ok {
                let items = (try? FileManager.default.contentsOfDirectory(atPath: tempDir)) ?? []
                return !items.isEmpty
            }
            return false
        }
    }
}
