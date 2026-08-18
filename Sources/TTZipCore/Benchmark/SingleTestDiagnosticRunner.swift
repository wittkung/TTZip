// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Diagnostic failure stages for single format testing.
public enum DiagnosticFailureStage: String, Sendable {
    case datasetPreparation = "STAGE 1 - Dataset Generation"
    case compressionExecution = "STAGE 2 - Compression Execution"
    case archiveValidation = "STAGE 3 - Archive File Validation"
    case extractionExecution = "STAGE 4 - Extraction Decompression"
    case integrityVerification = "STAGE 5 - Byte & Hash Integrity Audit"
}

/// Single test diagnostic execution and root-cause diagnostic logger.
public final class SingleTestDiagnosticRunner: @unchecked Sendable {
    public static let shared = SingleTestDiagnosticRunner()
    
    private init() {}
    
    /// Logs single test initialization banner.
    public func logBanner(
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String? = nil,
        sandboxPath: String
    ) {
        let isEnc = (password != nil && !password!.isEmpty)
        let encDesc = isEnc ? "AES-256 Encryption (Password: \(password!))" : "Unencrypted"
        TTLogger.info("\n====================================================================================================")
        TTLogger.info("🔬 [TTZip Single Format Diagnostic] Target: \(format.rawValue.uppercased()) (\(format.fileExtension)) | Level: \(level.title) (\(level.rawValue))")
        TTLogger.info("⚙️ Parameters: \(encDesc) | Split: \(format.supportsSplitVolume) | Platform: macOS arm64e")
        TTLogger.info("📁 Sandbox: \(sandboxPath)")
        TTLogger.info("====================================================================================================")
    }
    
    /// Logs structured diagnostic failure report with actionable troubleshooting hints.
    public func reportFailure(
        stage: DiagnosticFailureStage,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String? = nil,
        error: Error? = nil,
        errorMessage: String,
        archivePath: String? = nil,
        destinationDir: String? = nil,
        expectedBytes: Int64? = nil,
        actualBytes: Int64? = nil,
        sandboxPath: String? = nil
    ) {
        let isEnc = (password != nil && !password!.isEmpty)
        let encDesc = isEnc ? "AES-256 Password Encryption (Password: \(password!))" : "Unencrypted"
        
        TTLogger.error("\n====================================================================================================")
        TTLogger.error("🚨 [DIAGNOSTIC FAILURE REPORT]")
        TTLogger.error("====================================================================================================")
        TTLogger.error("📌 Failure Stage: \(stage.rawValue)")
        TTLogger.error("📦 Target Format: \(format.rawValue.uppercased()) (\(format.fileExtension))")
        TTLogger.error("⚙️ Parameters: \(level.title) (Level \(level.rawValue)) | \(encDesc)")
        if let s = sandboxPath { TTLogger.error("📁 Sandbox: \(s)") }
        if let a = archivePath {
            let sz = (try? FileManager.default.attributesOfItem(atPath: a)[.size] as? Int64) ?? 0
            TTLogger.error("📄 Archive Path: \(a) (Size: \(sz) bytes)")
        }
        if let d = destinationDir { TTLogger.error("📂 Destination: \(d)") }
        
        TTLogger.error("\n----------------------------------------------------------------------------------------------------")
        TTLogger.error("🔍 Diagnostics:")
        TTLogger.error("  - Description: \(errorMessage)")
        if let err = error {
            TTLogger.error("  - Caught Exception: \(err.localizedDescription) (\(err))")
        }
        if let exp = expectedBytes, let act = actualBytes {
            let diff = act - exp
            let diffStr = diff > 0 ? "+\(diff) bytes (residual uncleaned files)" : "\(diff) bytes (data loss/incomplete extraction)"
            TTLogger.error("  - Byte Comparison: Expected \(exp) bytes vs Actual \(act) bytes | Delta: \(diffStr)")
        }
        
        TTLogger.error("\n💡 Root Cause Diagnostic Hints:")
        let hints = generateDiagnosticHints(stage: stage, format: format, errorMessage: errorMessage, archivePath: archivePath, destinationDir: destinationDir)
        for (idx, hint) in hints.enumerated() {
            TTLogger.error("  \(idx + 1). \(hint)")
        }
        TTLogger.error("====================================================================================================\n")
    }
    
    private func generateDiagnosticHints(
        stage: DiagnosticFailureStage,
        format: ArchiveCompressionFormat,
        errorMessage: String,
        archivePath: String?,
        destinationDir: String?
    ) -> [String] {
        var hints: [String] = []
        
        switch stage {
        case .datasetPreparation:
            hints.append("Verify disk space and temporary directory read/write permissions.")
            hints.append("Check FileHandle write operations for I/O errors.")
            
        case .compressionExecution:
            if format == .zip {
                hints.append("Inspect CTTZipBridge (libdeflate / WinZip AES-256) C layer function pointers and CStruct initialization.")
                hints.append("Verify POSIX path escaping and multi-threaded write synchronization.")
            } else if format == .sevenZip {
                hints.append("Verify 7zz executable resolution in bundle or system PATH.")
                hints.append("Confirm CTTZipBridge_7z.c working_dir and relative paths.")
            } else if format == .zst || format == .tarZst {
                hints.append("Inspect NativeZstdEngine libzstd C API calls (zstdContext / zstdCompressBound).")
            } else {
                hints.append("Verify tar binary path resolution and posix_spawn arguments.")
            }
            
        case .archiveValidation:
            hints.append("Archive size is 0 bytes, indicating no stream data was written.")
            hints.append("Verify input file enumeration in compression pipeline.")
            
        case .extractionExecution:
            if errorMessage.contains("TTZIP_ERR_INVALID_PASSWORD") || errorMessage.contains("password") {
                hints.append("Password validation failed: verify PBKDF2-SHA1 2-byte verification and WinZip Extra Field 0x9901.")
            } else if errorMessage.contains("chdir") || errorMessage.contains("No such file") {
                hints.append("Destination directory missing: verify ttzip_common_mkdir_p(dest) invocation prior to extraction.")
            } else {
                hints.append("Inspect ArchiveExtractor dispatch logic for format.")
            }
            
        case .integrityVerification:
            hints.append("Extracted size > expected: check for uncleaned intermediate tar archives.")
            hints.append("Extracted size < expected: check filter rules or hidden file skipping.")
            hints.append("CRC32 mismatch: check stream truncation or concurrent buffer synchronization.")
        }
        
        return hints
    }
}
