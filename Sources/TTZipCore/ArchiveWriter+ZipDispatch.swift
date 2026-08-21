// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension ArchiveWriter {
    /// Dispatches compression requests targeting the ZIP archive format.
    /// - Returns: `true` if the archive creation was handled and completed successfully, `false` otherwise.
    internal func dispatchZipCreation(
        outputPath: String,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        startTime: Date,
        totalBytes: Int64,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool {
        // 0. Transparent Adaptive Store Auto-Downgrade Route (Zero Configuration Creep)
        if level != .store && (password == nil || password!.isEmpty) && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0),
           let firstInput = inputPaths.first, inputPaths.count == 1, totalBytes >= 64 * 1024 {
            let eval = AdaptivePipelineOrchestrator.shared.evaluateFile(atPath: firstInput)
            if eval.recommendDirectStore && eval.shannonEntropy > 7.65 {
                let success = (try? ZipStoreStreamWriter.shared.createStoreArchive(
                    outputPath: outputPath,
                    inputPaths: inputPaths,
                    skipMacJunk: options.skipMacJunk,
                    enableZeroCopy: true,
                    progressHandler: progressHandler
                )) ?? false
                if success {
                    notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "Adaptive Store zero-copy archive created", progressHandler: progressHandler)
                    return true
                }
            }
        }

        // 1. Level 0 Store Direct I/O Route (16MB SIMD page-aligned zero-copy)
        // 🔒 API CONTRACT: ZIP Store Dispatch Route (Hand-tuned Zero-Copy Pipeline)
        // SEE: .agents/rules/zip-engine-freeze.md
        if level == .store && (password == nil || password!.isEmpty) && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0) {
            let success = try ZipStoreStreamWriter.shared.createStoreArchive(
                outputPath: outputPath,
                inputPaths: inputPaths,
                skipMacJunk: options.skipMacJunk,
                enableZeroCopy: advancedOptions.zipOptions.enableZeroCopy,
                progressHandler: progressHandler
            )
            if success {
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "Store zero-copy archive created", progressHandler: progressHandler)
                return true
            }
        }
        
        // 1.5. Single-File Extreme Multi-Block Parallel Route (Zopfli DAG / Near-Optimal DP + 32KB cross-block warmup)
        if (level == .level2 || level == .level3 || level == .level4 || level == .level5 || level == .level6 || level == .level7) && (password == nil || password!.isEmpty) && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0),
           inputPaths.count == 1, let singlePath = inputPaths.first {

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: singlePath, isDirectory: &isDir), !isDir.boolValue {
                let attrs = (try? FileManager.default.attributesOfItem(atPath: singlePath)) ?? [:]
                let fileSize = (attrs[.size] as? Int64) ?? 0
                if fileSize >= 2 * 1024 * 1024 {
                    let extremeOk = (try? ZipExtremeBlockWriter.shared.createExtremeArchive(
                        outputPath: outputPath,
                        inputPath: singlePath,
                        level: level
                    )) ?? false
                    if extremeOk {
                        notifyCompletion(totalBytes: fileSize, startTime: startTime, message: "ZIP Extreme archive created", progressHandler: progressHandler)
                        return true
                    }
                }
            }
        }
        
        // 2. Native ZIP multi-threaded parallel compression engine (libdeflate + mmap + NEON CRC32)
        // 🔒 API CONTRACT: ZIP Parallel Compression Engine Route
        // SEE: .agents/rules/zip-engine-freeze.md
        if (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0) {
            let lvlMap: TTZipCompressionLevel
            switch level {
            case .store: lvlMap = TTZIP_COMPRESSION_LEVEL_STORE
            case .fastest, .fast: lvlMap = TTZIP_COMPRESSION_LEVEL_FASTEST
            case .normal: lvlMap = TTZIP_COMPRESSION_LEVEL_NORMAL
            case .maximum: lvlMap = TTZIP_COMPRESSION_LEVEL_MAXIMUM
            case .ultra: lvlMap = TTZIP_COMPRESSION_LEVEL_ULTRA
            default: lvlMap = TTZIP_COMPRESSION_LEVEL_NORMAL
            }
            let enc: TTZipEncryptionMethod = (password != nil && !password!.isEmpty) ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE
            let pwd = (password != nil && !password!.isEmpty) ? password : nil
            let res = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
                CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                    CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                        guard let cOutputPath = cOutputPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                        var opt = TTZipCreateOptions(
                            format: TTZIP_ARCHIVE_FORMAT_ZIP,
                            level: lvlMap,
                            encryption: enc,
                            password: cPassword,
                            thread_budget: 0,
                            solid_block_size_mb: 0,
                            progress_callback: nil,
                            user_data: nil
                        )
                        return ttzip_rust_create_archive(cInputPaths, inputPaths.count, cOutputPath, &opt)
                    }
                }
            }
            if res == TTZIP_STATUS_OK {
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "ZIP archive created", progressHandler: progressHandler)
                return true
            }
        }

        // 3. Split multi-volume creation mode for ZIP
        if let splitBytes = splitVolumeSizeBytes, splitBytes > 0 {
            let lvlMap: TTZipCompressionLevel
            switch level {
            case .store: lvlMap = TTZIP_COMPRESSION_LEVEL_STORE
            case .fastest, .fast: lvlMap = TTZIP_COMPRESSION_LEVEL_FASTEST
            case .normal: lvlMap = TTZIP_COMPRESSION_LEVEL_NORMAL
            case .maximum: lvlMap = TTZIP_COMPRESSION_LEVEL_MAXIMUM
            case .ultra: lvlMap = TTZIP_COMPRESSION_LEVEL_ULTRA
            default: lvlMap = TTZIP_COMPRESSION_LEVEL_NORMAL
            }
            let enc: TTZipEncryptionMethod = (password != nil && !password!.isEmpty) ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE
            let pwd = (password != nil && !password!.isEmpty) ? password : nil
            let res = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
                CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                    CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                        guard let cOutputPath = cOutputPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                        var opt = TTZipCreateOptions(
                            format: TTZIP_ARCHIVE_FORMAT_ZIP,
                            level: lvlMap,
                            encryption: enc,
                            password: cPassword,
                            thread_budget: 0,
                            solid_block_size_mb: 0,
                            progress_callback: nil,
                            user_data: nil
                        )
                        return ttzip_rust_create_archive(cInputPaths, inputPaths.count, cOutputPath, &opt)
                    }
                }
            }
            if res == TTZIP_STATUS_OK {
                try? Self.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "ZIP multi-volume archive created", progressHandler: progressHandler)
                return true
            }
        }

        return false
    }
}
