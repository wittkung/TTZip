// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// High-performance POSIX glob wildcard matching, pattern filtering, and path component stripping engine.
public enum PathPatternFilterEngine: Sendable {
    
    // MARK: - Predefined Metadata & VCS Hash Sets
    
    /// Version control system directory names.
    public static let vcsDirectoryNames: Set<String> = [
        ".git", ".svn", ".hg", ".bzr", "CVS", "_darcs", ".hgignore"
    ]
    
    /// Version control system file names.
    public static let vcsFileNames: Set<String> = [
        ".gitignore", ".gitmodules", ".gitattributes", ".gitkeep",
        ".hgignore", ".hgtags",
        ".svnignore", ".bzrignore"
    ]
    
    /// Operating system junk files and metadata names.
    public static let macMetadataNames: Set<String> = [
        ".DS_Store", "__MACOSX", ".Spotlight-V100", ".Trashes",
        ".fseventsd", ".TemporaryItems", ".VolumeIcon.icns",
        "Thumbs.db", "$RECYCLE.BIN", "ehthumbs.db", "Desktop.ini"
    ]
    
    // MARK: - POSIX Fnmatch Wildcard Matching
    
    /// Evaluates whether path matches POSIX.2 glob pattern.
    public static func matches(pattern: String, path: String, caseSensitive: Bool = true) -> Bool {
        let flags = (caseSensitive ? 0 : FNM_CASEFOLD) | FNM_PATHNAME
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let cleanPat = pattern.hasPrefix("/") ? String(pattern.dropFirst()) : pattern
        
        // 1. Direct path / fnmatch
        if fnmatch(cleanPat, cleanPath, flags) == 0 {
            return true
        }
        if fnmatch(pattern, path, flags) == 0 {
            return true
        }
        
        // 2. Double-star glob support
        if pattern.contains("**") {
            var regexPat = "^"
            var idx = pattern.startIndex
            while idx < pattern.endIndex {
                if pattern[idx...].hasPrefix("**/") {
                    regexPat += "(?:.+/)?"
                    idx = pattern.index(idx, offsetBy: 3)
                } else if pattern[idx...].hasPrefix("/**") {
                    regexPat += "(?:/.*)?"
                    idx = pattern.index(idx, offsetBy: 3)
                } else if pattern[idx...].hasPrefix("**") {
                    regexPat += ".*"
                    idx = pattern.index(idx, offsetBy: 2)
                } else if pattern[idx] == "*" {
                    regexPat += "[^/]*"
                    idx = pattern.index(after: idx)
                } else if pattern[idx] == "?" {
                    regexPat += "[^/]"
                    idx = pattern.index(after: idx)
                } else if pattern[idx] == "." {
                    regexPat += "\\."
                    idx = pattern.index(after: idx)
                } else {
                    regexPat.append(pattern[idx])
                    idx = pattern.index(after: idx)
                }
            }
            regexPat += "$"
            if let regex = try? NSRegularExpression(pattern: regexPat, options: caseSensitive ? [] : [.caseInsensitive]) {
                let range = NSRange(location: 0, length: cleanPath.utf16.count)
                if regex.firstMatch(in: cleanPath, options: [], range: range) != nil {
                    return true
                }
                let rawRange = NSRange(location: 0, length: path.utf16.count)
                if regex.firstMatch(in: path, options: [], range: rawRange) != nil {
                    return true
                }
            }
        }
        
        // 3. Basename or component match for pattern without slashes
        if !cleanPat.contains("/") {
            let components = cleanPath.components(separatedBy: "/")
            for comp in components {
                if fnmatch(cleanPat, comp, caseSensitive ? 0 : FNM_CASEFOLD) == 0 {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Metadata Evaluation Decisions
    
    /// Checks if path matches VCS metadata.
    public static func isVCSMetadata(_ path: String) -> Bool {
        let parts = path.components(separatedBy: "/")
        return parts.contains { vcsDirectoryNames.contains($0) || vcsFileNames.contains($0) }
    }
    
    /// Checks if path matches OS temporary junk or metadata files.
    public static func isMacMetadata(_ path: String) -> Bool {
        let parts = path.components(separatedBy: "/")
        for part in parts {
            if macMetadataNames.contains(part) { return true }
            if part.hasPrefix("._") { return true }
        }
        return path.withCString { cPath in
            ttzip_rust_is_mac_junk(cPath)
        }
    }
    
    /// Evaluates whether path should be included based on exclusion/inclusion criteria.
    public static func shouldInclude(
        path: String,
        excludePatterns: [String] = [],
        includePatterns: [String] = [],
        excludeVCS: Bool = false,
        noMacMetadata: Bool = false
    ) -> Bool {
        if excludeVCS && isVCSMetadata(path) {
            return false
        }
        if noMacMetadata && isMacMetadata(path) {
            return false
        }
        if !includePatterns.isEmpty {
            let matchedInclude = includePatterns.contains { pattern in
                matches(pattern: pattern, path: path)
            }
            if !matchedInclude {
                return false
            }
            return true
        }
        if !excludePatterns.isEmpty {
            let matchedExclude = excludePatterns.contains { pattern in
                matches(pattern: pattern, path: path)
            }
            if matchedExclude {
                return false
            }
        }
        return true
    }
    
    /// Evaluates whether path should be excluded.
    public static func shouldExclude(
        path: String,
        excludePatterns: [String] = [],
        includePatterns: [String] = [],
        excludeVCS: Bool = false,
        noMacMetadata: Bool = false
    ) -> Bool {
        return !shouldInclude(
            path: path,
            excludePatterns: excludePatterns,
            includePatterns: includePatterns,
            excludeVCS: excludeVCS,
            noMacMetadata: noMacMetadata
        )
    }
    
    public static func shouldInclude(path: String, options: ArchiveFilterOptions) -> Bool {
        return shouldInclude(
            path: path,
            excludePatterns: options.excludePatterns,
            includePatterns: options.includePatterns,
            excludeVCS: options.excludeVCS,
            noMacMetadata: options.noMacMetadata
        )
    }
    
    public static func shouldExclude(path: String, options: ArchiveFilterOptions) -> Bool {
        return shouldExclude(
            path: path,
            excludePatterns: options.excludePatterns,
            includePatterns: options.includePatterns,
            excludeVCS: options.excludeVCS,
            noMacMetadata: options.noMacMetadata
        )
    }
    
    // MARK: - Leading Component Stripping
    
    /// Strips specified number of leading non-empty path components with zero intermediate heap allocations.
    ///
    /// - Parameters:
    ///   - path: Original relative or absolute path string.
    ///   - count: Count of leading directory components to strip.
    /// - Returns: Stripped path, or nil if component count is insufficient.
    public static func stripLeadingComponents(_ path: String, count: Int) -> String? {
        guard count > 0 else { return path }
        guard !path.isEmpty else { return nil }
        
        let utf8 = path.utf8
        var i = utf8.startIndex
        let end = utf8.endIndex
        
        // 1. Skip leading slashes
        while i < end && utf8[i] == UInt8(ascii: "/") {
            i = utf8.index(after: i)
        }
        
        // 2. Skip leading "./"
        if i < end && utf8[i] == UInt8(ascii: ".") {
            let next = utf8.index(after: i)
            if next < end && utf8[next] == UInt8(ascii: "/") {
                i = utf8.index(after: next)
                while i < end && utf8[i] == UInt8(ascii: "/") {
                    i = utf8.index(after: i)
                }
            }
        }
        
        var strippedCount = 0
        while strippedCount < count && i < end {
            while i < end && utf8[i] != UInt8(ascii: "/") {
                i = utf8.index(after: i)
            }
            strippedCount += 1
            while i < end && utf8[i] == UInt8(ascii: "/") {
                i = utf8.index(after: i)
            }
        }
        
        guard strippedCount == count, i < end else {
            return nil
        }
        
        let remaining = String(path[i..<end])
        return remaining.isEmpty ? nil : remaining
    }
}
