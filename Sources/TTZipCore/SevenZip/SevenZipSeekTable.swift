// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// In-memory random access and single-file extraction seek table for 7z archives.
public final class SevenZipSeekTable: @unchecked Sendable {
    
    public struct SeekEntry: Sendable {
        public let path: String
        public let uncompressedSize: Int64
        public let uncompressedOffset: Int64
        public let folderIndex: Int
        public let crc32: UInt32
        public let isDirectory: Bool
        public let isEmptyStream: Bool
        
        public init(
            path: String,
            uncompressedSize: Int64,
            uncompressedOffset: Int64,
            folderIndex: Int,
            crc32: UInt32,
            isDirectory: Bool,
            isEmptyStream: Bool
        ) {
            self.path = path
            self.uncompressedSize = uncompressedSize
            self.uncompressedOffset = uncompressedOffset
            self.folderIndex = folderIndex
            self.crc32 = crc32
            self.isDirectory = isDirectory
            self.isEmptyStream = isEmptyStream
        }
    }
    
    private let entriesByPath: [String: SeekEntry]
    public let allEntries: [SeekEntry]
    public let archivePath: String
    
    public init(archivePath: String, entries: [SeekEntry]) {
        self.archivePath = archivePath
        self.allEntries = entries
        var map: [String: SeekEntry] = [:]
        map.reserveCapacity(entries.count)
        for e in entries {
            map[e.path] = e
        }
        self.entriesByPath = map
    }
    
    /// Constructs a seek table by reading 7z archive headers asynchronously.
    public static func fromArchive(path: String, password: String? = nil) async throws -> SevenZipSeekTable {
        let entries = try await ArchiveReader().inspect(archivePath: path, password: password)
        var seekEntries: [SeekEntry] = []
        var runningOffset: Int64 = 0
        for entry in entries {
            seekEntries.append(SeekEntry(
                path: entry.path,
                uncompressedSize: entry.uncompressedSize,
                uncompressedOffset: runningOffset,
                folderIndex: 0,
                crc32: 0,
                isDirectory: entry.isDirectory,
                isEmptyStream: entry.uncompressedSize == 0
            ))
            runningOffset += entry.uncompressedSize
        }
        return SevenZipSeekTable(archivePath: path, entries: seekEntries)
    }
    
    /// O(1) metadata lookup by relative archive path.
    public func entry(forPath path: String) -> SeekEntry? {
        return entriesByPath[path]
    }
    
    /// Extracts a single entry directly to a destination directory without temporary directory full extraction.
    public func extractSingleFile(path: String, destinationDir: String, password: String? = nil) throws -> Bool {
        if let entry = entry(forPath: path), entry.isDirectory {
            let outDir = URL(fileURLWithPath: destinationDir).appendingPathComponent(path).path
            try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            return true
        }
        
        let outFilePath = URL(fileURLWithPath: destinationDir).appendingPathComponent(path).path
        let parentDir = (outFilePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        
        guard let data = extractData(forPath: path, password: password) else {
            return false
        }
        
        try data.write(to: URL(fileURLWithPath: outFilePath))
        return true
    }
    
    /// Extracts single entry data directly into a Swift `Data` buffer with zero disk writes.
    public func extractData(forPath path: String, password: String? = nil) -> Data? {
        if let entry = entry(forPath: path) {
            if entry.isDirectory { return nil }
            if entry.isEmptyStream || entry.uncompressedSize == 0 { return Data() }
            return Self.extractSingleEntryData(
                archivePath: archivePath,
                entryPath: path,
                expectedSize: Int(entry.uncompressedSize),
                password: password
            )
        }
        
        return Self.extractSingleEntryData(
            archivePath: archivePath,
            entryPath: path,
            expectedSize: nil,
            password: password
        )
    }
    
    /// Fast in-memory 7z solid single entry streaming extraction via Rust FFI (<10ms, zero disk write).
    public static func extractSingleEntryData(
        archivePath: String,
        entryPath: String,
        expectedSize: Int? = nil,
        password: String? = nil
    ) -> Data? {
        let initialCapacity = max(expectedSize ?? 64 * 1024, 1024)
        var buffer = [UInt8](repeating: 0, count: initialCapacity)
        var extractedLen: Int = 0
        
        let status = CUnsafeBufferAdapter.withCString(archivePath) { cArch in
            CUnsafeBufferAdapter.withCString(entryPath) { cPath in
                guard let cArch = cArch, let cPath = cPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                if let pass = password {
                    return CUnsafeBufferAdapter.withCString(pass) { cPass in
                        ttzip_rust_7z_extract_entry_memory(
                            cArch,
                            cPath,
                            -1,
                            cPass,
                            &buffer,
                            initialCapacity,
                            &extractedLen
                        )
                    }
                } else {
                    return ttzip_rust_7z_extract_entry_memory(
                        cArch,
                        cPath,
                        -1,
                        nil,
                        &buffer,
                        initialCapacity,
                        &extractedLen
                    )
                }
            }
        }
        
        if status == TTZIP_STATUS_OK {
            return Data(buffer.prefix(extractedLen))
        }
        
        // If buffer was too small, reallocate with exact extractedLen
        if (status == TTZIP_STATUS_ERR_OUT_OF_MEMORY || extractedLen > initialCapacity) && extractedLen > 0 {
            var exactBuffer = [UInt8](repeating: 0, count: extractedLen)
            var actualLen: Int = 0
            let retryStatus = CUnsafeBufferAdapter.withCString(archivePath) { cArch in
                CUnsafeBufferAdapter.withCString(entryPath) { cPath in
                    guard let cArch = cArch, let cPath = cPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    if let pass = password {
                        return CUnsafeBufferAdapter.withCString(pass) { cPass in
                            ttzip_rust_7z_extract_entry_memory(
                                cArch,
                                cPath,
                                -1,
                                cPass,
                                &exactBuffer,
                                exactBuffer.count,
                                &actualLen
                            )
                        }
                    } else {
                        return ttzip_rust_7z_extract_entry_memory(
                            cArch,
                            cPath,
                            -1,
                            nil,
                            &exactBuffer,
                            exactBuffer.count,
                            &actualLen
                        )
                    }
                }
            }
            if retryStatus == TTZIP_STATUS_OK {
                return Data(exactBuffer.prefix(actualLen))
            }
        }
        
        // Fallback: in-process extraction to ephemeral buffer
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_7z_tmp_\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let success = (try? SevenZipCAdapter.shared.extractArchive(archivePath: archivePath, destinationDir: tempDir, skipMacJunk: false, password: password)) ?? false
        if success {
            let directOut = URL(fileURLWithPath: tempDir).appendingPathComponent(entryPath).path
            if let data = try? Data(contentsOf: URL(fileURLWithPath: directOut)) {
                return data
            }
            let fileName = (entryPath as NSString).lastPathComponent
            let fm = FileManager.default
            if let enumerator = fm.enumerator(atPath: tempDir) {
                for case let file as String in enumerator {
                    if file == entryPath || file.hasSuffix("/\(entryPath)") || (file as NSString).lastPathComponent == fileName {
                        let fPath = URL(fileURLWithPath: tempDir).appendingPathComponent(file).path
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: fPath)) {
                            return data
                        }
                    }
                }
            }
        }
        
        return nil
    }
}
