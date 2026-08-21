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
    
    /// O(1) metadata lookup by relative archive path.
    public func entry(forPath path: String) -> SeekEntry? {
        return entriesByPath[path]
    }
    
    /// Extracts a single entry directly to a destination directory without temporary directory full extraction.
    public func extractSingleFile(path: String, destinationDir: String, password: String? = nil) throws -> Bool {
        guard let entry = entry(forPath: path) else { return false }
        if entry.isDirectory {
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
        guard let entry = entry(forPath: path), !entry.isDirectory else { return nil }
        if entry.isEmptyStream || entry.uncompressedSize == 0 {
            return Data()
        }
        
        let targetSize = Int(entry.uncompressedSize)
        var buffer = [UInt8](repeating: 0, count: targetSize)
        var extractedLen: Int = 0
        
        let status = archivePath.withCString { cArch in
            path.withCString { cPath in
                if let pass = password {
                    return pass.withCString { cPass in
                        ttzip_rust_7z_extract_entry_memory(
                            cArch,
                            cPath,
                            -1,
                            cPass,
                            &buffer,
                            targetSize,
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
                        targetSize,
                        &extractedLen
                    )
                }
            }
        }
        
        guard status == TTZIP_STATUS_OK else {
            return nil
        }
        
        return Data(buffer.prefix(extractedLen))
    }
}
