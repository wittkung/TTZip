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

        let targetFmt = self.targetFormat ?? format
        if targetFmt == .zip {
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
            if handled { return }
        }

        let actualFormat: ArchiveCompressionFormat
        if targetFmt == .zst {
            actualFormat = .tarZst
        } else if targetFmt == .iso {
            actualFormat = .tar
        } else {
            actualFormat = targetFmt
        }

        let success = createArchiveWithRust(
            outputPath: outputPath,
            format: actualFormat,
            inputPaths: inputPaths,
            level: level,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            skipMacJunk: options.skipMacJunk,
            startTime: startTime,
            totalBytes: totalBytes,
            progressHandler: progressHandler
        )

        if success {
            return
        }

        throw ArchiveError.readFailed(code: -1)
    }

    /// Directly drives archive compression through the Rust C-ABI microkernel.
    internal func createArchiveWithRust(
        outputPath: String,
        format: ArchiveCompressionFormat,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        password: String?,
        splitVolumeSizeBytes: Int64? = nil,
        skipMacJunk: Bool = true,
        startTime: Date = Date(),
        totalBytes: Int64 = 0,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) -> Bool {
        let rustFormat = ArchiveWriter.mapFormat(format)
        let lvlMap = ArchiveWriter.mapLevel(level)

        let enc: TTZipEncryptionMethod = (password != nil && !password!.isEmpty) ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let splitSize = UInt64(max(0, splitVolumeSizeBytes ?? 0))

        let status = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
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
                    return ttzip_rust_archive_create_unified(cInputPaths, inputPaths.count, cOutputPath, &opt, splitSize)
                }
            }
        }

        if status == TTZIP_STATUS_OK {
            notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "Archive created", progressHandler: progressHandler)
            return true
        }
        return false
    }
}
