// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Unified Extraction Facade

extension TTZipEngineFacade {
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        guard !archivePath.isEmpty, !destinationDir.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
        }
        
        if let explicitPwd = password, !explicitPwd.isEmpty {
            let elapsed = try await executePipelineExtract(
                archivePath: archivePath,
                destinationDir: destinationDir,
                password: explicitPwd,
                progress: combinedProgress
            )
            ArchivePasswordStore.shared.setPassword(explicitPwd, for: archivePath)
            return ExtractResult(
                archivePath: archivePath,
                destinationDir: destinationDir,
                durationSeconds: elapsed,
                unlockedPassword: explicitPwd,
                isVaultUnlocked: false
            )
        } else {
            do {
                let elapsed = try await executePipelineExtract(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: nil,
                    progress: combinedProgress
                )
                return ExtractResult(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    durationSeconds: elapsed,
                    unlockedPassword: nil,
                    isVaultUnlocked: false
                )
            } catch {
                // Password-less extraction failed, try password vault auto-unlock
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
                    return ExtractResult(
                        archivePath: archivePath,
                        destinationDir: destinationDir,
                        durationSeconds: elapsed,
                        unlockedPassword: entry.password,
                        isVaultUnlocked: true
                    )
                } catch {
                    // Try next candidate password in vault
                }
            }
        }
        
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
        
        let res = try await builder.executeExtract()
        return res.throughputMBs
    }
}
