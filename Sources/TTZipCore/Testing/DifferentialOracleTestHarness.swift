// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Differential Oracle Test Harness

/// Differential oracle test runner executing bidirectional roundtrip comparisons.
public enum DifferentialOracleTestHarness: Sendable {
    
    /// Executes bidirectional roundtrip verification between TTZip and reference oracles.
    public static func executeRoundtrip(
        format: ArchiveCompressionFormat,
        sourceDir: String,
        oracle: String,
        tempSandbox: String
    ) async throws -> DifferentialTestReport {
        let registry = DifferentialOracleRegistry.shared
        guard let resolvedOraclePath = registry.oraclePath(for: oracle) else {
            throw ArchiveError.fileNotFound
        }
        
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourceDir).standardized
        let sandboxURL = URL(fileURLWithPath: tempSandbox).standardized
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        try fm.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        
        // 1. Baseline scan
        let baselineManifest = try DifferentialManifestScanner.scanDirectory(atPath: sourceURL.path)
        let childItems = try fm.contentsOfDirectory(atPath: sourceURL.path).sorted()
        guard !childItems.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        let fullInputPaths = childItems.map { sourceURL.appendingPathComponent($0).path }
        
        var divergenceErrors: [String] = []
        var capturedHexDiff: String? = nil
        
