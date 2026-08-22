// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Unified error taxonomy for archive operations across all formats.
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
        return localizedDescription()
    }
}

private final class EntryAccumulator {
    var entries: [ArchiveEntry] = []
}

/// High-performance stream-based archive reader (100% in-process C binding).
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
    
    /// Asynchronously inspects archive hierarchy with cooperative Swift 6 Task cancellation support.
    public func inspect(archivePath: String) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: nil)
    }
    
    public func inspect(archivePath: String, password: String?, candidatePasswords: [String]? = nil) async throws -> [ArchiveEntry] {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: archivePath),
              let fileSize = attrs[.size] as? Int64 else {
            throw ArchiveError.fileNotFound
        }
        
        // Zero-byte empty file returns empty list directly
        if fileSize == 0 {
            return []
        }
        
        try Task.checkCancellation()
        
        return try await Task.detached(priority: .userInitiated) {
            let lower = archivePath.lowercased()
            
            // Handle split multi-volume archives (.001)
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
                            let rustStatus = ttzip_rust_inspect_archive(pathPtr, pwdPtr, true, { entryPtr, ctx in
                                guard let entryPtr = entryPtr, let ctx = ctx else { return false }
                                let acc = Unmanaged<EntryAccumulator>.fromOpaque(ctx).takeUnretainedValue()
                                let meta = entryPtr.pointee
                                guard let cPathname = meta.path else { return true }
                                let rawLen = strlen(cPathname)
                                let pathData = Data(bytes: cPathname, count: rawLen)
                                let sanitizedPath = CharsetDetector.sanitizeFilename(bytes: pathData)
                                let detectedCharset = CharsetDetector.detectCharset(data: pathData)
                                let lastComp = (sanitizedPath as NSString).lastPathComponent
                                if lastComp.hasPrefix("._") || lastComp == ".DS_Store" || sanitizedPath.hasPrefix("PaxHeader") || sanitizedPath.contains("/PaxHeader") {
                                    return true
                                }
                                let entry = ArchiveEntry(
                                    path: sanitizedPath,
                                    uncompressedSize: Int64(meta.uncompressed_size),
                                    isDirectory: meta.is_directory,
                                    detectedEncoding: detectedCharset,
                                    isEncrypted: meta.is_encrypted,
                                    isDataEncrypted: meta.is_encrypted,
                                    isMetadataEncrypted: false
                                )
                                acc.entries.append(entry)
                                return true
                            }, contextPtr)
                            return (rustStatus == TTZIP_STATUS_OK) ? Int32(0) : Int32(-1)
                        }
                    }
                }
                if status == 0 && !accumulator.entries.isEmpty {
                    return accumulator.entries
                }
                
                // 1. Fast CLI listing probing via 7z -slt
                if let bin7z = SevenZipBinaryResolver.resolveBinaryPath() {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: bin7z)
                    var args = ["l", "-slt"]
                    if let p = pwd, !p.isEmpty {
                        args.append("-p\(p)")
                    } else {
                        args.append("-p-")
                    }
                    args.append(archivePath)
                    proc.arguments = args
                    let pipe = Pipe()
                    proc.standardInput = FileHandle.nullDevice
                    proc.standardOutput = pipe
                    proc.standardError = FileHandle.nullDevice
                    if (try? proc.run()) != nil {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        proc.waitUntilExit()
                        if proc.terminationStatus == 0, let text = String(data: data, encoding: .utf8) {
                            var parsedEntries: [ArchiveEntry] = []
                            let baseName = URL(fileURLWithPath: archivePath).lastPathComponent
                            let blocks = text.components(separatedBy: "\n\n")
                            for block in blocks {
                                var currPath: String? = nil
                                var currSize: Int64 = 0
                                var currIsDir = false
                                var currEnc = (pwd != nil)
                                for line in block.components(separatedBy: .newlines) {
                                    if line.hasPrefix("Path = ") {
                                        currPath = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    } else if line.hasPrefix("Size = ") {
                                        currSize = Int64(line.dropFirst(7).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                                    } else if line.hasPrefix("Attributes = ") {
                                        if line.contains("D") { currIsDir = true }
                                    } else if line.hasPrefix("Encrypted = +") {
                                        currEnc = true
                                    }
                                }
                                if let p = currPath, !p.isEmpty, p != archivePath, p != targetInspectPath, p != baseName, !p.hasSuffix(".7z"), !p.hasSuffix(".001") {
                                    let lastComp = (p as NSString).lastPathComponent
                                    if !lastComp.hasPrefix("._") && lastComp != ".DS_Store" {
                                        parsedEntries.append(ArchiveEntry(
                                            path: p,
                                            uncompressedSize: currSize,
                                            isDirectory: currIsDir,
                                            detectedEncoding: "UTF-8",
                                            isEncrypted: currEnc,
                                            isDataEncrypted: currEnc,
                                            isMetadataEncrypted: currEnc
                                        ))
                                    }
                                }
                            }
                            if !parsedEntries.isEmpty {
                                return parsedEntries
                            }
                        }
                    }
                }
                
                // 2. Sandboxed probing fallback
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("inspect_temp_\(UUID().uuidString)").path
                try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(atPath: tempDir) }
                
                var success = (try? SevenZipCAdapter.shared.extractArchive(archivePath: targetInspectPath, destinationDir: tempDir, skipMacJunk: true, password: pwd)) ?? false
                if !success {
                    let res = CUnsafeBufferAdapter.withCString(targetInspectPath) { cPath in
                        CUnsafeBufferAdapter.withCString(tempDir) { cDest in
                            CUnsafeBufferAdapter.withCString(pwd) { cPwd in
                                guard let cPath = cPath, let cDest = cDest else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                                var opt = TTZipExtractOptions(
                                    destination_path: cDest,
                                    password: cPwd,
                                    thread_budget: 1,
                                    overwrite_existing: true,
                                    preserve_permissions: true,
                                    dry_run: false,
                                    progress_callback: nil,
                                    user_data: nil
                                )
                                return ttzip_rust_extract_archive(cPath, cDest, &opt)
                            }
                        }
                    }
                    success = (res == TTZIP_STATUS_OK)
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
            
            if (lower.hasSuffix(".7z") || lower.hasSuffix(".7z.001")), password == nil || password?.isEmpty == true {
                if let fastEntries = NativeSevenZipEngine.shared.inspectSevenZip(archivePath: targetInspectPath), !fastEntries.isEmpty {
                    return fastEntries
                }
            }
            
            if let entries = performCInspect(password) {
                return entries
            }
            
            // Try password candidate pool
            let candidates = candidatePasswords ?? (PasswordVaultManager.shared.autoUnlockArchives ? PasswordVaultManager.shared.candidatePasswordsForAutoUnlock() : [])
            if password == nil || password?.isEmpty == true {
                for cand in candidates {
                    if let vaultEntries = performCInspect(cand) {
                        return vaultEntries
                    }
                }
            }
            
            // Password required error
            if (lower.contains(".7z") || lower.contains(".zip") || lower.contains(".rar")) && (password == nil || password?.isEmpty == true) {
                throw ArchiveError.passwordRequired
            }
            
            throw ArchiveError.readFailed(code: -1)
        }.value
    }
    
    /// Inspects archive and builds a unified hierarchical VFS tree.
    public func inspectTree(archivePath: String, password: String? = nil) async throws -> ArchiveCompositeDirectory {
        let entries = try await inspect(archivePath: archivePath, password: password)
        return ArchiveComponentTreeBuilder.buildTree(from: entries)
    }
    
    /// Performs fuzzy search on the archive contents using Safe Rust VFS engine.
    public func fuzzySearch(archivePath: String, query: String, password: String? = nil) async throws -> [ArchiveEntry] {
        let entries = try await inspect(archivePath: archivePath, password: password)
        return RustVfsBridge.fuzzySearch(in: entries, query: query)
    }
}

