// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Specialized password recovery workflow template (Template Method Pattern).
/// Coordinates password vault prior checks, dictionary/brute-force strategy dispatch, payload decode verification, and history writeback.
public final class PasswordRecoveryEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
    public override init() {
        super.init()
    }

    // MARK: - Step 1: Pre-execution Check Hook
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

    // MARK: - Step 2: Environment Preparation Primitive
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

    // MARK: - Step 3: Core Algorithm Primitive
    public override func executeCoreAlgorithmAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        let archivePath = context.archivePath
        let dictionary = context.dictionary
        let sm = context.stateMachine

        // Phase 1: Password Vault Prior Match
        let vaultEntries = PasswordVaultManager.shared.getEntries()
        for entry in vaultEntries {
            let isCorrect = await Self.testArchivePassword(archivePath: archivePath, password: entry.password)
            if isCorrect {
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

        // Phase 2: Dictionary Search Dispatch
        let startIndex = min(max(0, Int(sm?.checkpointOffset ?? 0)), dictionary.count)
        let totalCount = dictionary.count
        var attempts: Int64 = Int64(startIndex)
        var foundPassword: String? = nil

        for i in startIndex..<totalCount {
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
                throw CommandError.executionFailed(reason: "Password recovery task cancelled")
            }

            let pwd = dictionary[i]
            attempts += 1
            sm?.updateProgress(processedBytes: attempts, totalBytes: Int64(totalCount))
            sm?.setCheckpointOffset(attempts)

            // Phase 3: Payload Decode Verification
            let isCorrect = await Self.testArchivePassword(archivePath: archivePath, password: pwd)
            if isCorrect {
                foundPassword = pwd
                break
            }
        }

        if let pwd = foundPassword {
            // Phase 4: Vault Writeback
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

    // MARK: - Step 4: Output Integrity Hook
    public override func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        guard let pwd = result.unlockedPassword, !pwd.isEmpty else {
            throw ArchiveError.readFailed(code: -404)
        }
        result.setMetadata("PasswordVerifiedValid", forKey: "password_recovery_integrity")
    }

    // MARK: - Helper Methods
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
