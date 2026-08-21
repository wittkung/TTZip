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
/// Bypasses full-archive decompression by leveraging format-specific fast paths
/// (ZIP random seek tables and in-memory streaming data skips).
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
        
        let pathLower = archivePath.lowercased()
        
        // 1. ZIP Fast Path: Direct Random Seek via Central Directory
        if pathLower.hasSuffix(".zip") || pathLower.hasSuffix(".zipx") || pathLower.hasSuffix(".aar") {
            let fd = open(archivePath, O_RDONLY)
            if fd >= 0 {
                defer { close(fd) }
                var st = stat()
                if fstat(fd, &st) == 0 {
                    let fileSize = Int(st.st_size)
                    if let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
                        defer { munmap(mapped, fileSize) }
                        let bytePtr = mapped.assumingMemoryBound(to: UInt8.self)
                        if let descriptors = ZipCentralDirectoryReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize, skipMacJunk: false) {
                            let seekTable = ZipSeekTable(descriptors: descriptors, archiveSize: fileSize, bytePtr: bytePtr)
                            var extractedCount = 0
                            for targetPath in targetEntryPaths {
                                if let entryData = seekTable.extractSingleEntry(path: targetPath, from: bytePtr, fileSize: fileSize, password: password) {
                                    let outPath = (destinationDir as NSString).appendingPathComponent(targetPath)
                                    let parentDir = (outPath as NSString).deletingLastPathComponent
                                    try? fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                                    try entryData.write(to: URL(fileURLWithPath: outPath))
                                    extractedCount += 1
                                }
                            }
                            if extractedCount > 0 {
                                return extractedCount
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Fallback Streaming Fast-Path with temporary extraction
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
        let pathLower = archivePath.lowercased()
        
        // 0. VFS LZ4 Cache Pool Fast Path
        if let cached = VFSLz4CachePool.shared.getCachedEntry(archivePath: archivePath, entryPath: entryPath) {
            return cached
        }
        
        // 1. ZIP Fast Path: Direct Random Seek via Central Directory
        if pathLower.hasSuffix(".zip") || pathLower.hasSuffix(".zipx") || pathLower.hasSuffix(".aar") {
            let fd = open(archivePath, O_RDONLY)
            if fd >= 0 {
                defer { close(fd) }
                var st = stat()
                if fstat(fd, &st) == 0 {
                    let fileSize = Int(st.st_size)
                    if let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
                        defer { munmap(mapped, fileSize) }
                        let bytePtr = mapped.assumingMemoryBound(to: UInt8.self)
                        if let descriptors = ZipCentralDirectoryReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize, skipMacJunk: false) {
                            let seekTable = ZipSeekTable(descriptors: descriptors, archiveSize: fileSize, bytePtr: bytePtr)
                            if let entryData = seekTable.extractSingleEntry(path: entryPath, from: bytePtr, fileSize: fileSize, password: password) {
                                VFSLz4CachePool.shared.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: entryData)
                                return entryData
                            }
                        }
                    }
                }
            }
        }
        
        // 2. 7z Fast Path: Direct Rust in-memory streaming truncation extraction (<10ms zero disk write)
        if pathLower.hasSuffix(".7z") || pathLower.hasSuffix(".cb7") {
            if let entryData = SevenZipSeekTable.extractSingleEntryData(archivePath: archivePath, entryPath: entryPath, password: password) {
                VFSLz4CachePool.shared.cacheEntry(archivePath: archivePath, entryPath: entryPath, data: entryData)
                return entryData
            }
        }
        
        // 3. General Streaming Path: Extract single entry to ephemeral temp directory
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
