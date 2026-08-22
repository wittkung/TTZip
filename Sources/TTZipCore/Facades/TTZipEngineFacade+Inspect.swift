// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Unified Archive Inspection & Structure Probing Facade

extension TTZipEngineFacade {
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        guard !archivePath.isEmpty, FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        
        do {
            let entries = try await reader.inspect(archivePath: archivePath, password: explicitPwd)
            let treeNode = ArchiveComponentTreeBuilder.buildTree(from: entries)
            let securityReport = securityScanner.scanEntriesForReport(entries)
            if let p = explicitPwd, !p.isEmpty {
                ArchivePasswordStore.shared.setPassword(p, for: archivePath)
            }
            return ArchiveInspectionResult(
                archivePath: archivePath,
                entries: entries,
                treeNode: treeNode,
                securityReport: securityReport,
                unlockedPassword: explicitPwd
            )
        } catch ArchiveError.passwordRequired {
            // Fall through to password vault auto-unlock
        } catch {
            if explicitPwd != nil && explicitPwd?.isEmpty == false {
                throw error
            }
        }
        
        if autoVaultUnlock {
            let vaultEntries = passwordVault.getEntries()
            for entry in vaultEntries {
                if let entries = try? await reader.inspect(archivePath: archivePath, password: entry.password) {
                    passwordVault.recordUsage(id: entry.id)
                    ArchivePasswordStore.shared.setPassword(entry.password, for: archivePath)
                    let treeNode = ArchiveComponentTreeBuilder.buildTree(from: entries)
                    let securityReport = securityScanner.scanEntriesForReport(entries)
                    return ArchiveInspectionResult(
                        archivePath: archivePath,
                        entries: entries,
                        treeNode: treeNode,
                        securityReport: securityReport,
                        unlockedPassword: entry.password
                    )
                }
            }
        }
        
        throw ArchiveError.passwordRequired
    }
    
    // MARK: - Auxiliary High-Level Facade (Integrity, Repair & Password Recovery)
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        let crc = integrityChecker.computeCRC32(filePath: archivePath)
        let sha = try await integrityChecker.computeSHA256(filePath: archivePath)
        return HashVerificationResult(filePath: archivePath, crc32: crc, sha256: sha)
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        guard !damagedPath.isEmpty, !outputPath.isEmpty, FileManager.default.fileExists(atPath: damagedPath) else {
            throw ArchiveError.fileNotFound
        }
        return try await repairEngine.repairArchive(damagedArchivePath: damagedPath, repairedOutputPath: outputPath)
    }
    
    public func recoverPassword(
        archivePath: String,
        dictionary: [String]
    ) async throws -> PasswordRecoveryResult {
        return try await recoveryEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }
}
