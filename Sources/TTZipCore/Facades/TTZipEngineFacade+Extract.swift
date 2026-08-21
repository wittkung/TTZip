// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - 2. 快捷统一解压门面 (Extract Facade)

extension TTZipEngineFacade {
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        guard !archivePath.isEmpty, !destinationDir.isEmpty else {
            ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: "File not found")
            throw ArchiveError.fileNotFound
        }
        
        let valCtx = ArchiveValidationContext.forExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password
        )
        do {
            try ArchiveValidationPipeline.buildDefaultExtractPipeline().validateOrThrow(context: valCtx)
        } catch let valErr as ArchiveValidationError {
            ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: valErr.localizedDescription)
            throw valErr.asArchiveError
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
            let info = ArchiveProgressInfo(
                state: p.state,
                bytesProcessed: p.bytesProcessed,
                totalBytes: p.totalBytes,
                currentFileName: p.currentFileName,
                throughputMBs: p.throughputMBs,
                estimatedTimeRemaining: ArchiveProgressInfo.calculateETA(bytesProcessed: p.bytesProcessed, totalBytes: p.totalBytes, throughputMBs: p.throughputMBs),
                operationType: .extract
            )
            ArchiveProgressBroadcaster.shared.broadcastProgress(info)
        }
        
        if let explicitPwd = password, !explicitPwd.isEmpty {
            do {
                let elapsed = try await executePipelineExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: explicitPwd,
                    progress: combinedProgress
                )
                ArchivePasswordStore.shared.setPassword(explicitPwd, for: archivePath)
                let res = ExtractResult(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    durationSeconds: elapsed,
                    unlockedPassword: explicitPwd,
                    isVaultUnlocked: false
                )
                ArchiveEventCenter.shared.postArchiveCompleted(
                    archivePath: archivePath,
                    operationType: .extract,
                    duration: elapsed,
                    totalBytes: 0
                )
                return res
            } catch {
                ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: error.localizedDescription)
                throw error
            }
        } else {
            do {
                let elapsed = try await executePipelineExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: nil,
                    progress: combinedProgress
                )
                let res = ExtractResult(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    durationSeconds: elapsed,
                    unlockedPassword: nil,
                    isVaultUnlocked: false
                )
                ArchiveEventCenter.shared.postArchiveCompleted(
                    archivePath: archivePath,
                    operationType: .extract,
                    duration: elapsed,
                    totalBytes: 0
                )
                return res
            } catch {
                // 无密码解压失败，进入密码库自动解锁
            }
        }
        
        if autoVaultUnlock {
            let vaultEntries = passwordVault.getEntries()
            for entry in vaultEntries {
                do {
                    let elapsed = try await executePipelineExtract(
                        archivePath: archivePath,
                        destinationDir: destinationDir,
                        password: entry.password,
                        progress: combinedProgress
                    )
                    passwordVault.recordUsage(id: entry.id)
                    ArchivePasswordStore.shared.setPassword(entry.password, for: archivePath)
                    ArchiveEventCenter.shared.postPasswordVaultUnlocked(
                        archivePath: archivePath,
                        password: entry.password,
                        isVaultUnlocked: true
                    )
                    ArchiveEventCenter.shared.postArchiveCompleted(
                        archivePath: archivePath,
                        operationType: .extract,
                        duration: elapsed,
                        totalBytes: 0
                    )
                    return ExtractResult(
                        archivePath: archivePath,
                        destinationDir: destinationDir,
                        durationSeconds: elapsed,
                        unlockedPassword: entry.password,
                        isVaultUnlocked: true
                    )
                } catch {
                    // 继续下个口令
                }
            }
        }
        
        ArchiveEventCenter.shared.postExtractionFailed(archivePath: archivePath, error: "Password required")
        throw ArchiveError.passwordRequired
    }
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        guard !archivePath.isEmpty, !destinationDir.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        let extractor = ArchiveEngineFactory.makeExtractor()
        try await extractor.extractSingleFile(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: destinationDir,
            password: explicitPwd
        )
    }
    
    internal func executePipelineExtract(
        archivePath: String,
        destinationDir: String,
        password: String?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> Double {
        var builder = pipelineBuilderProvider()
            .withArchivePath(archivePath)
            .withDestinationDir(destinationDir)
            .withPassword(password)
        
        if let progress = progress {
            builder = builder.withProgressHandler(progress)
        }
        
        return try await builder.executeExtract()
    }
}
