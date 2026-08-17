import Foundation
import CTTZipBridge

public enum ArchiveError: Error, LocalizedError, Equatable {
    case fileNotFound
    case readFailed(code: Int32)
    case invalidFormat
    case passwordRequired
    case passwordRequiredDetailed(archivePath: String, tier: ArchiveEncryptionTier)
    case wrongPassword(archivePath: String)
    case unsupportedEncryptionMethod(archivePath: String, method: String)
    case corruptedData(archivePath: String, entryPath: String)
    case cancelled
    case invalidState
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "指定归档文件路径不存在"
        case .readFailed(let code):
            return "读取归档失败，错误代码: \(code)"
        case .invalidFormat:
            return "无法识别的归档格式"
        case .passwordRequired:
            return "归档已被加密，请输入解压密码"
        case .passwordRequiredDetailed(_, let tier):
            return tier == .headerAndData ? "归档头部与文件名已被加密，请输入解压密码以浏览内容" : "归档数据已被加密，请输入解压密码"
        case .wrongPassword:
            return "解压密码错误，请重新输入"
        case .unsupportedEncryptionMethod(_, let method):
            return "当前系统暂不支持该加密算法: \(method)"
        case .corruptedData(_, let entryPath):
            return "条目校验失败或数据已损坏: \(entryPath)"
        case .cancelled:
            return "归档操作已被取消"
        case .invalidState:
            return "归档任务状态非法或拒绝转移"
        }
    }
}

private final class EntryAccumulator {
    var entries: [ArchiveEntry] = []
}

