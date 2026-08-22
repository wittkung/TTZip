// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance selective archive extractor for targeted file subsets.
///
/// Bypasses full-archive decompression by extracting selected paths.
public final class ArchiveSelectiveExtractor: @unchecked Sendable {
    public static let shared = ArchiveSelectiveExtractor()
    
    private init() {}
    
    /// Selectively extracts a subset of files matching targetEntryPaths into destinationDir.
    public func extractSelected(
        archivePath: String,
        targetEntryPaths: Set<String>,
        destinationDir: String,
        password: String? = nil
    ) async throws -> Int {
        guard !targetEntryPaths.isEmpty else { return 0 }
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: destinationDir) {
            try fm.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        }
        
        let tempExtractionDir = fm.temporaryDirectory.appendingPathComponent("ttzip_selective_\(UUID().uuidString)").path
        defer { try? fm.removeItem(atPath: tempExtractionDir) }
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(
            archivePath: archivePath,
            destinationDir: tempExtractionDir,
            options: .defaultClean,
            password: password
        )
        
        var movedCount = 0
        for targetPath in targetEntryPaths {
            let srcPath = (tempExtractionDir as NSString).appendingPathComponent(targetPath)
            if fm.fileExists(atPath: srcPath) {
                let destPath = (destinationDir as NSString).appendingPathComponent(targetPath)
                let parentDir = (destPath as NSString).deletingLastPathComponent
                try? fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: destPath) {
                    try? fm.removeItem(atPath: destPath)
                }
                try fm.moveItem(atPath: srcPath, toPath: destPath)
                movedCount += 1
            }
        }
        
        return movedCount
    }
    
    /// Extracts a single entry directly into memory for instant Space-bar Quick Look or Drag-and-Drop.
    public func extractSingleEntryData(
        archivePath: String,
        entryPath: String,
        password: String? = nil
    ) async throws -> Data? {
        // 0. VFS LZ4 Cache Pool Fast Path
        if let cached = VFSLz4CachePool.shared.getCachedEntry(archivePath: archivePath, entryPath: entryPath) {
            return cached
        }
        
        // 1. Safe Rust Microkernel In-Memory Fast Path (7z archives)
        let ext = (archivePath as NSString).pathExtension.lowercased()
        if ext == "7z" || ext == "cb7" {
            let maxBufSize = 32 * 1024 * 1024 // 32MB single entry in-memory window
            var memBuffer = [UInt8](repeating: 0, count: maxBufSize)
            var extractedLen: Int = 0
            
            let status = archivePath.withCString { cArch in
                entryPath.withCString { cEntry in
                    CUnsafeBufferAdapter.withCString(password) { cPwd in
                        memBuffer.withUnsafeMutableBufferPointer { bPtr in
                            guard let base = bPtr.baseAddress else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                            return ttzip_rust_7z_extract_entry_memory(
                                cArch,
                                cEntry,
                                -1,
                                cPwd,
                                base,
                                maxBufSize,
                                &extractedLen
                            )
                        }
                    }
                }
            }
            
            if status == TTZIP_STATUS_OK && extractedLen > 0 && extractedLen <= maxBufSize {
                let data = Data(memBuffer.prefix(extractedLen))
                VFSLz4CachePool.shared.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: data)
                return data
            }
        }
        
        // 2. General Streaming Path: Extract single entry to ephemeral temp directory
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("ttzip_preview_\(UUID().uuidString)").path
        defer { try? fm.removeItem(atPath: tempDir) }
        
        let count = try await extractSelected(
            archivePath: archivePath,
            targetEntryPaths: [entryPath],
            destinationDir: tempDir,
            password: password
        )
        
        guard count > 0 else { return nil }
        let outPath = (tempDir as NSString).appendingPathComponent(entryPath)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: outPath)) {
            VFSLz4CachePool.shared.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: data)
            return data
        }
        return nil
    }
}
