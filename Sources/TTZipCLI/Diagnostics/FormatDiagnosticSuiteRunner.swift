// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
import CTTZipBridge

/// Single format test configuration.
public struct FormatDiagnosticConfig: Sendable {
    public let format: ArchiveCompressionFormat
    public let levelsToTest: [ArchiveCompressionLevel]
    public let testPasswordEncryption: Bool
    public let passwordToTest: String
    public let sampleFileCount: Int
    public let lineRepeatCount: Int
    
    public init(
        format: ArchiveCompressionFormat,
        levelsToTest: [ArchiveCompressionLevel] = [.store, .level1, .level6, .level9],
        testPasswordEncryption: Bool = true,
        passwordToTest: String = "TTZipTestPassword#2026!",
        sampleFileCount: Int = 100,
        lineRepeatCount: Int = 2000
    ) {
        self.format = format
        self.levelsToTest = format.supportedLevels.filter { levelsToTest.contains($0) }
        self.testPasswordEncryption = testPasswordEncryption && format.supportsPasswordEncryption
        self.passwordToTest = passwordToTest
        self.sampleFileCount = sampleFileCount
        self.lineRepeatCount = lineRepeatCount
    }
}

/// Generic format diagnostic test runner encapsulating dataset generation, compression, extraction, and CRC32 verification.
public final class FormatDiagnosticSuiteRunner: @unchecked Sendable {
    public static let shared = FormatDiagnosticSuiteRunner()
    
    private init() {}
    
