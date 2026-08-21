// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit

// MARK: - Differential Manifest Scanner

/// Recursive directory scanner generating normalized `FileTreeManifest` instances.
public enum DifferentialManifestScanner: Sendable {
    
    /// Recursively scans directory and builds normalized `FileTreeManifest`.
    public static func scanDirectory(atPath path: String) throws -> FileTreeManifest {
        let rootURL = URL(fileURLWithPath: path).standardized
        let rootPath = rootURL.path
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        
        var entries: [String: ManifestEntry] = [:]
        var totalByteSize: Int64 = 0
        var totalFileCount: Int = 0
        var totalDirectoryCount: Int = 0
        var totalSymlinkCount: Int = 0
        
        func traverse(dirPath: String) throws {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            for item in contents.sorted() {
                if item == ".noindex" || item == ".DS_Store" {
                    continue
                }
                let fullPath = (dirPath as NSString).appendingPathComponent(item)
                var st = stat()
                guard lstat(fullPath, &st) == 0 else { continue }
                
                var relPath = fullPath
                if relPath.hasPrefix(rootPath) {
                    relPath = String(relPath.dropFirst(rootPath.count))
                }
                while relPath.hasPrefix("/") {
                    relPath = String(relPath.dropFirst())
                }
                let normalizedRelPath = relPath.precomposedStringWithCanonicalMapping
                
                let mode = UInt16(st.st_mode & 0o777)
                let sMode = mode_t(st.st_mode)
                
                if (sMode & S_IFMT) == S_IFLNK {
                    var linkBuf = [CChar](repeating: 0, count: Int(PATH_MAX))
                    let len = readlink(fullPath, &linkBuf, linkBuf.count - 1)
                    let target: String? = len > 0 ? String(decoding: linkBuf.prefix(Int(len)).map { UInt8(bitPattern: $0) }, as: UTF8.self) : nil
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .symbolicLink,
                        byteSize: Int64(st.st_size),
                        sha256Checksum: "",
                        posixMode: mode,
                        symlinkTarget: target
                    )
                    entries[normalizedRelPath] = entry
                    totalSymlinkCount += 1
                } else if (sMode & S_IFMT) == S_IFDIR {
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .directory,
                        byteSize: 0,
                        sha256Checksum: "",
                        posixMode: mode,
                        symlinkTarget: nil
                    )
                    entries[normalizedRelPath] = entry
                    totalDirectoryCount += 1
                    try traverse(dirPath: fullPath)
                } else {
                    let fileSize = Int64(st.st_size)
                    let checksum = computeFileSHA256(path: fullPath, size: Int(st.st_size))
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .regularFile,
                        byteSize: fileSize,
                        sha256Checksum: checksum,
                        posixMode: mode,
                        symlinkTarget: nil
                    )
                    entries[normalizedRelPath] = entry
                    totalByteSize += fileSize
                    totalFileCount += 1
                }
            }
        }
        
        try traverse(dirPath: rootPath)
        
        return FileTreeManifest(
            rootDirectory: rootPath,
            entries: entries,
            totalByteSize: totalByteSize,
            totalFileCount: totalFileCount,
            totalDirectoryCount: totalDirectoryCount,
            totalSymlinkCount: totalSymlinkCount
        )
    }
    
    // MARK: - SHA-256 Checksum Helper
    
    private static func computeFileSHA256(path: String, size: Int) -> String {
        guard size > 0 else {
            return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return "" }
        defer { close(fd) }
        
        if size < 32 * 1024 * 1024, let mapped = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
            defer { munmap(mapped, size) }
            posix_madvise(mapped, size, POSIX_MADV_WILLNEED)
            var hasher = SHA256()
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: mapped, count: size))
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }
        
        var hasher = SHA256()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var bytesRead = read(fd, buffer, bufferSize)
        while bytesRead > 0 {
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: bytesRead))
            bytesRead = read(fd, buffer, bufferSize)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
