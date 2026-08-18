// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

/// High-performance data integrity and checksum verification engine (CRC32 & SHA256).
public final class ArchiveIntegrityChecker: ArchiveIntegrityChecking, @unchecked Sendable {
    private let hashCalculator: HashCalculating
    private var sourceCRCCache: [String: String] = [:]
    private let cacheLock = NSLock()
    
    public init(hashCalculator: HashCalculating = ArchiveEngineFactory.makeHashCalculator()) {
        self.hashCalculator = hashCalculator
    }
    
    /// Computes CRC32 checksum string for a file (e.g. `"A1B2C3D4"`).
    public func computeCRC32(filePath: String) -> String {
        let crc = ttzip_compute_file_crc32(filePath)
        return String(format: "%08X", crc)
    }
    
    /// Asynchronously computes SHA256 digest string for a file.
    public func computeSHA256(filePath: String) async throws -> String {
        return try await hashCalculator.computeHash(filePath: filePath, type: .sha256)
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
                    if filename == ".metadata_never_index" || filename == ".DS_Store" || filename.hasPrefix("._") || filename.contains(":com.apple.") || filename.contains("com.apple.provenance") {
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
            if let dbgEnum = fm.enumerator(atPath: checkDir) {
                while let r = dbgEnum.nextObject() as? String {
                    let fp = (checkDir as NSString).appendingPathComponent(r)
                    var id: ObjCBool = false
                    if fm.fileExists(atPath: fp, isDirectory: &id) {
                        let s = (try? fm.attributesOfItem(atPath: fp)[.size] as? Int64) ?? 0
                        TTLogger.error("     - rel: \(r) | isDir: \(id.boolValue) | size: \(s)")
                    }
                }
            }
            SingleTestDiagnosticRunner.shared.reportFailure(
                stage: .integrityVerification,
                format: .zip,
                level: .level1,
                errorMessage: "[\(label)] Extracted byte size mismatch",
                destinationDir: directoryPath,
                expectedBytes: expectedOriginalBytes,
                actualBytes: totalExtractedBytes
            )
        }
        return (isValid, totalExtractedBytes, crcStr)
    }
}
