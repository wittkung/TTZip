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
    ///
    /// - Parameters:
    ///   - pattern: Wildcard glob pattern (supporting `*`, `?`, `[...]`, `[!...]`).
    ///   - path: Relative or absolute path to test.
    ///   - caseSensitive: Case sensitivity flag (default `true`).
    /// - Returns: True if matching, false otherwise.
    public static func matches(pattern: String, path: String, caseSensitive: Bool = true) -> Bool {
        guard !pattern.isEmpty else { return path.isEmpty }
        guard !path.isEmpty else { return pattern == "*" }
        
        // 1. Wildcard short-circuit
        if pattern == "*" {
            return true
        }
        
        // 2. Exact match short-circuit
        if caseSensitive {
            if pattern == path { return true }
        } else {
            if pattern.caseInsensitiveCompare(path) == .orderedSame { return true }
        }
        
        // 3. Fast path for suffix patterns (*.ext)
        if pattern.hasPrefix("*.") {
            let suffixPart = pattern.dropFirst()
            if !suffixPart.dropFirst().contains(where: { $0 == "*" || $0 == "?" || $0 == "[" || $0 == "/" || $0 == "\\" }) {
                let suffixStr = String(suffixPart)
                if caseSensitive {
                    if path.hasSuffix(suffixStr) { return true }
                } else {
                    if path.lowercased().hasSuffix(suffixStr.lowercased()) { return true }
                }
            }
        }
        
        let caseFlags: Int32 = caseSensitive ? 0 : FNM_CASEFOLD
        
        // 4. Root anchored pattern (e.g. "/build/*")
        if pattern.hasPrefix("/") {
            let trimmedPattern = String(pattern.drop(while: { $0 == "/" }))
            let trimmedPath = String(path.drop(while: { $0 == "/" }))
            return invokeFnmatch(pattern: trimmedPattern, path: trimmedPath, flags: FNM_PATHNAME | caseFlags)
        }
        
        // 5. Hierarchical path pattern (e.g. "src/*.swift" or "docs/api/*")
        if pattern.contains("/") {
            let trimmedPath = String(path.drop(while: { $0 == "/" }))
            
            if pattern.hasPrefix("**/") {
                let subPattern = String(pattern.dropFirst(3))
                if !subPattern.contains("/") {
                    if matches(pattern: subPattern, path: path, caseSensitive: caseSensitive) {
                        return true
                    }
                }
            }
            
            if pattern.hasSuffix("/**") {
                let prefix = String(pattern.dropLast(3))
                let cleanPrefix = prefix.hasPrefix("/") ? String(prefix.dropFirst()) : prefix
                if trimmedPath.hasPrefix(cleanPrefix + "/") || trimmedPath == cleanPrefix {
                    return true
                }
            }
            
            return invokeFnmatch(pattern: pattern, path: trimmedPath, flags: FNM_PATHNAME | caseFlags)
        }
        
        // 6. Basename and intermediate component matching
        let lastComponent = (path as NSString).lastPathComponent
        if invokeFnmatch(pattern: pattern, path: lastComponent, flags: caseFlags) {
            return true
        }
        
        let components = path.split(separator: "/")
        for comp in components {
            let compStr = String(comp)
            if invokeFnmatch(pattern: pattern, path: compStr, flags: caseFlags) {
                return true
            }
        }
        
        return invokeFnmatch(pattern: pattern, path: path, flags: caseFlags)
    }
    
    // MARK: - Metadata Evaluation Decisions
    
    /// Checks if path matches VCS metadata.
    public static func isVCSMetadata(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let last = (path as NSString).lastPathComponent
        if vcsDirectoryNames.contains(last) || vcsFileNames.contains(last) {
            return true
        }
        let components = path.split(separator: "/")
        for comp in components {
            let compStr = String(comp)
            if vcsDirectoryNames.contains(compStr) || vcsFileNames.contains(compStr) {
                return true
            }
        }
        return false
    }
    
    /// Checks if path matches OS temporary junk or metadata files.
    public static func isMacMetadata(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let last = (path as NSString).lastPathComponent
        if macMetadataNames.contains(last) || last.hasPrefix("._") {
            return true
        }
        let components = path.split(separator: "/")
        for comp in components {
            let compStr = String(comp)
            if compStr == "__MACOSX" || compStr == ".Spotlight-V100" || compStr == ".Trashes" || compStr == ".fseventsd" || compStr == ".TemporaryItems" || compStr.hasPrefix("._") {
                return true
            }
        }
        return false
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
    
    // MARK: - C fnmatch invocation
    
    private static func invokeFnmatch(pattern: String, path: String, flags: Int32) -> Bool {
        return pattern.withCString { p in
            path.withCString { s in
                fnmatch(p, s, flags) == 0
            }
        }
    }
}
