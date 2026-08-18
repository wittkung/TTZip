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
        switch self {
        case .fileNotFound:
            return "Archive file not found at specified path"
        case .readFailed(let code):
            return "Failed to read archive header or entries (code: \(code))"
        case .invalidFormat:
            return "Unrecognized or invalid archive format"
        case .passwordRequired:
            return "Archive is password-protected. Please enter password"
        case .passwordRequiredDetailed(_, let tier):
            return tier == .headerAndData
                ? "Archive header and entries are encrypted. Password required to list contents"
                : "Archive payload data is encrypted. Password required to extract"
        case .wrongPassword:
            return "Incorrect password for archive"
        case .unsupportedEncryptionMethod(_, let method):
            return "Unsupported cryptographic algorithm or encryption method: \(method)"
        case .corruptedData(_, let entryPath):
            return "Data corruption or checksum mismatch detected in entry: \(entryPath)"
        case .cancelled:
            return "Archive operation was cancelled by user"
        case .invalidState:
            return "Archive engine task entered an invalid state"
        }
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
        var fileSize: Int64 = 0
        guard ttzip_stat_file_info(archivePath, &fileSize, nil, nil) == 0 else {
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
                
                // For encrypted archives or complex 7z containers, fallback to sandboxed probing
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("inspect_temp_\(UUID().uuidString)").path
                try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(atPath: tempDir) }
                
                var success = (try? SevenZipCAdapter.shared.extractArchive(archivePath: targetInspectPath, destinationDir: tempDir, skipMacJunk: true, password: pwd)) ?? false
                if !success {
                    success = (ttzip_extract_archive_advanced(targetInspectPath, tempDir, true, pwd) == 0)
                }
                if !success, let bin7z = SevenZipBinaryResolver.resolveBinaryPath() {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: bin7z)
                    var args = ["x", "-y", "-o\(tempDir)", targetInspectPath]
                    if let p = pwd, !p.isEmpty {
                        args.append("-p\(p)")
                    } else {
                        args.append("-p-")
                    }
                    proc.arguments = args
                    proc.standardOutput = Pipe()
                    proc.standardError = Pipe()
                    if (try? proc.run()) != nil {
                        proc.waitUntilExit()
                        success = (proc.terminationStatus == 0)
                    }
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
}