        // 2. Pass 1: TTZip compress -> Oracle extract
        let ttzipArchiveURL = sandboxURL.appendingPathComponent("ttzip_out_\(UUID().uuidString)\(format.fileExtension)")
        let oracleExtractURL = sandboxURL.appendingPathComponent("oracle_extracted_\(UUID().uuidString)")
        try fm.createDirectory(at: oracleExtractURL, withIntermediateDirectories: true)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: ttzipArchiveURL.path,
            format: format,
            level: .normal,
            inputPaths: fullInputPaths
        )
        guard fm.fileExists(atPath: ttzipArchiveURL.path) else {
            throw ArchiveError.readFailed(code: -1)
        }
        
        try await extractWithOracle(
            oraclePath: resolvedOraclePath,
            format: format,
            archivePath: ttzipArchiveURL.path,
            destinationDir: oracleExtractURL.path
        )
        
        let oracleExtractedManifest = try DifferentialManifestScanner.scanDirectory(atPath: oracleExtractURL.path)
        let pass1Report = DifferentialManifestVerifier.compare(
            ttzip: oracleExtractedManifest,
            oracle: baselineManifest,
            format: format,
            oracleName: "\(oracle) (TTZip->Oracle)"
        )
        divergenceErrors.append(contentsOf: pass1Report.divergenceErrors)
        if capturedHexDiff == nil {
            capturedHexDiff = pass1Report.hexDiffOutput
        }
        
        // 3. Pass 2: Oracle compress -> TTZip extract (if oracle supports creation)
        var ttzipExtractedManifest: FileTreeManifest? = nil
        if canOracleCompress(oracle: resolvedOraclePath, format: format) {
            let oracleArchiveURL = sandboxURL.appendingPathComponent("oracle_out_\(UUID().uuidString)\(format.fileExtension)")
            let ttzipExtractURL = sandboxURL.appendingPathComponent("ttzip_extracted_\(UUID().uuidString)")
            try fm.createDirectory(at: ttzipExtractURL, withIntermediateDirectories: true)
            
            try await compressWithOracle(
                oraclePath: resolvedOraclePath,
                format: format,
                sourceDir: sourceURL.path,
                inputItems: childItems,
                outputPath: oracleArchiveURL.path
            )
            
            if fm.fileExists(atPath: oracleArchiveURL.path) {
                let extractor = ArchiveExtractor()
                try await extractor.extract(
                    archivePath: oracleArchiveURL.path,
                    destinationDir: ttzipExtractURL.path,
                    options: ArchiveFilterOptions(skipMacJunk: false)
                )
                
                let ttzipManifest = try DifferentialManifestScanner.scanDirectory(atPath: ttzipExtractURL.path)
                ttzipExtractedManifest = ttzipManifest
                
                let pass2Report = DifferentialManifestVerifier.compare(
                    ttzip: ttzipManifest,
                    oracle: baselineManifest,
                    format: format,
                    oracleName: "\(oracle) (Oracle->TTZip)"
                )
                divergenceErrors.append(contentsOf: pass2Report.divergenceErrors)
                if capturedHexDiff == nil {
                    capturedHexDiff = pass2Report.hexDiffOutput
                }
                
                let crossReport = DifferentialManifestVerifier.compare(
                    ttzip: ttzipManifest,
                    oracle: oracleExtractedManifest,
                    format: format,
                    oracleName: oracle
                )
                divergenceErrors.append(contentsOf: crossReport.divergenceErrors)
                if capturedHexDiff == nil {
                    capturedHexDiff = crossReport.hexDiffOutput
                }
            }
        }
        
        var seenErrors = Set<String>()
        var uniqueErrors: [String] = []
        for err in divergenceErrors {
            if !seenErrors.contains(err) {
                seenErrors.insert(err)
                uniqueErrors.append(err)
            }
        }
        
        let isPassed = uniqueErrors.isEmpty
        return DifferentialTestReport(
            format: format,
            targetOracle: oracle,
            isPassed: isPassed,
            ttzipManifest: ttzipExtractedManifest ?? oracleExtractedManifest,
            oracleManifest: oracleExtractedManifest,
            divergenceErrors: uniqueErrors,
            hexDiffOutput: capturedHexDiff
        )
    }
    
    // MARK: - Oracle Subprocess Execution Helpers
    
    public static func canOracleCompress(oracle: String, format: ArchiveCompressionFormat) -> Bool {
        let name = (oracle as NSString).lastPathComponent.lowercased()
        if name.contains("tar") {
            return format == .tar || format == .gz || format == .tarGz || format == .bz2 || format == .tarBz2 || format == .xz || format == .tarXz || format == .zst || format == .tarZst
        }
        if name.contains("unzip") {
            return DifferentialOracleRegistry.shared.oraclePath(for: "zip") != nil && format == .zip
        }
        if name.contains("zip") {
            return format == .zip
        }
        if name.contains("7z") {
            return format == .sevenZip || format == .zip || format == .tar
        }
        if name == "zstd" {
            return format == .zst || format == .tarZst
        }
        if name == "gzip" {
            return format == .gz || format == .tarGz
        }
        if name == "xz" {
            return format == .xz || format == .tarXz
        }
        return false
    }
    
    public static func extractWithOracle(
        oraclePath: String,
        format: ArchiveCompressionFormat,
        archivePath: String,
        destinationDir: String
    ) async throws {
        let name = (oraclePath as NSString).lastPathComponent.lowercased()
        let args: [String]
        
        if name.contains("unzip") {
            args = ["-q", "-o", archivePath, "-d", destinationDir]
        } else if name.contains("tar") {
            args = ["-xf", archivePath, "-C", destinationDir]
        } else if name.contains("7z") {
            args = ["x", "-y", "-o\(destinationDir)", archivePath]
        } else {
            args = ["-xf", archivePath, "-C", destinationDir]
        }
        
        let result = try await SubprocessExecutor.shared.executeAsync(
            executablePath: oraclePath,
            arguments: args,
            currentDirectory: destinationDir
        )
        guard result.exitCode == 0 else {
            throw ArchiveError.readFailed(code: result.exitCode)
        }
    }
    
    public static func compressWithOracle(
        oraclePath: String,
        format: ArchiveCompressionFormat,
        sourceDir: String,
        inputItems: [String],
        outputPath: String
    ) async throws {
        let name = (oraclePath as NSString).lastPathComponent.lowercased()
        var execPath = oraclePath
        let args: [String]
        
        if name.contains("tar") {
            var flag = "-cf"
            switch format {
            case .gz, .tarGz: flag = "-czf"
            case .bz2, .tarBz2: flag = "-cjf"
            case .xz, .tarXz: flag = "-cJf"
            default: flag = "-cf"
            }
            args = [flag, outputPath, "-C", sourceDir] + inputItems
        } else if name.contains("unzip") {
            guard let zipPath = DifferentialOracleRegistry.shared.oraclePath(for: "zip") else {
                throw ArchiveError.invalidFormat
            }
            execPath = zipPath
            args = ["-q", "-r", "-y", outputPath] + inputItems
        } else if name.contains("zip") {
            args = ["-q", "-r", "-y", outputPath] + inputItems
        } else if name.contains("7z") {
            args = ["a", "-y", outputPath] + inputItems
        } else {
            throw ArchiveError.invalidFormat
        }
        
        let result = try await SubprocessExecutor.shared.executeAsync(
            executablePath: execPath,
            arguments: args,
            currentDirectory: sourceDir
        )
        guard result.exitCode == 0 else {
            throw ArchiveError.readFailed(code: result.exitCode)
        }
    }
}
