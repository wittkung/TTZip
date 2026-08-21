// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance native 7z archiving, extraction, and split-volume management engine.
public final class SevenZipEngine: @unchecked Sendable {
    public static let shared = SevenZipEngine()
    
    private static let _mmtArg: String = "-mmt=on"
    private static let mxArgs = ["-mx=0", "-mx=1", "-mx=2", "-mx=3", "-mx=4", "-mx=5", "-mx=6", "-mx=7", "-mx=8", "-mx=9"]
    
    private init() {}
    
    // MARK: - Compression Entry
    
    /// Creates and compresses a 7z archive.
    @inline(__always)
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipCAdapter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            progressHandler: progressHandler
        )
    }
    
    // MARK: - Extraction Entry
    
    /// Extracts a 7z archive using the in-process C static binding engine.
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) throws -> Bool {
        let pwd = (password != nil && !password!.isEmpty) ? password : nil

        if archivePath.hasSuffix(".001") || archivePath.contains(".7z.") {
            TTLogger.info("[SevenZipEngine] Extracting split volume archive: \(archivePath)")
            let joinedTemp = FileManager.default.temporaryDirectory.appendingPathComponent("joined_\(UUID().uuidString).7z").path
            defer { try? FileManager.default.removeItem(atPath: joinedTemp) }
            if ArchiveExtractor().joinSplitVolumes(firstVolumePath: archivePath, outputPath: joinedTemp) {
                if let ok = try? SevenZipCAdapter.shared.extractArchive(archivePath: joinedTemp, destinationDir: destinationDir, skipMacJunk: true, password: pwd), ok {
                    let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
                    if !items.isEmpty { return true }
                }
            }
            let ok = try SevenZipCAdapter.shared.extractArchive(archivePath: archivePath, destinationDir: destinationDir, skipMacJunk: true, password: pwd)
            if !ok {
                TTLogger.debug("[SevenZipEngine] Split archive extraction failed: \(archivePath)")
            }
            return ok
        }
        
        let ok = try SevenZipCAdapter.shared.extractArchive(archivePath: archivePath, destinationDir: destinationDir, skipMacJunk: true, password: pwd)
        if !ok {
            TTLogger.debug("[SevenZipEngine] Extraction failed: \(archivePath)")
            return false
        }
        
        let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
        TTLogger.debug("[SevenZipEngine] destinationDir: \(destinationDir), itemsCount: \(items.count), items: \(items)")
        if items.isEmpty {
            TTLogger.warning("[SevenZipEngine] Extraction succeeded but output directory is empty: \(destinationDir)")
            return false
        }
        
        return true
    }
    
    // MARK: - Helpers
    
    private func splitPath(_ path: String) -> (String?, String) {
        if let lastSlash = path.lastIndex(of: "/") {
            return (String(path[..<lastSlash]), String(path[path.index(after: lastSlash)...]))
        }
        return (nil, path)
    }
}
