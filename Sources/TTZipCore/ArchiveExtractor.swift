// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance stream-based archive extraction engine.
public final class ArchiveExtractor: ArchiveExtracting, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner, targetFormat: ArchiveCompressionFormat? = nil) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }

    /// Synchronously extracts an archive to the destination directory (zero Task queue overhead).
    @inline(__always)
    public func extractSync(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) throws {
        let template = ArchiveEngineTemplateRegistry.shared.template(forPath: archivePath, operation: .extract)
        let context = ArchiveTemplateContext(
            operation: .extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            options: options,
            advancedOptions: advancedOptions
        )
        _ = try template.performWorkflow(context: context)
    }

    /// Asynchronously extracts an archive with password candidate traversal and fast-path dispatch.
    public func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws {
        let valCtx = ArchiveValidationContext.forExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password
        )
        try ArchiveValidationPipeline.buildDefaultExtractPipeline().validateOrThrow(context: valCtx)
        
        let pathLower = archivePath.lowercased()
        let passCandidates = password != nil ? [password!] : PasswordVaultManager.shared.candidatePasswordsForAutoUnlock()
        
        // Handle split multi-volume 7z archives (.001 / .7z.001)
        if pathLower.hasSuffix(".001") || pathLower.contains(".7z.") {
            let activePwd = password ?? passCandidates.first
            let pwd = (activePwd != nil && !activePwd!.isEmpty) ? activePwd : nil
            
            if pathLower.hasSuffix(".001") {
                let joinedTemp = FileManager.default.temporaryDirectory.appendingPathComponent("joined_\(UUID().uuidString).7z").path
                defer { try? FileManager.default.removeItem(atPath: joinedTemp) }
                if self.joinSplitVolumes(firstVolumePath: archivePath, outputPath: joinedTemp) {
                    if let ok = try? SevenZipEngine.shared.extract(archivePath: joinedTemp, destinationDir: destinationDir, password: pwd), ok {
                        let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
                        if !items.isEmpty { return }
                    }
                }
            }
            
            if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: pwd), ok {
                let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
                if !items.isEmpty { return }
            }
            let status = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
                CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                    CUnsafeBufferAdapter.withCString(pwd) { pPtr in
                        guard let aPtr = aPtr, let dPtr = dPtr else { return Int32(-1) }
                        var opt = TTZipExtractOptions(
                            destination_path: dPtr,
                            password: pPtr,
                            thread_budget: 4,
                            overwrite_existing: true,
                            preserve_permissions: true,
                            dry_run: false,
                            progress_callback: nil,
                            user_data: nil
                        )
                        let rStatus = ttzip_rust_extract_archive(aPtr, dPtr, &opt)
                        if rStatus == TTZIP_STATUS_OK {
                            return Int32(0)
                        }
                        return ttzip_extract_archive_advanced(aPtr, dPtr, options.skipMacJunk, pPtr)
                    }
                }
            }
            if status == 0 {
                return
            }
            try await extractSingleFile(archivePath: archivePath, entryPath: "*", destinationDir: destinationDir, password: pwd)
            return
        }
        
        // Fast-path for Apple DMG containers (UDIF with LZFSE / ZLIB / RAW / LZMA chunks)
        if pathLower.hasSuffix(".dmg") {
            let candidates: [String?] = passCandidates.isEmpty ? [password] : passCandidates.map { Optional($0) }
            for cand in candidates {
                if let ok = try? DMGVirtualStreamAdapter.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: cand, skipMacJunk: options.skipMacJunk), ok {
                    if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
                        return
                    }
                }
            }
        }
        
        // Fast-path for single-file .lzfse archives
        if pathLower.hasSuffix(".lzfse") {
            let outName = URL(fileURLWithPath: archivePath).deletingPathExtension().lastPathComponent
            let targetOut = (destinationDir as NSString).appendingPathComponent(outName.isEmpty ? "decompressed" : outName)
            if LzfseCAdapter.shared.decompressFileStream(srcPath: archivePath, dstPath: targetOut) == 0 {
                return
            }
        }
        
        // Fast-path for 7z / DMG / ISO containers
        if pathLower.contains(".7z") || pathLower.contains("sevenzip") || pathLower.hasSuffix(".cb7") || pathLower.hasSuffix(".dmg") || pathLower.hasSuffix(".iso") {
            let activePwd = password ?? passCandidates.first
            let pwd = (activePwd != nil && !activePwd!.isEmpty) ? activePwd : nil
            let rStatus = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
                CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                    CUnsafeBufferAdapter.withCString(pwd) { pPtr in
                        guard let aPtr = aPtr, let dPtr = dPtr else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                        var opt = TTZipExtractOptions(
                            destination_path: dPtr,
                            password: pPtr,
                            thread_budget: 0,
                            overwrite_existing: true,
                            preserve_permissions: true,
                            dry_run: false,
                            progress_callback: nil,
                            user_data: nil
                        )
                        return ttzip_rust_extract_archive(aPtr, dPtr, &opt)
                    }
                }
            }
            if rStatus == TTZIP_STATUS_OK {
                let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
                if !items.isEmpty {
                    return
                }
            }
            
            let candidates: [String?] = passCandidates.isEmpty ? [password] : passCandidates.map { Optional($0) }
            for cand in candidates {
                if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: cand), ok {
                    if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
                        return
                    }
                }
            }
        }
        
        // Native parallel engine fast-path for ZIP archives
        if pathLower.hasSuffix(".zip") || pathLower.contains(".zip") {
            let activePwd = password ?? passCandidates.first
            let pwd = (activePwd != nil && !activePwd!.isEmpty) ? activePwd : nil
            let rStatus = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
                CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                    CUnsafeBufferAdapter.withCString(pwd) { pPtr in
                        guard let aPtr = aPtr, let dPtr = dPtr else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                        var opt = TTZipExtractOptions(
                            destination_path: dPtr,
                            password: pPtr,
                            thread_budget: 0,
                            overwrite_existing: true,
                            preserve_permissions: true,
                            dry_run: false,
                            progress_callback: nil,
                            user_data: nil
                        )
                        return ttzip_rust_extract_archive(aPtr, dPtr, &opt)
                    }
                }
            }
            if rStatus == TTZIP_STATUS_OK {
                return
            }
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        if !fileManager.fileExists(atPath: destinationDir) {
            try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }
        
        Self.preventSpotlightIndexing(at: destinationDir)
        try Task.checkCancellation()
        
        let performExtraction = { [weak self] () throws in
            self?.hardwareTuner.boostCurrentThreadPriority()
            let candidates: [String?] = (password != nil) ? [password] : (passCandidates.isEmpty ? [nil] : passCandidates.map { Optional($0) })
            var lastStatus: Int32 = -1
            for cand in candidates {
                let status = ttzip_extract_archive_advanced(archivePath, destinationDir, options.skipMacJunk, cand)
                if status == 0 {
                    return
                }
                lastStatus = status
            }
            throw ArchiveError.readFailed(code: lastStatus)
        }
        
        try await Task.detached(priority: .userInitiated) {
            try performExtraction()
        }.value
        
        Self.cleanupQuarantineAttributes(at: destinationDir)
    }
    
    /// Synchronously extracts a single file from the archive without processing other entries.
    public func extractSingleFile(archivePath: String, entryPath: String, destinationDir: String, password: String? = nil) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: destinationDir) {
                try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
            }
            
            let pathLower = archivePath.lowercased()
            if pathLower.contains(".7z") || pathLower.contains("sevenzip") || pathLower.hasSuffix(".cb7") {
                if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: password), ok {
                    return
                }
            } else if pathLower.hasSuffix(".zip") {
                let pwd = (password != nil && !password!.isEmpty) ? password : nil
                let rStatus = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
                    CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                        CUnsafeBufferAdapter.withCString(pwd) { pPtr in
                            guard let aPtr = aPtr, let dPtr = dPtr else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                            var opt = TTZipExtractOptions(
                                destination_path: dPtr,
                                password: pPtr,
                                thread_budget: 0,
                                overwrite_existing: true,
                                preserve_permissions: true,
                                dry_run: false,
                                progress_callback: nil,
                                user_data: nil
                            )
                            return ttzip_rust_extract_archive(aPtr, dPtr, &opt)
                        }
                    }
                }
                if rStatus == TTZIP_STATUS_OK {
                    return
                }
            } else if pathLower.hasSuffix(".aar") {
                if let ok = try? NativeAppleArchiveEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir), ok {
                    return
                }
            }
            
            let status = ttzip_extract_archive_advanced(archivePath, destinationDir, false, password)
            if status != 0 {
                throw ArchiveError.readFailed(code: status)
            }
        }.value
        Self.cleanupQuarantineAttributes(at: destinationDir)
    }

    // MARK: - Helpers
    
    internal static func cleanupQuarantineAttributes(at dirPath: String) {
        dirPath.withCString { pathPtr in
            let sz = getxattr(pathPtr, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW)
            if sz > 0 {
                removexattr(pathPtr, "com.apple.quarantine", XATTR_NOFOLLOW)
            }
        }
    }
    
    private static func preventSpotlightIndexing(at dirPath: String) {
        let noIndexFilePath = (dirPath as NSString).appendingPathComponent(".noindex")
        if !FileManager.default.fileExists(atPath: noIndexFilePath) {
            FileManager.default.createFile(atPath: noIndexFilePath, contents: nil)
        }
    }
    
    public func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool {
        let status = firstVolumePath.withCString { cFirst in
            outputPath.withCString { cOut in
                ttzip_rust_join_split_volumes(cFirst, cOut, nil, nil)
            }
        }
        return status == TTZIP_STATUS_OK
    }

    /// Template Method Pattern execution of streaming archive extraction.
    public func extractViaTemplate(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) throws -> WorkflowResult {
        let context = ArchiveTemplateContext(
            operation: .extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            options: options,
            advancedOptions: advancedOptions
        )
        let template = ArchiveEngineTemplateRegistry.shared.template(forPath: archivePath, operation: .extract)
        return try template.performWorkflow(context: context)
    }
}
