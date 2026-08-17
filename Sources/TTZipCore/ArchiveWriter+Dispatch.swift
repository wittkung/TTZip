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

    /// 同步创建归档内部方法
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
            
        // 1. 7z 快速路径 (无分卷切片时优先调度)
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
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "7z 极速打包完成", progressHandler: progressHandler)
                return
            }
        }
            
        // 1. 原生 Level 0 Store 直通模式 (16MB SIMD 页对齐 Direct I/O 零拷贝，打满 SSD/RAM 总线)
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
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "原生 Store 零拷贝直通打包完成", progressHandler: progressHandler)
                return
            }
        }
        
        // 2. 原生 ZIP 打包压缩引擎 (libdeflate + mmap + NEON CRC32 + 多核并发)
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
                notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "原生 C 极速 ZIP 打包完成", progressHandler: progressHandler)
                return
            }
        }
        
        // 2. 原生 ZST 流引擎 (RFC 8878 libzstd 硬件帧流)
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
                    notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "原生 ZST 压缩完成", progressHandler: progressHandler)
                    return
                }
            }
        }

        // 4. 原生 C 内存层直通引擎 (针对 <50MB 小容量 TAR 归档包)
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
                    currentFileName: "原生 C 语言极速归档完成",
                    throughputMBs: throughput
                ))
                return
            }
        }
        
        // 3. 针对 7z / zip 分卷切割模式 (100% 进程内纯原生打包与切片)
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
                    notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "7z 极速分卷打包完成", progressHandler: progressHandler)
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
                    notifyCompletion(totalBytes: totalBytes, startTime: startTime, message: "ZIP 极速分卷打包完成", progressHandler: progressHandler)
                    return
                }
            }
        }
        
        // 针对 特殊系统级格式直通驱动 (Apple Archive, DMG, ISO, WIM - 100% In-Process)
        if format == .aar, let firstInput = inputPaths.first {
            if let ok = try? NativeAppleArchiveEngine.shared.compress(sourcePath: firstInput, outputPath: outputPath), ok {
                let duration = max(0.001, Date().timeIntervalSince(startTime))
                let throughput = (Double(totalBytes) / (1024 * 1024)) / duration
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "Apple Archive 硬件极速打包完成", throughputMBs: throughput))
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
                let msg = format == .dmg ? "DMG 磁盘映像打包完成" : "ISO 光盘映像生成完成"
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
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "WIM 极速打包完成", throughputMBs: throughput))
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
                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: totalBytes, totalBytes: totalBytes, currentFileName: "原生 C 引擎打包完成", throughputMBs: throughput))
                return
            }
        }
        
        // 默认全能 C-Bridge 递归打包器 fallback
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
        let status = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
            ttzip_create_archive_tuned(
                outputPath,
                format.rawValue,
                cInputPaths,
                inputPaths.count,
                options.skipMacJunk,
                Int32(advancedOptions.zstdLevel),
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
            currentFileName: "压缩完成",
            throughputMBs: throughput
        ))
    }
}
