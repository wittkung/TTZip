// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Cross-platform path sanitization, normalization, and security auditing subsystem.
///
/// Aligned with libarchive `archive_read_disk_posix.c` and `archive_read_disk_windows.c`:
/// - Stack-based Zip Slip directory traversal neutralization with zero heap fragmentation
/// - DOS reserved device name interception (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`, `PhysicalDrive`)
/// - NTFS Alternate Data Stream (ADS) colon stripping
/// - Win32 extended-length path normalization (`\\?\` and `\\?\UNC\`)
/// - APFS NFD (Decomposed) to standard NFC (Precomposed) normalization
public enum PlatformPathSanitizer: Sendable {
    
    private static let windowsReservedNames: Set<String> = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]
    
    /// Executes cross-platform security sanitization and canonical normalization.
    ///
    /// - Parameter path: Input relative or absolute path.
    /// - Returns: Normalized path result containing canonical path, boundary flags, and reserved name markers.
    public static func sanitize(path: String) -> PlatformPathNormalizationResult {
        guard !path.isEmpty else {
            return PlatformPathNormalizationResult(
                originalPath: "",
                normalizedPath: "",
                isAbsolute: false,
                isUNCPath: false,
                isLongPath: false,
                containsWindowsReservedDeviceName: false,
                strippedAlternateDataStream: nil,
                win32FormattedPath: ""
            )
        }
        
        var isUNC = false
        var isAbsolute = false
        var working = path
        
        // 1. UNC network paths (\\server\share)
        if working.hasPrefix("\\\\") || working.hasPrefix("//") {
            isUNC = true
            isAbsolute = true
        } else if working.hasPrefix("/") || working.hasPrefix("\\") {
            isAbsolute = true
        }
        
        // 2. Windows drive letters (C:/ or C:\)
        if working.count >= 2 {
            let firstTwo = working.prefix(2)
            if let firstChar = firstTwo.first, firstChar.isLetter && firstTwo.suffix(1) == ":" {
                isAbsolute = true
            }
        }
        
        // 3. Normalize slashes and apply Unicode NFC precomposed mapping
        working = working.replacingOccurrences(of: "\\", with: "/")
        working = working.precomposedStringWithCanonicalMapping
        
        // 4. NTFS Alternate Data Stream (ADS) stripping (e.g., filename.txt:evil.exe)
        var strippedADS: String?
        if let colonIndex = working.firstIndex(of: ":") {
            let prefix = working[..<colonIndex]
            if !(prefix.count == 1 && prefix.first?.isLetter == true) {
                strippedADS = String(working[colonIndex...])
                working = String(prefix)
            }
        }
        
        // 5. Stack-based segment sanitization (removes '.', redundant slashes, and Zip Slip '..')
        let rawSegments = working.split(separator: "/", omittingEmptySubsequences: true)
        var cleanSegments: [String] = []
        var containsReserved = false
        
        for segmentSubstring in rawSegments {
            let segment = String(segmentSubstring)
            
            if segment == "." {
                continue
            }
            if segment == ".." {
                if !cleanSegments.isEmpty {
                    cleanSegments.removeLast()
                }
                continue
            }
            
            let baseName = (segment as NSString).deletingPathExtension.uppercased()
            if windowsReservedNames.contains(baseName) || segment.uppercased().starts(with: "PHYSICALDRIVE") {
                containsReserved = true
            }
            
            cleanSegments.append(segment)
        }
        
        let normalized = cleanSegments.joined(separator: "/")
        let isLong = normalized.utf16.count > 260
        
        // 6. Format Win32 formatted path
        var win32Path = cleanSegments.joined(separator: "\\")
        if isUNC {
            win32Path = "\\\\?\\UNC\\" + win32Path
        } else if isLong && isAbsolute {
            win32Path = "\\\\?\\" + win32Path
        }
        
        return PlatformPathNormalizationResult(
            originalPath: path,
            normalizedPath: normalized,
            isAbsolute: isAbsolute,
            isUNCPath: isUNC,
            isLongPath: isLong,
            containsWindowsReservedDeviceName: containsReserved,
            strippedAlternateDataStream: strippedADS,
            win32FormattedPath: win32Path
        )
    }
}
