// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Static utility for POSIX path normalization, shell unescaping, tilde expansion, and prefix parsing.
public enum POSIXPathSanitizer: Sendable {
    
    /// Determines whether the raw user input is intended as a filesystem path rather than a keyword search.
    public static func isPathInput(_ rawInput: String) -> Bool {
        let trimmed = rawInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") || trimmed.hasPrefix(".") || trimmed.hasPrefix("file://") {
            return true
        }
        
        if trimmed.contains("/") || trimmed.contains("\\") {
            return true
        }
        
        return false
    }
    
    public static func isPathLike(input: String) -> Bool {
        return isPathInput(input)
    }
    
    /// Normalizes and resolves a raw user input path into a canonical POSIX path.
    public static func sanitize(rawInput: String, relativeTo baseDirectory: URL? = nil) -> String {
        var trimmed = rawInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return ""
        }
        
        // Strip wrapping quotes
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2) {
            trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty else {
            return ""
        }
        
        var unescaped = trimmed
        if unescaped.hasPrefix("file://") {
            if let url = URL(string: unescaped), url.isFileURL {
                unescaped = url.path
            } else {
                let stripped = String(unescaped.dropFirst(7))
                unescaped = stripped.removingPercentEncoding ?? stripped
            }
        }
        
        unescaped = unescapeShellBackslashes(unescaped)
        unescaped = expandTilde(unescaped)
        
        let isAbsolute = unescaped.hasPrefix("/")
        let resolvedPath: String
        if isAbsolute {
            resolvedPath = unescaped
        } else {
            let base = baseDirectory?.path ?? NSHomeDirectory()
            resolvedPath = (base as NSString).appendingPathComponent(unescaped)
        }
        
        let standardized = (resolvedPath as NSString).standardizingPath
        return standardized.isEmpty ? "/" : standardized
    }
    
    public static func sanitize(input: String, relativeTo baseDirectory: URL? = nil) -> String {
        return sanitize(rawInput: input, relativeTo: baseDirectory)
    }
    
    /// Extracts the parent directory to query and the trailing prefix for real-time autocompletion.
    public static func extractParentAndPrefix(input: String, relativeTo baseDirectory: URL? = nil) -> (parentDirectory: String, prefix: String) {
        var trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            let base = baseDirectory?.path ?? NSHomeDirectory()
            return (parentDirectory: (base as NSString).standardizingPath, prefix: "")
        }
        
        // Strip outer quotes if present
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2) {
            trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty else {
            let base = baseDirectory?.path ?? NSHomeDirectory()
            return (parentDirectory: (base as NSString).standardizingPath, prefix: "")
        }
        
        var unescaped = trimmed
        if unescaped.hasPrefix("file://") {
            if let url = URL(string: unescaped), url.isFileURL {
                unescaped = url.path
            } else {
                let stripped = String(unescaped.dropFirst(7))
                unescaped = stripped.removingPercentEncoding ?? stripped
            }
        }
        
        unescaped = unescapeShellBackslashes(unescaped)
        
        // Handle standalone tilde
        if unescaped == "~" {
            return (parentDirectory: NSHomeDirectory(), prefix: "")
        }
        
        unescaped = expandTilde(unescaped)
        
        let isAbsolute = unescaped.hasPrefix("/")
        let fullPath: String
        if isAbsolute {
            fullPath = unescaped
        } else {
            let base = baseDirectory?.path ?? NSHomeDirectory()
            fullPath = (base as NSString).appendingPathComponent(unescaped)
        }
        
        if unescaped.hasSuffix("/") {
            // Trailing slash: Exploring inside this directory
            let parent = (fullPath as NSString).standardizingPath
            return (parentDirectory: parent.isEmpty ? "/" : parent, prefix: "")
        } else {
            // No trailing slash: Parent directory + matching prefix
            let parent = (fullPath as NSString).deletingLastPathComponent
            let prefix = (fullPath as NSString).lastPathComponent
            let standardizedParent = (parent as NSString).standardizingPath
            return (parentDirectory: standardizedParent.isEmpty ? "/" : standardizedParent, prefix: prefix)
        }
    }
    
    public static func extractParentAndPrefix(rawInput: String, baseDirectory: URL? = nil) -> (parentDirectory: String, prefix: String) {
        return extractParentAndPrefix(input: rawInput, relativeTo: baseDirectory)
    }
    
    // MARK: - Private Helpers
    
    private static func expandTilde(_ path: String) -> String {
        if path == "~" {
            return NSHomeDirectory()
        } else if path.hasPrefix("~/") {
            return NSHomeDirectory() + path.dropFirst(1)
        } else if path.hasPrefix("~") {
            let expanded = (path as NSString).expandingTildeInPath
            return expanded
        }
        return path
    }
    
    private static func unescapeShellBackslashes(_ path: String) -> String {
        guard path.contains("\\") else { return path }
        var result = ""
        result.reserveCapacity(path.utf8.count)
        var isEscaping = false
        for char in path {
            if isEscaping {
                result.append(char)
                isEscaping = false
            } else if char == "\\" {
                isEscaping = true
            } else {
                result.append(char)
            }
        }
        if isEscaping {
            result.append("\\")
        }
        return result
    }
}