    /// Runs format diagnostic suite for target configuration.
    @discardableResult
    public func runDiagnosticSuite(config: FormatDiagnosticConfig) throws -> Bool {
        let fmt = config.format
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("\(fmt.rawValue.capitalized)Debug_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }
        
        let sourceFolder = tempDir.appendingPathComponent("small_files")
        try fm.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        
        // 1. Generate test dataset
        let line = "Apple Silicon TTZip High-Precision \(fmt.rawValue.uppercased()) Diagnostic Benchmark Line...\n"
        let sampleContent = String(repeating: line, count: config.lineRepeatCount)
        let sampleData = sampleContent.data(using: .utf8)!
        let singleFileSize = Int64(sampleData.count)
        
        for i in 0..<config.sampleFileCount {
            let fURL = sourceFolder.appendingPathComponent("file_\(i).txt")
            try sampleData.write(to: fURL)
        }
        let expectedTotalBytes = singleFileSize * Int64(config.sampleFileCount)
        
        SingleTestDiagnosticRunner.shared.logBanner(
            format: fmt,
            level: config.levelsToTest.first ?? .store,
            password: config.testPasswordEncryption ? config.passwordToTest : nil,
            sandboxPath: tempDir.path
        )
        TTLogger.info("  - Dataset ready: \(sourceFolder.path) | \(config.sampleFileCount) files | Expected bytes: \(expectedTotalBytes)")
        
        let writer = ArchiveEngineFactory.makeWriter(for: fmt)
        let extractor = ArchiveEngineFactory.makeExtractor(for: fmt)
        let checker = ArchiveEngineFactory.makeIntegrityChecker()
        var allPassed = true
        
        // 2. Iterate compression levels
        for level in config.levelsToTest {
            TTLogger.info("\n🔍 [\(fmt.rawValue.uppercased()) Diagnostic] Testing \(level.title) (Level \(level.rawValue))...")
            let archiveName = "archive_\(level.rawValue)\(fmt.fileExtension)"
            let archivePath = tempDir.appendingPathComponent(archiveName).path
            
            let startCompress = Date()
            do {
                try writer.createArchiveSync(
                    outputPath: archivePath,
                    format: fmt,
                    level: level,
                    inputPaths: [sourceFolder.path]
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .compressionExecution,
                    format: fmt,
                    level: level,
                    error: error,
                    errorMessage: "Compression failed with exception",
                    archivePath: archivePath,
                    sandboxPath: tempDir.path
                )
                allPassed = false
                continue
            }
            
            let compressDuration = max(0.001, Date().timeIntervalSince(startCompress))
            let archiveSize = (try? fm.attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0
            if archiveSize == 0 {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .archiveValidation,
                    format: fmt,
                    level: level,
                    errorMessage: "Generated archive size is 0 bytes",
                    archivePath: archivePath,
                    sandboxPath: tempDir.path
                )
                allPassed = false
                continue
            }
            
            let compressMBs = (Double(expectedTotalBytes) / (1024 * 1024)) / compressDuration
            TTLogger.info("  - \(fmt.rawValue.uppercased()) \(level.title) compressed, size: \(archiveSize) bytes | Duration: \(String(format: "%.3f", compressDuration))s (\(String(format: "%.1f", compressMBs)) MB/s)")
            
            let outDir = tempDir.appendingPathComponent("out_\(level.rawValue)").path
            try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            
            let startExtract = Date()
            do {
                try extractor.extractSync(
                    archivePath: archivePath,
                    destinationDir: outDir
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .extractionExecution,
                    format: fmt,
                    level: level,
                    error: error,
                    errorMessage: "Extraction failed with exception",
                    archivePath: archivePath,
                    destinationDir: outDir,
                    sandboxPath: tempDir.path
                )
                allPassed = false
                continue
            }
            let extractDuration = max(0.001, Date().timeIntervalSince(startExtract))
            let extractMBs = (Double(expectedTotalBytes) / (1024 * 1024)) / extractDuration
            TTLogger.info("  - Extraction complete: \(String(format: "%.3f", extractDuration))s (\(String(format: "%.1f", extractMBs)) MB/s)")
            
            let res = checker.verifyExtractedDirectory(
                directoryPath: outDir,
                expectedOriginalBytes: expectedTotalBytes,
                sourceFilePath: sourceFolder.path,
                label: "\(fmt.rawValue.uppercased()) \(level.title)"
            )
            if !res.isValid {
                allPassed = false
            }
        }
        
        // 3. Password encryption roundtrip
        if config.testPasswordEncryption {
            let encLevel: ArchiveCompressionLevel = config.levelsToTest.contains(.level1) ? .level1 : (config.levelsToTest.first ?? .store)
            TTLogger.info("\n🔍 [\(fmt.rawValue.uppercased()) Diagnostic] Testing AES-256 \(encLevel.title)...")
            let encArchiveName = "archive_enc\(fmt.fileExtension)"
            let encArchivePath = tempDir.appendingPathComponent(encArchiveName).path
            
            do {
                try writer.createArchiveSync(
                    outputPath: encArchivePath,
                    format: fmt,
                    level: encLevel,
                    inputPaths: [sourceFolder.path],
                    password: config.passwordToTest
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .compressionExecution,
                    format: fmt,
                    level: encLevel,
                    password: config.passwordToTest,
                    error: error,
                    errorMessage: "Encrypted compression failed with exception",
                    archivePath: encArchivePath,
                    sandboxPath: tempDir.path
                )
                return false
            }
            
            let encOutDir = tempDir.appendingPathComponent("out_enc").path
            try fm.createDirectory(atPath: encOutDir, withIntermediateDirectories: true)
            
            do {
                try extractor.extractSync(
                    archivePath: encArchivePath,
                    destinationDir: encOutDir,
                    password: config.passwordToTest
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .extractionExecution,
                    format: fmt,
                    level: encLevel,
                    password: config.passwordToTest,
                    error: error,
                    errorMessage: "Encrypted extraction failed with exception",
                    archivePath: encArchivePath,
                    destinationDir: encOutDir,
                    sandboxPath: tempDir.path
                )
                return false
            }
            
            let encRes = checker.verifyExtractedDirectory(
                directoryPath: encOutDir,
                expectedOriginalBytes: expectedTotalBytes,
                sourceFilePath: sourceFolder.path,
                label: "\(fmt.rawValue.uppercased()) AES-256"
            )
            if !encRes.isValid {
                allPassed = false
            }
        }
        
        TTLogger.info("--------------------------------------------------------------------------------\n")
        return allPassed
    }
}
