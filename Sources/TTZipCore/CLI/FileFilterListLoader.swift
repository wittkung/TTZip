// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Asynchronous chunked file filter list and manifest loader.
///
/// Reads newline or NUL-delimited file path lists from disk files or standard input (`-`),
/// automatically filtering comment lines starting with `#` and empty strings.
public enum FileFilterListLoader: Sendable {
    
    /// Loads an array of filesystem paths from a manifest file or standard input.
    /// - Parameters:
    ///   - filePath: Path to file on disk, or `"-"` for standard input.
    ///   - nullDelimiter: Whether paths are separated by NUL byte (`\0`) instead of newline (`\n`).
    /// - Returns: Array of trimmed, non-empty path strings.
    /// - Throws: `NSError` if the file cannot be opened or read.
    public static func loadPaths(from filePath: String, nullDelimiter: Bool = false) async throws -> [String] {
        let trimmedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return [] }
        
        let handle: FileHandle
        let shouldClose: Bool
        
        if StreamPipeAdapter.isStandardStream(trimmedPath) {
            handle = FileHandle.standardInput
            shouldClose = false
        } else {
            guard FileManager.default.fileExists(atPath: trimmedPath) else {
                throw NSError(
                    domain: "TTZipFileFilterList",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Filter manifest file not found: \(trimmedPath)"]
                )
            }
            guard let fileHandle = FileHandle(forReadingAtPath: trimmedPath) else {
                throw NSError(
                    domain: "TTZipFileFilterList",
                    code: 13,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot open filter manifest file: \(trimmedPath)"]
                )
            }
            handle = fileHandle
            shouldClose = true
        }
        
        defer {
            if shouldClose {
                try? handle.close()
            }
        }
        
        var results: [String] = []
        results.reserveCapacity(512)
        
        if nullDelimiter {
            // NUL-delimited chunk parsing
            let data = handle.readDataToEndOfFile()
            let paths = data.split(separator: 0).compactMap { chunk -> String? in
                guard !chunk.isEmpty else { return nil }
                return String(data: Data(chunk), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            return paths
        } else {
            // Streaming line-by-line parsing
            for try await line in handle.bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Ignore empty lines and comment lines prefixed with '#'
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                results.append(trimmed)
            }
        }
        
        return results
    }
}
