// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance unified stream-based archive extraction engine.
public final class ArchiveExtractor: ArchiveExtracting, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(
        hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }

    /// Synchronously extracts an archive to the destination directory.
    @inline(__always)
    public func extractSync(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }

        if !fileManager.fileExists(atPath: destinationDir) {
            try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }

        Self.preventSpotlightIndexing(at: destinationDir)
        defer { Self.cleanupQuarantineAttributes(at: destinationDir) }

        hardwareTuner.boostCurrentThreadPriority()

        if dispatchFastExtraction(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        ) {
            return
        }

        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let status = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
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
                    return ttzip_rust_archive_extract_unified(aPtr, dPtr, &opt)
                }
            }
        }

        if status == TTZIP_STATUS_OK {
            return
        }

        if let items = try? fileManager.contentsOfDirectory(atPath: destinationDir) {
            for item in items {
                try? fileManager.removeItem(atPath: (destinationDir as NSString).appendingPathComponent(item))
            }
        }

        if status == TTZIP_STATUS_CANCELLED {
            throw CancellationError()
        }

        throw ArchiveError.readFailed(code: status.rawValue)
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

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }

        if !fileManager.fileExists(atPath: destinationDir) {
            try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }

        Self.preventSpotlightIndexing(at: destinationDir)
        try Task.checkCancellation()

        let passCandidates: [String?] = password != nil ? [password] : {
            let vaultCandidates = PasswordVaultManager.shared.candidatePasswordsForAutoUnlock()
            return vaultCandidates.isEmpty ? [nil] : vaultCandidates.map { Optional($0) }
        }()

        try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            self.hardwareTuner.boostCurrentThreadPriority()

            for cand in passCandidates {
                if self.dispatchFastExtraction(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    options: options,
                    password: cand,
                    advancedOptions: advancedOptions
                ) {
                    return
                }

                let status = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
                    CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                        CUnsafeBufferAdapter.withCString(cand) { pPtr in
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
                            return ttzip_rust_archive_extract_unified(aPtr, dPtr, &opt)
                        }
                    }
                }

                if status == TTZIP_STATUS_OK {
                    return
                }
            }

            if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir) {
                for item in items {
                    try? FileManager.default.removeItem(atPath: (destinationDir as NSString).appendingPathComponent(item))
                }
            }

            throw ArchiveError.readFailed(code: -11)
        }.value

        Self.cleanupQuarantineAttributes(at: destinationDir)
    }

    /// Synchronously extracts a single file from the archive without processing other entries.
    public func extractSingleFile(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: destinationDir) {
                try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
            }

            let pwd = (password != nil && !password!.isEmpty) ? password : nil
            let status = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
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
                        return ttzip_rust_archive_extract_unified(aPtr, dPtr, &opt)
                    }
                }
            }

            if status != TTZIP_STATUS_OK {
                throw ArchiveError.readFailed(code: status.rawValue)
            }
        }.value

        Self.cleanupQuarantineAttributes(at: destinationDir)
    }

    /// Joins multi-volume split archive files into a continuous output file.
    public func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool {
        do {
            try SplitVolumeConcatenator.shared.join(firstVolumePath: firstVolumePath, outputPath: outputPath)
            return true
        } catch {
            return false
        }
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
}
