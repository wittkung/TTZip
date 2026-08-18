// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension ArchiveWriter {
    private func notifyCompletion(
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
            
        // 0. Transparent Adaptive Store Auto-Downgrade Route (Zero Configuration Creep)
        if format == .zip && level != .store && (password == nil || password!.isEmpty) && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0),
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
                    return
                }
            }
        }

        // 1. Level 0 Store Direct I/O Route (16MB SIMD page-aligned zero-copy)
        // 🔒 API CONTRACT: ZIP Store Dispatch Route (Hand-tuned Zero-Copy Pipeline)
        // SEE: .agents/rules/zip-engine-freeze.md
        if format == .zip && level == .store && (password == nil || password!.isEmpty) && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0) {
            let success = try ZipStoreStreamWriter.shared.createStoreArchive(
                outputPath: outputPath,
                inputPaths: inputPaths,
                skipMacJunk: options.skipMacJunk,
                enableZeroCopy: advancedOptions.zipOptions.enableZeroCopy,
                progressHandler: progressHandler
            )
            if success {
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "Store zero-copy archive created", progressHandler: progressHandler)
                return
            }
        }
        
        // 1.5. Single-File Extreme Multi-Block Parallel Route (Zopfli DAG / Near-Optimal DP + 32KB cross-block warmup)
        if format == .zip && (level == .level2 || level == .level3 || level == .level4 || level == .level5 || level == .level6 || level == .level7) && (password == nil || password!.isEmpty) && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0),
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
                        return
                    }
                }
            }
        }
        
        // 2. Native ZIP multi-threaded parallel compression engine (libdeflate + mmap + NEON CRC32)
        // 🔒 API CONTRACT: ZIP Parallel Compression Engine Route
        // SEE: .agents/rules/zip-engine-freeze.md
        if format == .zip && (splitVolumeSizeBytes == nil || splitVolumeSizeBytes == 0) {
            let cLevel = Int32(level.rawValue)
            let res = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
                CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                    CUnsafeBufferAdapter.withCString(password) { cPassword in
                        guard let cOutputPath = cOutputPath else { return Int32(-1) }
                        let status = ttzip_create_zip_parallel_c(cOutputPath, cInputPaths, inputPaths.count, cLevel, options.skipMacJunk, cPassword)
                        if status == 0 { return Int32(0) }
                        return ttzip_create_archive_tuned(cOutputPath, "zip", cInputPaths, inputPaths.count, options.skipMacJunk, cLevel, 0, 16, cPassword)
                    }
                }
            }
            if res == 0 {
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "ZIP archive created", progressHandler: progressHandler)
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
            let cores = (advancedOptions.cpuThreads > 0) ? advancedOptions.cpuThreads : hardwareTuner.totalCores
            
            let fmtStr: String
            switch format {
            case .zip: fmtStr = "zip"
            case .sevenZip: fmtStr = "7z"
            case .tarGz, .gz: fmtStr = "tar.gz"
            case .tarZst, .zst: fmtStr = "tar.zst"
            case .tarBz2, .bz2: fmtStr = "tar.bz2"
            case .tarXz, .xz: fmtStr = "tar.xz"
            default: fmtStr = format.rawValue
            }
            
            let res = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
                CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                    guard let cOutputPath = cOutputPath else { return Int32(-1) }
                    return ttzip_create_archive_tuned(
                        cOutputPath,
                        fmtStr,
                        cInputPaths,
                        inputPaths.count,
                        options.skipMacJunk,
                        Int32(level.rawValue),
                        0,
                        Int32(cores),
                        nil
                    )
                }
            }
            if res == 0 {
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
        
        // 3. Split multi-volume creation mode
        if (format == .sevenZip || format == .zip) && (splitVolumeSizeBytes != nil && splitVolumeSizeBytes! > 0) {
            let splitBytes = splitVolumeSizeBytes!
            if format == .sevenZip {
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
            } else {
                let cLevel = Int32(level.rawValue)
                let res = CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
                    CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                        CUnsafeBufferAdapter.withCString(password) { cPassword in
                            guard let cOutputPath = cOutputPath else { return Int32(-1) }
                            let status = ttzip_create_zip_parallel_c(cOutputPath, cInputPaths, inputPaths.count, cLevel, options.skipMacJunk, cPassword)
                            if status == 0 { return Int32(0) }
                            return ttzip_create_archive_tuned(cOutputPath, "zip", cInputPaths, inputPaths.count, options.skipMacJunk, cLevel, 0, 16, cPassword)
                        }
                    }
                }
                if res == 0 {
                    try? Self.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
                    notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "ZIP multi-volume archive created", progressHandler: progressHandler)
                    return
                }
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
            let res = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                ttzip_create_tar_native_c(outputPath, "iso", cInputPaths, inputPaths.count, options.skipMacJunk, Int32(level.rawValue))
            }
            if res == 0 {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                let msg = format == .dmg ? "DMG disk image created" : "ISO disk image created"
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: msg, throughputMBs: throughput))
                return
            }
        }
        
        if format == .wim {
            let res = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                ttzip_create_archive_tuned(outputPath, "wim", cInputPaths, inputPaths.count, options.skipMacJunk, Int32(level.rawValue), 0, Int32(hardwareTuner.totalCores), password)
            }
            if res == 0 {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "WIM archive created", throughputMBs: throughput))
                return
            }
        }
        
        let actualFormat = (format == .zst) ? .tarZst : format
        if (actualFormat == .tarZst || actualFormat == .tarGz || actualFormat == .sevenZip || actualFormat == .tar || actualFormat == .bz2 || actualFormat == .xz || actualFormat == .lzip || actualFormat == .lz4 || actualFormat == .brotli || actualFormat == .lrzip || actualFormat == .snappy || actualFormat == .wim) {
            let zstdLevel = Int32(level.rawValue)
            let zstdWindow = advancedOptions.zstdEnableLDM ? Int32(hardwareTuner.optimalZstdLongWindowLog) : 0
            let threads = Int32(hardwareTuner.totalCores)
            
            let cFormat: String
            switch actualFormat {
            case .tarGz, .gz: cFormat = "tar.gz"
            case .tarZst, .zst: cFormat = "tar.zst"
            case .sevenZip: cFormat = "7z"
            case .bz2, .tarBz2: cFormat = "tar.bz2"
            case .xz, .tarXz: cFormat = "tar.xz"
            case .lzip: cFormat = "lzip"
            case .lz4: cFormat = "lz4"
            case .brotli: cFormat = "brotli"
            case .lrzip: cFormat = "lrzip"
            case .snappy: cFormat = "snappy"
            case .wim: cFormat = "wim"
            default: cFormat = "tar"
            }
            
            let res = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                ttzip_create_archive_tuned(
                    outputPath,
                    cFormat,
                    cInputPaths,
                    inputPaths.count,
                    options.skipMacJunk,
                    zstdLevel,
                    zstdWindow,
                    threads,
                    password
                )
            }
            if res == 0 {
                if let splitBytes = splitVolumeSizeBytes, splitBytes > 0 {
                    try Self.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
                }
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "Archive created", throughputMBs: throughput))
                return
            }
        }
        
        // Fallback writer
        let monitorBox = StateBoxBool(true)
        let monitorTask = Task {
            let start = Date()
            while monitorBox.value {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard monitorBox.value else { break }
                if let attrs = try? FileManager.default.attributesOfItem(atPath: outputPath),
                   let writtenBytes = attrs[.size] as? Int64, writtenBytes > 0 {
                    let elapsed = max(0.05, Date().timeIntervalSince(start))
                    let throughput = (Double(writtenBytes) / (1024 * 1024)) / elapsed
                    let pct = min(0.95, Double(writtenBytes) / Double(max(1, totalBytes)))
                    progressHandler?(ArchiveProgress(
                        state: .processing,
                        bytesProcessed: min(totalBytes, Int64(Double(totalBytes) * pct)),
                        totalBytes: totalBytes,
                        currentFileName: (inputPaths.first as NSString?)?.lastPathComponent ?? "",
                        throughputMBs: throughput
                    ))
                }
            }
        }
        
        let windowLog = advancedOptions.zstdEnableLDM ? hardwareTuner.optimalZstdLongWindowLog : 0
        let effectiveLvl = level.rawValue != 0 ? level.rawValue : advancedOptions.zstdLevel
        let status = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
            ttzip_create_archive_tuned(
                outputPath,
                format.rawValue,
                cInputPaths,
                inputPaths.count,
                options.skipMacJunk,
                Int32(effectiveLvl),
                Int32(windowLog),
                Int32(advancedOptions.cpuThreads),
                password
            )
        }
        
        monitorBox.value = false
        monitorTask.cancel()
        
        if status != 0 {
            throw ArchiveError.readFailed(code: status)
        }
        
        if let splitBytes = splitVolumeSizeBytes, splitBytes > 0 {
            try Self.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitBytes)
        }
        
        let duration = max(0.01, Date().timeIntervalSince(startTime))
        let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
        
        progressHandler?(ArchiveProgress(
            state: .completed,
            bytesProcessed: totalBytes,
            totalBytes: totalBytes,
            currentFileName: "Compression completed",
            throughputMBs: throughput
        ))
    }
}
