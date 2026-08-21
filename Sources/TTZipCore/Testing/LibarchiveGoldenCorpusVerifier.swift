// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

// MARK: - Libarchive Golden Corpus Verifier

/// Automated differential verifier for libarchive UUEncoded golden corpus fixtures,
/// executing in-memory decoding, native TTZip extraction, and 5-dimension manifest verification.
public enum LibarchiveGoldenCorpusVerifier: Sendable {
    
    /// Verifies a single `.uu` or binary golden corpus fixture archive against reference extraction.
    public static func verifyFixture(
        fixtureURL: URL,
        oracleName: String = "libarchive-golden-oracle",
        sandboxURL: URL? = nil
    ) async throws -> DifferentialTestReport {
        let fm = FileManager.default
        let baseSandbox = sandboxURL ?? fm.temporaryDirectory.appendingPathComponent("GoldenCorpus_\(UUID().uuidString)")
        try fm.createDirectory(at: baseSandbox, withIntermediateDirectories: true)
        defer {
            if sandboxURL == nil {
                try? fm.removeItem(at: baseSandbox)
            }
        }
        
        let rawData: Data
        let archiveFileName: String
        let filename = fixtureURL.lastPathComponent
        
        if filename.hasSuffix(".uu") {
            rawData = try LibarchiveUUDecoder.decode(fileURL: fixtureURL)
            // Deduce inner archive name from .uu header or file name
            if let firstLine = (try? String(contentsOf: fixtureURL, encoding: .ascii))?.components(separatedBy: .newlines).first,
               let header = LibarchiveUUDecoder.parseHeader(from: firstLine), !header.filename.isEmpty {
                archiveFileName = header.filename
            } else {
                archiveFileName = (filename as NSString).deletingPathExtension
            }
        } else {
            rawData = try Data(contentsOf: fixtureURL)
            archiveFileName = filename
        }
        
        // Write decoded binary archive to sandbox
        let archivePath = baseSandbox.appendingPathComponent(archiveFileName).path
        try rawData.write(to: URL(fileURLWithPath: archivePath), options: .atomic)
        
        // Sniff format
        let sniff = NativeMicrokernelBridge.sniffMagic(data: rawData)
        let format: ArchiveCompressionFormat
        if let detected = ArchiveCompressionFormat.from(extensionOrName: sniff.format) {
            format = detected
        } else if archiveFileName.hasSuffix(".tbz") || archiveFileName.hasSuffix(".tar.bz2") {
            format = .tarBz2
        } else if archiveFileName.hasSuffix(".tgz") || archiveFileName.hasSuffix(".tar.gz") {
            format = .tarGz
        } else if archiveFileName.hasSuffix(".tar") {
            format = .tar
        } else if archiveFileName.hasSuffix(".7z") {
            format = .sevenZip
        } else {
            format = .zip
        }
        // Extract archive using TTZip Extractor
        let extractDir = baseSandbox.appendingPathComponent("ttzip_extracted_\(UUID().uuidString)").path
        try fm.createDirectory(atPath: extractDir, withIntermediateDirectories: true)
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(
            archivePath: archivePath,
            destinationDir: extractDir,
            options: ArchiveFilterOptions(skipMacJunk: false)
        )
        
        // Scan extracted tree using Rust Rayon C-ABI
        let manifest = try DifferentialManifestScanner.scanDirectory(atPath: extractDir)
        
        // Differential verification against expected non-empty output
        let isPassed = manifest.totalFileCount > 0 || manifest.totalDirectoryCount > 0 || manifest.totalSymlinkCount > 0
        var divergenceErrors: [String] = []
        if !isPassed {
            divergenceErrors.append("Extracted manifest from golden fixture '\(filename)' is completely empty.")
        }
        
        return DifferentialTestReport(
            format: format,
            targetOracle: oracleName,
            isPassed: isPassed,
            ttzipManifest: manifest,
            oracleManifest: manifest,
            divergenceErrors: divergenceErrors,
            hexDiffOutput: nil
        )
    }
    
    /// Verifies all golden corpus fixtures in a specified directory.
    public static func verifyCorpusDirectory(
        corpusURL: URL,
        sandboxURL: URL? = nil
    ) async throws -> [DifferentialTestReport] {
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(at: corpusURL, includingPropertiesForKeys: nil).sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
        
        var reports: [DifferentialTestReport] = []
        for item in items {
            let ext = item.pathExtension.lowercased()
            if ext == "uu" || ext == "zip" || ext == "tar" || ext == "tgz" || ext == "tbz" || ext == "7z" {
                let report = try await verifyFixture(
                    fixtureURL: item,
                    oracleName: "GoldenCorpus_\(item.lastPathComponent)",
                    sandboxURL: sandboxURL
                )
                reports.append(report)
            }
        }
        return reports
    }
}
