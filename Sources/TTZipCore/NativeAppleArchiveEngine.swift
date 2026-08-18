// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
@preconcurrency import AppleArchive
import System

/// Native in-process Apple Archive (`.aar`) streaming codec engine.
///
/// Utilizes AppleArchive framework with LZFSE hardware acceleration.
public final class NativeAppleArchiveEngine: Sendable {
    public static let shared = NativeAppleArchiveEngine()
    
    private init() {}

    private func makeKeySet() -> ArchiveHeader.FieldKeySet {
        return ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLAG,MTM,CTM") ?? ArchiveHeader.FieldKeySet("TYP,PAT,DAT") ?? ArchiveHeader.FieldKeySet()
    }

    /// Stream compresses a file or directory into Apple Archive (.aar) container.
    public func compress(
        sourcePath: String,
        outputPath: String
    ) throws -> Bool {
        let srcFilePath = FilePath(sourcePath)
        let dstFilePath = FilePath(outputPath)
        
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: dstFilePath,
            mode: .writeOnly,
            options: [.create, .truncate],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            return false
        }
        defer { try? writeFileStream.close() }
        
        guard let compressStream = ArchiveByteStream.compressionStream(
            using: .lzfse,
            writingTo: writeFileStream
        ) else {
            return false
        }
        defer { try? compressStream.close() }
        
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            return false
        }
        defer { try? encodeStream.close() }
        
        let keySet = makeKeySet()
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDir) {
            if isDir.boolValue {
                try encodeStream.writeDirectoryContents(archiveFrom: srcFilePath, keySet: keySet)
            } else {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("aar_src_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }
                
                let fileName = (sourcePath as NSString).lastPathComponent
                let linkPath = tempDir.appendingPathComponent(fileName).path
                try FileManager.default.copyItem(atPath: sourcePath, toPath: linkPath)
                try encodeStream.writeDirectoryContents(archiveFrom: FilePath(tempDir.path), keySet: keySet)
            }
        }
        return true
    }

    /// Stream extracts an Apple Archive (.aar) container.
    public func extract(
        archivePath: String,
        destinationDir: String
    ) throws -> Bool {
        let srcFilePath = FilePath(archivePath)
        let dstFilePath = FilePath(destinationDir)
        
        try FileManager.default.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        
        guard let readFileStream = ArchiveByteStream.fileStream(
            path: srcFilePath,
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            return false
        }
        defer { try? readFileStream.close() }
        
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            return false
        }
        defer { try? decompressStream.close() }
        
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            return false
        }
        defer { try? decodeStream.close() }
        
        guard let extractStream = ArchiveStream.extractStream(
            extractingTo: dstFilePath,
            flags: [.ignoreOperationNotPermitted]
        ) else {
            return false
        }
        defer { try? extractStream.close() }
        
        _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        return true
    }

    /// Inspects an Apple Archive (.aar) and lists metadata entries.
    public func inspect(archivePath: String) throws -> [ArchiveEntry] {
        let srcFilePath = FilePath(archivePath)
        guard let readFileStream = ArchiveByteStream.fileStream(
            path: srcFilePath,
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            return []
        }
        defer { try? readFileStream.close() }
        
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            return []
        }
        defer { try? decompressStream.close() }
        
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            return []
        }
        defer { try? decodeStream.close() }
        
        var entries: [ArchiveEntry] = []
        while let header = try decodeStream.readHeader() {
            var path = ""
            var size: UInt64 = 0
            var isDir = false
            for field in header {
                switch field {
                case .string(let key, let str):
                    if key == ArchiveHeader.FieldKey("PAT") {
                        path = str
                    } else if key == ArchiveHeader.FieldKey("TYP") {
                        if str == "D" { isDir = true }
                    }
                case .uint(let key, let val):
                    if key == ArchiveHeader.FieldKey("DAT") {
                        size = val
                    }
                default:
                    break
                }
            }
            if !path.isEmpty && !path.hasPrefix("._") && !path.contains("/._") {
                entries.append(ArchiveEntry(
                    path: path,
                    uncompressedSize: Int64(size),
                    isDirectory: isDir || path.hasSuffix("/"),
                    detectedEncoding: "UTF-8"
                ))
            }
        }
        return entries
    }
}
