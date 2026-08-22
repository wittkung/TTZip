// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance unified stream-based archive extraction engine (Ultra-Thin Rust C-ABI Facade).
public final class ArchiveExtractor: ArchiveExtracting, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(
        hardwareTuner: HardwareTunerProtocol = AppleSiliconTuner.shared,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }

    /// Synchronously extracts an archive to the destination directory via Rust C-ABI.
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

        if password == nil || password?.isEmpty == true {
            for vaultPwd in PasswordVaultManager.shared.candidatePasswordsForAutoUnlock() {
                if dispatchFastExtraction(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    options: options,
                    password: vaultPwd,
                    advancedOptions: advancedOptions
                ) {
                    return
                }
            }
        }

        if let items = try? fileManager.contentsOfDirectory(atPath: destinationDir) {
            for item in items {
                try? fileManager.removeItem(atPath: (destinationDir as NSString).appendingPathComponent(item))
            }
        }

        throw ArchiveError.readFailed(code: -1)
    }

    /// Asynchronously extracts an archive with Task cancellation support.
    public func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }

        if !fileManager.fileExists(atPath: destinationDir) {
            try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }

        Self.preventSpotlightIndexing(at: destinationDir)
        try Task.checkCancellation()

        try await Task.detached(priority: .userInitiated) {
            try self.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: options,
                password: password,
                advancedOptions: advancedOptions
            )
        }.value

        Self.cleanupQuarantineAttributes(at: destinationDir)
    }

    /// Unified facade method to extract an archive to the destination directory.
    @inline(__always)
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws {
        try await extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        )
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

    /// Joins multi-volume split archive files into a continuous output file via Rust C-ABI.
    public func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool {
        return CUnsafeBufferAdapter.withCString(firstVolumePath) { cFirst in
            CUnsafeBufferAdapter.withCString(outputPath) { cOut in
                guard let cFirst = cFirst, let cOut = cOut else { return false }
                return ttzip_rust_join_split_volumes(cFirst, cOut, nil, nil) == TTZIP_STATUS_OK
            }
        }
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

// MARK: - Extractor Dispatch

//
//


extension ArchiveExtractor {
    /// Dispatches format-specific fast-path extraction pipelines directly via Rust microkernel C-ABI.
    internal func dispatchFastExtraction(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) -> Bool {
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

        let items = ((try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []).filter { $0 != ".noindex" && $0 != ".DS_Store" && !$0.hasPrefix("._") }
        if status == TTZIP_STATUS_OK && !items.isEmpty {
            Self.cleanupQuarantineAttributes(at: destinationDir)
            return true
        }

        return false
    }
}

// MARK: - Selective Extractor

//
//


/// High-performance selective archive extractor for targeted file subsets.
///
/// Bypasses full-archive decompression by extracting selected paths.
public final class ArchiveSelectiveExtractor: @unchecked Sendable {
    public static let shared = ArchiveSelectiveExtractor()
    
    private init() {}
    
    /// Selectively extracts a subset of files matching targetEntryPaths into destinationDir.
    public func extractSelected(
        archivePath: String,
        targetEntryPaths: Set<String>,
        destinationDir: String,
        password: String? = nil
    ) async throws -> Int {
        guard !targetEntryPaths.isEmpty else { return 0 }
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: destinationDir) {
            try fm.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }
        
        let tempExtractionDir = fm.temporaryDirectory.appendingPathComponent("ttzip_selective_\(UUID().uuidString)").path
        defer { try? fm.removeItem(atPath: tempExtractionDir) }
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(
            archivePath: archivePath,
            destinationDir: tempExtractionDir,
            options: .defaultClean,
            password: password
        )
        
        var movedCount = 0
        for targetPath in targetEntryPaths {
            let srcPath = (tempExtractionDir as NSString).appendingPathComponent(targetPath)
            if fm.fileExists(atPath: srcPath) {
                let destPath = (destinationDir as NSString).appendingPathComponent(targetPath)
                let parentDir = (destPath as NSString).deletingLastPathComponent
                try? fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: destPath) {
                    try? fm.removeItem(atPath: destPath)
                }
                try fm.moveItem(atPath: srcPath, toPath: destPath)
                movedCount += 1
            }
        }
        
        return movedCount
    }
    
    /// Extracts a single entry directly into memory for instant Space-bar Quick Look or Drag-and-Drop.
    public func extractSingleEntryData(
        archivePath: String,
        entryPath: String,
        password: String? = nil
    ) async throws -> Data? {
        // 0. VFS LZ4 Cache Pool Fast Path
        if let cached = VFSLz4CachePool.shared.getCachedEntry(archivePath: archivePath, entryPath: entryPath) {
            return cached
        }
        
        // 1. Safe Rust Microkernel In-Memory Fast Path (7z archives)
        let ext = (archivePath as NSString).pathExtension.lowercased()
        if ext == "7z" || ext == "cb7" {
            let maxBufSize = 32 * 1024 * 1024 // 32MB single entry in-memory window
            var memBuffer = [UInt8](repeating: 0, count: maxBufSize)
            var extractedLen: Int = 0
            
            let status = archivePath.withCString { cArch in
                entryPath.withCString { cEntry in
                    CUnsafeBufferAdapter.withCString(password) { cPwd in
                        memBuffer.withUnsafeMutableBufferPointer { bPtr in
                            guard let base = bPtr.baseAddress else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                            return ttzip_rust_7z_extract_entry_memory(
                                cArch,
                                cEntry,
                                -1,
                                cPwd,
                                base,
                                maxBufSize,
                                &extractedLen
                            )
                        }
                    }
                }
            }
            
            if status == TTZIP_STATUS_OK && extractedLen > 0 && extractedLen <= maxBufSize {
                let data = Data(memBuffer.prefix(extractedLen))
                VFSLz4CachePool.shared.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: data)
                return data
            }
        }
        
        // 2. General Streaming Path: Extract single entry to ephemeral temp directory
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("ttzip_preview_\(UUID().uuidString)").path
        defer { try? fm.removeItem(atPath: tempDir) }
        
        let count = try await extractSelected(
            archivePath: archivePath,
            targetEntryPaths: [entryPath],
            destinationDir: tempDir,
            password: password
        )
        
        guard count > 0 else { return nil }
        let outPath = (tempDir as NSString).appendingPathComponent(entryPath)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: outPath)) {
            VFSLz4CachePool.shared.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: data)
            return data
        }
        return nil
    }
}
