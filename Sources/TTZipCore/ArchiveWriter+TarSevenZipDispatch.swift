// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension ArchiveWriter {
    internal func notifyCompletion(
        totalBytes: Int64,
        startTime: Date,
        message: String,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) {
        let duration = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
        progressHandler?(ArchiveProgress(
            state: .completed,
            bytesProcessed: totalBytes,
            totalBytes: totalBytes,
            currentFileName: message,
            throughputMBs: throughput
        ))
    }

    /// Internal synchronous archive creation implementation.
    internal func createArchiveInternal(
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?,
        startTime: Date,
        totalBytes: Int64
    ) throws {
        hardwareTuner.boostCurrentThreadPriority()
            
        // 1. 7z fast path
        if format == .sevenZip {
            let success = try SevenZipParallelWriter.shared.createArchive(
                outputPath: outputPath,
                inputPaths: inputPaths,
                level: level,
                password: password,
                progressHandler: progressHandler
            )
            if success {
                if let splitBytes = splitVolumeSizeBytes, splitBytes > 0 {
                    try ArchiveWriter.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
                }
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "7z compression completed", progressHandler: progressHandler)
                return
            }
        }
            
        // ZIP compression routes
        if format == .zip {
            let handled = try dispatchZipCreation(
                outputPath: outputPath,
                level: level,
                inputPaths: inputPaths,
                options: options,
                splitVolumeSizeBytes: splitVolumeSizeBytes,
                password: password,
                advancedOptions: advancedOptions,
                startTime: startTime,
                totalBytes: totalBytes,
                progressHandler: progressHandler
            )
            if handled {
                return
            }
        }

        // 2. Native ZST streaming engine
        if format == .zst, let srcPath = inputPaths.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: srcPath, isDirectory: &isDir), !isDir.boolValue {
                let success = try NativeZstdEngine.shared.compressFile(
                    srcPath: srcPath,
                    dstPath: outputPath,
                    level: level,
                    enableLDM: advancedOptions.zstdEnableLDM,
                    progressHandler: progressHandler
                )
                if success {
                    notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "ZST compression completed", progressHandler: progressHandler)
                    return
                }
            }
        }

        // 4. Native in-memory C streaming engine for small TAR archives (<50MB)
        let hasDirectoryInput = inputPaths.contains { p in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: p, isDirectory: &isDir) && isDir.boolValue
        }
        if !hasDirectoryInput && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes! == 0) && (format == .tarGz || format == .tarZst || format == .tarBz2 || format == .tarXz) && totalBytes < 50 * 1024 * 1024 && (password == nil || password!.isEmpty) {
            let res = createArchiveWithRust(
                outputPath: outputPath,
                format: format,
                inputPaths: inputPaths,
                level: level,
                password: nil,
                skipMacJunk: options.skipMacJunk
            )
            if res {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                progressHandler?(ArchiveProgress(
                    state: .completed,
                    bytesProcessed: totalBytes,
                    totalBytes: totalBytes,
                    currentFileName: "Archive created",
                    throughputMBs: throughput
                ))
                return
            }
        }
        
        // 3. Split multi-volume creation mode for 7z
        if format == .sevenZip && (splitVolumeSizeBytes != nil && splitVolumeSizeBytes! > 0) {
            let splitBytes = splitVolumeSizeBytes!
            let success = (try? SevenZipParallelWriter.shared.createArchive(
                outputPath: outputPath,
                inputPaths: inputPaths,
                level: level,
                password: password,
                progressHandler: progressHandler
            )) ?? false
            if success {
                try? Self.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "7z multi-volume archive created", progressHandler: progressHandler)
                return
            }
        }
        
        // Formats: Apple Archive, Brotli, DMG, ISO, WIM
        if format == .aar, let firstInput = inputPaths.first {
            if let ok = try? NativeAppleArchiveEngine.shared.compress(sourcePath: firstInput, outputPath: outputPath), ok {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "Apple Archive created", throughputMBs: throughput))
                return
            }
        }
        
        if format == .brotli {
            if let ok = try? NativeBrotliEngine.shared.createArchive(outputPath: outputPath, inputPaths: inputPaths, level: level, skipMacJunk: options.skipMacJunk, progressHandler: progressHandler), ok {
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "Brotli archive created", progressHandler: progressHandler)
                return
            }
        }
        
        if (format == .dmg || format == .iso) {
            let res = createArchiveWithRust(
                outputPath: outputPath,
                format: format,
                inputPaths: inputPaths,
                level: level,
                password: nil,
                skipMacJunk: options.skipMacJunk
            )
            if res {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                let msg = format == .dmg ? "DMG disk image created" : "ISO disk image created"
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: msg, throughputMBs: throughput))
                return
            }
        }
        
        if format == .wim {
            let res = createArchiveWithRust(
                outputPath: outputPath,
                format: .tar,
                inputPaths: inputPaths,
                level: level,
                password: password,
                skipMacJunk: options.skipMacJunk
            )
            if res {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "WIM archive created", throughputMBs: throughput))
                return
            }
        }
        
        let actualFormat = (format == .zst) ? .tarZst : format
        let res = createArchiveWithRust(
            outputPath: outputPath,
            format: actualFormat,
            inputPaths: inputPaths,
            level: level,
            password: password,
            skipMacJunk: options.skipMacJunk
        )
        if res {
            if let splitBytes = splitVolumeSizeBytes, splitBytes > 0 {
                try Self.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
            }
            let duration = max(0.001, Date().timeIntervalSince(startTime))
            let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
            progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "Archive created", throughputMBs: throughput))
            return
        }
        
        throw ArchiveError.readFailed(code: -1)
    }

    internal func createArchiveWithRust(
        outputPath: String,
        format: ArchiveCompressionFormat,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        password: String?,
        skipMacJunk: Bool
    ) -> Bool {
        let rustFormat: TTZipArchiveFormat
        switch format {
        case .zip: rustFormat = TTZIP_ARCHIVE_FORMAT_ZIP
        case .sevenZip: rustFormat = TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP
        case .tar, .tarGz, .gz, .tarZst, .zst, .tarBz2, .bz2, .tarXz, .xz: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR
        default: rustFormat = TTZIP_ARCHIVE_FORMAT_TAR
        }

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

        return CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return false }
                    var opt = TTZipCreateOptions(
                        format: rustFormat,
                        level: lvlMap,
                        encryption: enc,
                        password: cPassword,
                        thread_budget: 0,
                        solid_block_size_mb: 0,
                        progress_callback: nil,
                        user_data: nil
                    )
                    return ttzip_rust_create_archive(cInputPaths, inputPaths.count, cOutputPath, &opt) == TTZIP_STATUS_OK
                }
            }
        }
    }
}