/// 高性能流式归档文件读取引擎 (100% 进程内纯原生 C 驱动，零 Subprocess)
public final class ArchiveReader: ArchiveReading, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(
        hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }
    
    /// 异步检查并读取归档文件的目录结构列表 (支持 Swift 6 Task 取消感知与加密密码解析)
    public func inspect(archivePath: String) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: nil)
    }
    
    public func inspect(archivePath: String, password: String?, candidatePasswords: [String]? = nil) async throws -> [ArchiveEntry] {
        var fileSize: Int64 = 0
        guard ttzip_stat_file_info(archivePath, &fileSize, nil, nil) == 0 else {
            throw ArchiveError.fileNotFound
        }
        
        // 0 字节空文件直接返回空条目
        if fileSize == 0 {
            return []
        }
        
        try Task.checkCancellation()
        
        return try await Task.detached(priority: .userInitiated) {
            let lower = archivePath.lowercased()
            
            // 针对分卷 .001 处理
            var targetInspectPath = archivePath
            var cleanupTempPath: String? = nil
            if lower.hasSuffix(".001") {
                let ext = lower.contains(".7z") ? "7z" : (lower.contains(".zip") ? "zip" : "tmp")
                let joinedTemp = FileManager.default.temporaryDirectory.appendingPathComponent("joined_inspect_\(UUID().uuidString).\(ext)").path
                if ArchiveExtractor().joinSplitVolumes(firstVolumePath: archivePath, outputPath: joinedTemp) {
                    targetInspectPath = joinedTemp
                    cleanupTempPath = joinedTemp
                }
            }
            defer {
                if let tmp = cleanupTempPath {
                    try? FileManager.default.removeItem(atPath: tmp)
                }
            }
            
            let performCInspect: (String?) -> [ArchiveEntry]? = { pwd in
                let accumulator = EntryAccumulator()
                let contextPtr = Unmanaged.passUnretained(accumulator).toOpaque()
                
                let status = withExtendedLifetime(accumulator) {
                    CUnsafeBufferAdapter.withCString(targetInspectPath) { pathPtr in
                        CUnsafeBufferAdapter.withCString(pwd) { pwdPtr in
                            guard let pathPtr = pathPtr else { return Int32(-1) }
                            return ttzip_inspect_archive_v2(pathPtr, pwdPtr, contextPtr) { ctx, cPathname, size, isDir, isDataEnc, isMetaEnc in
                                guard let ctx = ctx, let cPathname = cPathname else { return }
                                let acc = Unmanaged<EntryAccumulator>.fromOpaque(ctx).takeUnretainedValue()
                                let rawLen = strlen(cPathname)
                                let pathData = Data(bytes: cPathname, count: rawLen)
                                let sanitizedPath = CharsetDetector.sanitizeFilename(bytes: pathData)
                                let detectedCharset = CharsetDetector.detectCharset(data: pathData)
                                let lastComp = (sanitizedPath as NSString).lastPathComponent
                                if lastComp.hasPrefix("._") || lastComp == ".DS_Store" || sanitizedPath.hasPrefix("PaxHeader") || sanitizedPath.contains("/PaxHeader") {
                                    return
                                }
                                let entry = ArchiveEntry(
                                    path: sanitizedPath,
                                    uncompressedSize: size,
                                    isDirectory: isDir,
                                    detectedEncoding: detectedCharset,
                                    isEncrypted: isDataEnc || isMetaEnc,
                                    isDataEncrypted: isDataEnc,
                                    isMetadataEncrypted: isMetaEnc
                                )
                                acc.entries.append(entry)
                            }
                        }
                    }
                }
                if status == 0 && !accumulator.entries.isEmpty {
                    return accumulator.entries
                }
                
                // 若为 7z 或带密码加密包，尝试利用进程内 C 提取引擎沙盒探测
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("inspect_temp_\(UUID().uuidString)").path
                try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(atPath: tempDir) }
                
                var success = (try? SevenZipCAdapter.shared.extractArchive(archivePath: targetInspectPath, destinationDir: tempDir, skipMacJunk: true, password: pwd)) ?? false
                if !success {
                    success = (ttzip_extract_archive_advanced(targetInspectPath, tempDir, true, pwd) == 0)
                }
                TTLogger.debug("[Inspect] in-process extraction success=\(success), tempDir=\(tempDir)")
                if success {
                    let fm = FileManager.default
                    let subpaths = try? fm.subpathsOfDirectory(atPath: tempDir)
                    TTLogger.debug("[Inspect] subpaths count: \(subpaths?.count ?? 0), items: \(subpaths ?? [])")
                    if let subpaths = subpaths, !subpaths.isEmpty {
                        let entries = subpaths.compactMap { relPath -> ArchiveEntry? in
                            let fullP = (tempDir as NSString).appendingPathComponent(relPath)
                            var isD: ObjCBool = false
                            guard fm.fileExists(atPath: fullP, isDirectory: &isD) else { return nil }
                            let attrs = (try? fm.attributesOfItem(atPath: fullP)) ?? [:]
                            let sz = (attrs[.size] as? Int64) ?? 0
                            return ArchiveEntry(
                                path: relPath,
                                uncompressedSize: sz,
                                isDirectory: isD.boolValue,
                                detectedEncoding: "UTF-8",
                                isEncrypted: pwd != nil,
                                isDataEncrypted: pwd != nil,
                                isMetadataEncrypted: pwd != nil
                            )
                        }
                        TTLogger.debug("[Inspect] returning entries: \(entries.count)")
                        return entries
                    }
                }
                return nil
            }
            
            if (lower.hasSuffix(".zip") || lower.hasSuffix(".jar") || lower.hasSuffix(".apk") || lower.hasSuffix(".epub") || lower.hasSuffix(".docx") || lower.hasSuffix(".xlsx")),
               password == nil || password?.isEmpty == true {
                if let fastEntries = performCInspect(nil), !fastEntries.isEmpty {
                    return fastEntries
                }
                if let fastEntries = NativeZipEngine.shared.inspectZip(archivePath: targetInspectPath) {
                    return fastEntries
                }
            }
            
            if lower.hasSuffix(".aar") {
                if let aarEntries = try? NativeAppleArchiveEngine.shared.inspect(archivePath: targetInspectPath), !aarEntries.isEmpty {
                    return aarEntries
                }
            }
            
            if let entries = performCInspect(password) {
                return entries
            }
            
            // 尝试密码库口令池
            let candidates = candidatePasswords ?? (PasswordVaultManager.shared.autoUnlockArchives ? PasswordVaultManager.shared.candidatePasswordsForAutoUnlock() : [])
            if password == nil || password?.isEmpty == true {
                for cand in candidates {
                    if let vaultEntries = performCInspect(cand) {
                        return vaultEntries
                    }
                }
            }
            
            // 若 7z 或 zip 加密包且无密码或密码错误
            if (lower.contains(".7z") || lower.contains(".zip") || lower.contains(".rar")) && (password == nil || password?.isEmpty == true) {
                throw ArchiveError.passwordRequired
            }
            
            throw ArchiveError.readFailed(code: -1)
        }.value
    }
}
