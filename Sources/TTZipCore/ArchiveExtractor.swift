import Foundation
import CTTZipBridge

/// 高性能流式归档解压引擎
public final class ArchiveExtractor: ArchiveExtracting, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner, targetFormat: ArchiveCompressionFormat? = nil) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }

    /// 同步将归档文件解压缩至指定目标文件夹 (零 Swift Task 分发开销)
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

    /// 异步将归档文件解压缩至指定目标文件夹
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
        
        // 针对分卷 7z 压缩包直通处理
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
        
        // 针对 7z / DMG / ISO 格式极速原生 C 语言并发解压引擎
        if pathLower.contains(".7z") || pathLower.contains("sevenzip") || pathLower.hasSuffix(".cb7") || pathLower.hasSuffix(".dmg") || pathLower.hasSuffix(".iso") {
            let candidates: [String?] = passCandidates.isEmpty ? [password] : passCandidates.map { Optional($0) }
            for cand in candidates {
                if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: cand), ok {
                    if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
                        return
                    }
                }
            }
        }
        
        // 针对 ZIP 格式原生 C 极速 GCD 16 核并发解压引擎 (含 WinZip AES-256 解密)
        if pathLower.hasSuffix(".zip") || pathLower.contains(".zip") {
            let activePwd = password ?? passCandidates.first
            if ttzip_extract_zip_c_parallel(archivePath, destinationDir, options.skipMacJunk, activePwd) == 0 {
                return
            }
        }
        
        let fileManager = FileManager.default
        guard ttzip_stat_file_info(archivePath, nil, nil, nil) == 0 else {
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
                if let self = self, self.dispatchFastExtraction(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    options: options,
                    password: cand,
                    advancedOptions: advancedOptions
                ) {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return
                }
                
                let status = ttzip_extract_archive_advanced(archivePath, destinationDir, options.skipMacJunk, cand)
                if status == 0 {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return
                }
                lastStatus = status
            }
            throw ArchiveError.readFailed(code: lastStatus)
        }
        
        try await Task.detached(priority: .userInitiated) {
            try performExtraction()
        }.value
    }
    
    /// 从归档文件中精确提解单个指定文件 (100% 进程内纯原生 C / 系统引擎)
    public func extractSingleFile(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        if !fileManager.fileExists(atPath: destinationDir) {
            try fileManager.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }
        
        try await Task.detached(priority: .userInitiated) {
            let pathLower = archivePath.lowercased()
            if pathLower.contains(".7z") || pathLower.contains("sevenzip") || pathLower.hasSuffix(".cb7") {
                if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: password), ok {
                    return
                }
            } else if pathLower.hasSuffix(".zip") {
                if ttzip_extract_zip_c_parallel(archivePath, destinationDir, false, password) == 0 {
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

    // MARK: - 辅助方法
    
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
        let fm = FileManager.default
        guard firstVolumePath.hasSuffix(".001") else { return false }
        let basePath = String(firstVolumePath.dropLast(4))
        
        fm.createFile(atPath: outputPath, contents: nil)
        let outFd = open(outputPath, O_WRONLY | O_TRUNC, 0644)
        guard outFd >= 0 else { return false }
        defer { close(outFd) }
        
        var idx = 1
        return MemoryPageFlyweightPool.shared.withBuffer(size: .page64K) { ptr, capacity in
            while true {
                let partPath = String(format: "%@.%03d", basePath, idx)
                guard fm.fileExists(atPath: partPath) else { break }
                let inFd = open(partPath, O_RDONLY)
                guard inFd >= 0 else { break }
                
                while true {
                    let bytesRead = read(inFd, ptr, capacity)
                    if bytesRead <= 0 { break }
                    _ = write(outFd, ptr, bytesRead)
                }
                close(inFd)
                idx += 1
            }
            return idx > 1
        }
    }

    /// 【3.6 模板方法模式 (Template Method Pattern)】使用算法骨架进行流式解压
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
