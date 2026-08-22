// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public enum DiagnosticStage: String, Sendable {
    case initialization = "STAGE_1_INIT"
    case datasetGeneration = "STAGE_2_DATASET"
    case compressionExecution = "STAGE_3_COMPRESS"
    case archiveValidation = "STAGE_4_ARCHIVE_VALIDATION"
    case extractionExecution = "STAGE_5_EXTRACT"
    case payloadIntegrityVerification = "STAGE_6_INTEGRITY"
}

public struct DiagnosticErrorReport: Sendable {
    public let stage: DiagnosticStage
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let password: String?
    public let originalError: (any Error)?
    public let localizedMessage: String
    public let archivePath: String?
    public let destinationDir: String?
    public let sandboxDir: String?
    public let timestamp: Date
}

public final class SingleTestDiagnosticRunner: @unchecked Sendable {
    public static let shared = SingleTestDiagnosticRunner()
    
    private var failureReports: [DiagnosticErrorReport] = []
    private let lock = NSLock()
    
    private init() {}
    
    public func clearReports() {
        lock.lock()
        defer { lock.unlock() }
        failureReports.removeAll()
    }
    
    public func getReports() -> [DiagnosticErrorReport] {
        lock.lock()
        defer { lock.unlock() }
        return failureReports
    }
    
    public func reportFailure(
        stage: DiagnosticStage,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String? = nil,
        error: (any Error)? = nil,
        errorMessage: String,
        archivePath: String? = nil,
        destinationDir: String? = nil,
        sandboxPath: String? = nil
    ) {
        lock.lock()
        let report = DiagnosticErrorReport(
            stage: stage,
            format: format,
            level: level,
            password: password,
            originalError: error,
            localizedMessage: errorMessage,
            archivePath: archivePath,
            destinationDir: destinationDir,
            sandboxDir: sandboxPath,
            timestamp: Date()
        )
        failureReports.append(report)
        lock.unlock()
        
        TTLogger.error("\n" + String(repeating: "=", count: 80))
        TTLogger.error("🚨 [TTZip Diagnostic Failure Intercept] [\(stage.rawValue)]")
        TTLogger.error("--------------------------------------------------------------------------------")
        TTLogger.error("  • Format:           \(format.rawValue.uppercased()) (\(format.fileExtension))")
        TTLogger.error("  • Compression Level:\(level.title) (Level \(level.rawValue))")
        if let pwd = password {
            TTLogger.error("  • Password Encrypted:YES (AES-256: \(pwd))")
        } else {
            TTLogger.error("  • Password Encrypted:NO")
        }
        TTLogger.error("  • Stage Message:    \(errorMessage)")
        if let err = error {
            TTLogger.error("  • Underlying Error: \(err)")
        }
        if let arc = archivePath {
            let size = (try? FileManager.default.attributesOfItem(atPath: arc)[.size] as? Int64) ?? -1
            TTLogger.error("  • Archive Path:     \(arc) (Size: \(size) bytes)")
        }
        if let dst = destinationDir {
            TTLogger.error("  • Destination Dir:  \(dst)")
        }
        if let sb = sandboxPath {
            TTLogger.error("  • Sandbox Temp Dir: \(sb)")
        }
        TTLogger.error(String(repeating: "=", count: 80) + "\n")
    }
    
    public func logBanner(
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String? = nil,
        sandboxPath: String? = nil
    ) {
        TTLogger.info("\n" + String(repeating: "-", count: 80))
        TTLogger.info("🚀 [Starting Single Diagnostic Run: \(format.rawValue.uppercased())]")
        TTLogger.info("  - Format Extension: \(format.fileExtension)")
        TTLogger.info("  - Default Level:    \(level.title) (Level \(level.rawValue))")
        TTLogger.info("  - Encryption Test:  \(password != nil ? "Enabled" : "Disabled")")
        if let sb = sandboxPath {
            TTLogger.info("  - Working Sandbox:  \(sb)")
        }
        TTLogger.info(String(repeating: "-", count: 80))
    }
}
