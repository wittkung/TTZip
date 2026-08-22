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

/// High-performance stream-based archive reader (Ultra-Thin Rust C-ABI Facade).
public final class ArchiveReader: ArchiveReading, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(
        hardwareTuner: HardwareTunerProtocol = AppleSiliconTuner.shared,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }
    
    /// Asynchronously inspects archive hierarchy with cooperative Swift 6 Task cancellation support.
    public func inspect(archivePath: String) async throws -> [ArchiveEntry] {
        let vaultPasswords = PasswordVaultManager.shared.candidatePasswordsForAutoUnlock()
        return try await inspect(archivePath: archivePath, password: nil, candidatePasswords: vaultPasswords)
    }

    /// Convenience facade method to list entries of an archive.
    @inline(__always)
    public func listEntries(archivePath: String, password: String? = nil) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
    }
    
    public func inspect(
        archivePath: String,
        password: String?,
        candidatePasswords: [String]? = nil
    ) async throws -> [ArchiveEntry] {
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
            
            let performInspect: (String?) -> [ArchiveEntry]? = { pwd in
                let accumulator = EntryAccumulator()
                let contextPtr = Unmanaged.passUnretained(accumulator).toOpaque()
                
                let status = withExtendedLifetime(accumulator) {
                    CUnsafeBufferAdapter.withCString(targetInspectPath) { pathPtr in
                        CUnsafeBufferAdapter.withCString(pwd) { pwdPtr in
                            guard let pathPtr = pathPtr else { return Int32(-1) }
                            let rustStatus = ttzip_rust_archive_inspect_unified(pathPtr, pwdPtr, true, { entryPtr, ctx in
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
                if lower.contains(".7z") || lower.contains(".001") {
                    if let cliEntries = Self.inspectWith7zCLI(archivePath: targetInspectPath, password: pwd) {
                        return cliEntries
                    }
                }
                return nil
            }
            
            if let entries = performInspect(password) {
                return entries
            }
            
            let candidates = candidatePasswords ?? PasswordVaultManager.shared.candidatePasswordsForAutoUnlock()
            if (password == nil || password?.isEmpty == true) && !candidates.isEmpty {
                for cand in candidates {
                    if let candEntries = performInspect(cand) {
                        return candEntries
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
    public func inspectTree(
        archivePath: String,
        password: String? = nil,
        candidatePasswords: [String]? = nil
    ) async throws -> ArchiveCompositeDirectory {
        let entries = try await inspect(archivePath: archivePath, password: password, candidatePasswords: candidatePasswords)
        return ArchiveComponentTreeBuilder.buildTree(from: entries)
    }

    /// Fast zero-decompression probe of archive encryption tier.
    public func probeEncryption(archivePath: String) async throws -> ArchiveEncryptionTier {
        let entries = try? await inspect(archivePath: archivePath, password: nil, candidatePasswords: nil)
        guard let entries = entries else { return .headerAndData }
        if entries.isEmpty { return .none }
        if entries.contains(where: { $0.isEncrypted }) {
            return .dataOnly
        }
        return .none
    }
    
    /// Asynchronously renders ASCII/Unicode hierarchical tree directly using the Safe Rust VFS engine.
    public func renderTree(archivePath: String, password: String? = nil) async throws -> String {
        let entries = try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
        let rootName = (archivePath as NSString).lastPathComponent
        return RustVfsBridge.renderTree(from: entries, rootName: rootName)
    }

    /// Performs fuzzy search on the archive contents using Safe Rust VFS engine.
    public func fuzzySearch(archivePath: String, query: String, password: String? = nil) async throws -> [ArchiveEntry] {
        let entries = try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
        return RustVfsBridge.fuzzySearch(in: entries, query: query)
    }

    internal static func inspectWith7zCLI(archivePath: String, password: String?) -> [ArchiveEntry]? {
        guard let bin7z = SevenZipBinaryResolver.resolveBinaryPath() else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin7z)
        var args = ["l", "-slt"]
        if let p = password, !p.isEmpty {
            args.append("-p\(p)")
        } else {
            args.append("-p-")
        }
        args.append(archivePath)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else { return nil }
        
        var entries: [ArchiveEntry] = []
        guard let dashRange = text.range(of: "----------\n") ?? text.range(of: "----------\r\n") else { return nil }
        let filesSection = String(text[dashRange.upperBound...])
        let rawBlocks = filesSection.components(separatedBy: "\n\n")
        
        for block in rawBlocks {
            var path: String?
            var size: Int64 = 0
            var isDir = false
            var isEnc = false
            for line in block.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = trimmed.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    let key = parts[0]
                    let val = parts[1]
                    switch key {
                    case "Path": path = val
                    case "Size": size = Int64(val) ?? 0
                    case "Folder": isDir = (val == "+")
                    case "Encrypted": isEnc = (val == "+")
                    default: break
                    }
                }
            }
            if let p = path, !p.isEmpty {
                let lastComp = (p as NSString).lastPathComponent
                if !lastComp.hasPrefix("._") && lastComp != ".DS_Store" {
                    entries.append(ArchiveEntry(
                        path: p,
                        uncompressedSize: size,
                        isDirectory: isDir,
                        detectedEncoding: "UTF-8",
                        isEncrypted: isEnc,
                        isDataEncrypted: isEnc,
                        isMetadataEncrypted: isEnc
                    ))
                }
            }
        }
        return entries.isEmpty ? nil : entries
    }
}
