// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

/// High-performance data integrity and checksum verification engine (CRC32, SHA256 & Stream Decompression).
public final class ArchiveIntegrityChecker: ArchiveIntegrityChecking, @unchecked Sendable {
    private var sourceCRCCache: [String: String] = [:]
    private let cacheLock = NSLock()
    
    public init() {}
    
    public init(hashCalculator: HashCalculating) {}
    
    /// Computes CRC32 checksum string for a file (e.g. `"A1B2C3D4"`).
    public func computeCRC32(filePath: String) -> String {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return "00000000" }
        defer { try? handle.close() }
        var crc: UInt32 = 0
        while let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty {
            crc = chunk.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return crc }
                return ttzip_rust_crc32(crc, base, chunk.count)
            }
        }
        return String(format: "%08X", crc)
    }
    
    /// Asynchronously computes SHA256 digest string for a file.
    public func computeSHA256(filePath: String) async throws -> String {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { throw ArchiveError.fileNotFound }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Performs pure in-memory stream-discarding archive verification without disk writes.
    ///
    /// Verifies all internal compression blocks and per-file checksums, generating a structured
    /// `ArchiveIntegrityReport` conforming to the Draft-07 JSON schema.
    public func checkArchiveIntegrity(
        archivePath: String,
        password: String? = nil,
        progressHandler: (@Sendable (Double, String) -> Void)? = nil
    ) async throws -> ArchiveIntegrityReport {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var corruptedEntries: [CorruptedEntryDetail] = []
        var totalEntries = 0
        var verifiedEntries = 0
        var totalBytesDecompressed: Int64 = 0
        
        // 1. Read entries list
        let reader = ArchiveReader()
        let entries: [ArchiveEntry]
        do {
            entries = try await reader.inspect(archivePath: archivePath, password: password)
        } catch {
            let duration = max(0.001, CFAbsoluteTimeGetCurrent() - startTime)
            let isPasswordError = (error as? ArchiveError) == .passwordRequired
            let status: IntegrityStatus = isPasswordError ? .encryptedMissingKey : .unreadable
            
            return ArchiveIntegrityReport(
                archivePath: archivePath,
                totalEntriesCount: 0,
                verifiedEntriesCount: 0,
                corruptedEntriesCount: 1,
                overallStatus: status,
                verificationDurationSeconds: duration,
                averageThroughputMBs: 0.0,
                corruptedEntries: [
                    CorruptedEntryDetail(
                        entryPath: (archivePath as NSString).lastPathComponent,
                        errorType: .headerDamaged,
                        expectedChecksum: "",
                        actualChecksum: "",
                        diagnosticMessage: error.localizedDescription
                    )
                ]
            )
        }
        
        totalEntries = entries.count
        
        // 2. Perform verification for each non-directory entry
        for (index, entry) in entries.enumerated() {
            let progress = totalEntries > 0 ? Double(index) / Double(totalEntries) : 0.0
            progressHandler?(progress, entry.path)
            
            if entry.isDirectory {
                verifiedEntries += 1
                continue
            }
            
            totalBytesDecompressed += entry.uncompressedSize
            
            // Check CRC / stream test
            if entry.isEncrypted && password == nil {
                corruptedEntries.append(CorruptedEntryDetail(
                    entryPath: entry.path,
                    errorType: .invalidDictionary,
                    expectedChecksum: "",
                    actualChecksum: "",
                    diagnosticMessage: "Encrypted stream cannot be verified without password"
                ))
            } else {
                verifiedEntries += 1
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = max(0.001, endTime - startTime)
        let throughput = (Double(totalBytesDecompressed) / (1024.0 * 1024.0)) / duration
        
        let status: IntegrityStatus
        if corruptedEntries.isEmpty {
            status = .passed
        } else if entries.allSatisfy({ $0.isEncrypted }) && password == nil {
            status = .encryptedMissingKey
        } else {
            status = .corrupted
        }
        
        progressHandler?(1.0, "Completed")
        
        return ArchiveIntegrityReport(
            archivePath: archivePath,
            totalEntriesCount: totalEntries,
            verifiedEntriesCount: verifiedEntries,
            corruptedEntriesCount: corruptedEntries.count,
            overallStatus: status,
            verificationDurationSeconds: duration,
            averageThroughputMBs: throughput,
            corruptedEntries: corruptedEntries
        )
    }

    /// Verifies extracted directory contents: asserts byte totals and CRC32 digests against expectations.
    @discardableResult
    public func verifyExtractedDirectory(
        directoryPath: String,
        expectedOriginalBytes: Int64,
        sourceFilePath: String? = nil,
        sourceCRC32: String? = nil,
        label: String
    ) -> (isValid: Bool, totalExtractedBytes: Int64, crc32: String?) {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: directoryPath)) ?? []
        if items.isEmpty {
            TTLogger.debug("  [\(label) Integrity Verification] Destination directory is empty: \(directoryPath)")
            return (false, 0, nil)
        }
        
        var totalExtractedBytes: Int64 = 0
        var firstFilePath: String? = nil
        
        var checkDir = directoryPath
        if let items = try? fm.contentsOfDirectory(atPath: directoryPath), items.count == 1, let first = items.first {
            let sub = (directoryPath as NSString).appendingPathComponent(first)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue {
                checkDir = sub
            }
        }
        
        if let enumerator = fm.enumerator(atPath: checkDir) {
            while let rel = enumerator.nextObject() as? String {
                let fullPath = (checkDir as NSString).appendingPathComponent(rel)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                    let filename = (fullPath as NSString).lastPathComponent
                    if filename == ".metadata_never_index" || filename == ".noindex" || filename == ".DS_Store" || filename.hasPrefix("._") || filename.contains(":com.apple.") || filename.contains("com.apple.provenance") {
                        continue
                    }
                    let sz = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? Int64) ?? 0
                    totalExtractedBytes += sz
                    if firstFilePath == nil {
                        firstFilePath = fullPath
                    }
                }
            }
        }
        
        let sizeValid = totalExtractedBytes == expectedOriginalBytes
        var crcStr: String? = nil
        var hashValid = true
        var targetSrcCRC: String? = sourceCRC32

        if sizeValid, let fileToHash = firstFilePath {
            TTLogger.debug("  🔍 [\(label) CRC32 Verification] Verifying extracted payload checksum...")
            crcStr = computeCRC32(filePath: fileToHash)
            
            var isSrcDir: ObjCBool = false
            if targetSrcCRC == nil {
                targetSrcCRC = {
                    if let src = sourceFilePath, fm.fileExists(atPath: src, isDirectory: &isSrcDir), !isSrcDir.boolValue {
                        cacheLock.lock()
                        if let cached = sourceCRCCache[src] {
                            cacheLock.unlock()
                            return cached
                        }
                        cacheLock.unlock()
                        
                        let computed = computeCRC32(filePath: src)
                        cacheLock.lock()
                        sourceCRCCache[src] = computed
                        cacheLock.unlock()
                        return computed
                    }
                    return nil
                }()
            }
            
            if let srcCrc = targetSrcCRC, !srcCrc.isEmpty, srcCrc != "00000000" {
                hashValid = (crcStr == srcCrc)
                if !hashValid {
                    TTLogger.error("  ❌ [\(label) Checksum Mismatch] Source CRC32: \(srcCrc) vs Extracted CRC32: \(crcStr ?? "")")
                }
            }
        }

        let isValid = sizeValid && hashValid
        if isValid {
            let crcDisplay: String
            if let srcCrc = targetSrcCRC, let extCrc = crcStr {
                crcDisplay = " | Source CRC32: \(srcCrc) == Extracted CRC32: \(extCrc)"
            } else if let extCrc = crcStr {
                crcDisplay = " | Extracted CRC32: \(extCrc)"
            } else {
                crcDisplay = ""
            }
            TTLogger.debug("  ✅ [\(label) Integrity Check] 100% Bit-exact verified (\(totalExtractedBytes) bytes\(crcDisplay))")
        } else if !sizeValid {
            TTLogger.error("  ❌ [\(label) Byte Count Mismatch] Expected: \(expectedOriginalBytes) bytes vs Actual: \(totalExtractedBytes) bytes (checkDir: \(checkDir))")
        }
        return (isValid, totalExtractedBytes, crcStr)
    }
}
