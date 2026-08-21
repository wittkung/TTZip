// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Safe Rust Unified VFS Bridge.
public enum RustVfsBridge {
    
    /// Builds a native VFS tree handle from flat ArchiveEntry list.
    public static func withTreeHandle<R>(entries: [ArchiveEntry], rootName: String = "", block: (OpaquePointer) throws -> R) rethrows -> R? {
        var rawEntries: [TTZipEntryMetadata] = []
        rawEntries.reserveCapacity(entries.count)
        
        var cStrings: [ContiguousArray<CChar>] = []
        cStrings.reserveCapacity(entries.count)
        
        for entry in entries {
            let cstr = entry.path.utf8CString
            cStrings.append(cstr)
        }
        
        for (i, entry) in entries.enumerated() {
            cStrings[i].withUnsafeBufferPointer { ptr in
                let mtime = entry.modificationDate.map { Int64($0.timeIntervalSince1970) } ?? 0
                rawEntries.append(TTZipEntryMetadata(
                    path: ptr.baseAddress,
                    uncompressed_size: UInt64(max(0, entry.uncompressedSize)),
                    compressed_size: 0,
                    crc32: 0,
                    mtime_epoch_secs: mtime,
                    mode: entry.isDirectory ? 0o755 : 0o644,
                    is_directory: entry.isDirectory,
                    is_encrypted: entry.isEncrypted,
                    compression_method: 0
                ))
            }
        }
        
        let rootCStr = rootName.utf8CString
        let handle: OpaquePointer? = rootCStr.withUnsafeBufferPointer { rPtr in
            rawEntries.withUnsafeBufferPointer { ePtr in
                ttzip_rust_vfs_tree_build(ePtr.baseAddress, ePtr.count, rPtr.baseAddress)
            }
        }
        
        guard let validHandle = handle else { return nil }
        defer { ttzip_rust_vfs_tree_free(validHandle) }
        return try block(validHandle)
    }
    
    /// Renders ASCII/Unicode hierarchical tree using Safe Rust VFS engine.
    public static func renderTree(from entries: [ArchiveEntry], rootName: String = "") -> String {
        return withTreeHandle(entries: entries, rootName: rootName) { handle in
            var outPtr: UnsafeMutablePointer<CChar>? = nil
            let status = ttzip_rust_vfs_tree_render(handle, &outPtr)
            guard status == TTZIP_STATUS_OK, let ptr = outPtr else { return "" }
            defer { ttzip_rust_vfs_free_string(ptr) }
            return String(cString: ptr)
        } ?? ""
    }
    
    /// Performs fast fuzzy search against archive entries using Safe Rust VFS engine.
    public static func fuzzySearch(in entries: [ArchiveEntry], query: String) -> [ArchiveEntry] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return entries
        }
        
        let entryMap = Dictionary(entries.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        
        return withTreeHandle(entries: entries, rootName: "") { handle -> [ArchiveEntry] in
            final class SearchAccumulator {
                var matchedPaths: [String] = []
            }
            let acc = SearchAccumulator()
            let accPtr = Unmanaged.passUnretained(acc).toOpaque()
            
            let queryCStr = query.utf8CString
            _ = queryCStr.withUnsafeBufferPointer { qPtr in
                ttzip_rust_vfs_fuzzy_search(handle, qPtr.baseAddress, { resultPtr, ctx in
                    guard let resultPtr = resultPtr, let ctx = ctx else { return false }
                    let raw = resultPtr.pointee
                    if let pathC = raw.path {
                        let path = String(cString: pathC)
                        let accumulator = Unmanaged<SearchAccumulator>.fromOpaque(ctx).takeUnretainedValue()
                        accumulator.matchedPaths.append(path)
                    }
                    return true
                }, accPtr)
            }
            
            return acc.matchedPaths.compactMap { entryMap[$0] }
        } ?? []
    }
}
