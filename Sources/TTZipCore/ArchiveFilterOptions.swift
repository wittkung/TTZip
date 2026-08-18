// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Filter and entry exclusion rules for archive creation and extraction.
public struct ArchiveFilterOptions: Sendable, Equatable {
    /// Glob patterns to exclude.
    public var excludePatterns: [String]
    /// Glob patterns to include exclusively.
    public var includePatterns: [String]
    /// Number of leading path directory components to strip on extraction.
    public var stripComponents: Int
    /// Automatically ignore VCS repository metadata (`.git`, `.svn`, `.hg`).
    public var excludeVCS: Bool
    /// Automatically exclude AppleDouble (`._*`) and `.DS_Store` metadata artifacts.
    public var noMacMetadata: Bool
    /// Extract files directly into destination root without creating directories.
    public var flattenPaths: Bool
    /// Path to file containing newline or NUL-separated path list.
    public var filesFromPath: String?
    /// Whether `--files-from` list uses NUL delimiter (`\0`).
    public var nullDelimiter: Bool
    
    // MARK: - Backwards Compatibility Aliases
    public var skipMacJunk: Bool {
        get { noMacMetadata }
        set { noMacMetadata = newValue }
    }
    
    public var skipGitDirectory: Bool {
        get { excludeVCS }
        set { excludeVCS = newValue }
    }
    
    public var customIgnorePatterns: [String] {
        get { excludePatterns }
        set { excludePatterns = newValue }
    }
    
    public init(
        excludePatterns: [String] = [],
        includePatterns: [String] = [],
        stripComponents: Int = 0,
        excludeVCS: Bool = false,
        noMacMetadata: Bool = true,
        flattenPaths: Bool = false,
        filesFromPath: String? = nil,
        nullDelimiter: Bool = false
    ) {
        self.excludePatterns = excludePatterns
        self.includePatterns = includePatterns
        self.stripComponents = stripComponents
        self.excludeVCS = excludeVCS
        self.noMacMetadata = noMacMetadata
        self.flattenPaths = flattenPaths
        self.filesFromPath = filesFromPath
        self.nullDelimiter = nullDelimiter
    }
    
    public init(
        skipMacJunk: Bool = true,
        skipGitDirectory: Bool = false,
        customIgnorePatterns: [String] = []
    ) {
        self.excludePatterns = customIgnorePatterns
        self.includePatterns = []
        self.stripComponents = 0
        self.excludeVCS = skipGitDirectory
        self.noMacMetadata = skipMacJunk
        self.flattenPaths = false
        self.filesFromPath = nil
        self.nullDelimiter = false
    }
    
    public static let defaultClean = ArchiveFilterOptions(excludePatterns: [], includePatterns: [], stripComponents: 0, excludeVCS: false, noMacMetadata: true)
    public static let preserveAll = ArchiveFilterOptions(excludePatterns: [], includePatterns: [], stripComponents: 0, excludeVCS: false, noMacMetadata: false)
    
    /// Returns true if the entry path represents macOS or Windows system metadata artifacts.
    public static func isSystemMetadata(path: String) -> Bool {
        var normalized = path.replacingOccurrences(of: "\\", with: "/")
        while normalized.hasPrefix("./") {
            normalized.removeFirst(2)
        }
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalized == "__MACOSX" || normalized.hasPrefix("__MACOSX/") {
            return true
        }
        let fileName = (normalized as NSString).lastPathComponent
        if fileName.hasPrefix("._") || fileName == ".DS_Store" || fileName == ".localized" || fileName == ".VolumeIcon.icns" {
            return true
        }
        if fileName.hasPrefix(".Spotlight-V100") || fileName.hasPrefix(".Trashes") || fileName.hasPrefix(".fseventsd") || fileName.hasPrefix(".TemporaryItems") || fileName.hasPrefix("PaxHeader") {
            return true
        }
        if fileName.caseInsensitiveCompare("Thumbs.db") == .orderedSame || fileName.caseInsensitiveCompare("desktop.ini") == .orderedSame || fileName.caseInsensitiveCompare("ehthumbs.db") == .orderedSame {
            return true
        }
        return false
    }
}



// MARK: - PrototypeCopyable Prototype Pattern Extension
extension ArchiveFilterOptions: PrototypeCopyable {
    /// Creates an independent snapshot clone of this configuration.
    public func clone() -> ArchiveFilterOptions {
        return clone(mutate: { _ in })
    }
    
    /// Prototype copy with inout mutation closure.
    /// - Parameter mutate: Mutation block applied to the clone.
    /// - Returns: Mutated independent snapshot.
    public func clone(mutate: (inout ArchiveFilterOptions) -> Void = { _ in }) -> ArchiveFilterOptions {
        var copy = self
        mutate(&copy)
        return copy
    }
}
