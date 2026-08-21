// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Cross-platform path sanitization, normalization, and security auditing subsystem.
///
/// Fully backed by high-performance Safe Rust engine (`ttzip_rust_sanitize_path`):
/// - Zero-allocation single-pass Zip Slip directory traversal neutralization and detection
/// - Win32 reserved device name interception (`CON`, `PRN`, `AUX`, `NUL`, `COM0-9`, `LPT0-9`, `CLOCK$`, `PhysicalDrive`)
/// - Win32 trailing space and dot normalization
/// - NTFS Alternate Data Stream (ADS) identification and stripping
/// - Unicode NFC canonical normalization
/// - Win32 extended-length path formatting (`\\?\` and `\\?\UNC\`)
public enum PlatformPathSanitizer: Sendable {
    
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
                win32FormattedPath: "",
                hasTraversalAttack: false
            )
        }
        
        var rawResult = TTZipPathSanitizationResult()
        let status = path.withCString { cStr in
            ttzip_rust_sanitize_path(cStr, &rawResult)
        }
        
        guard status == TTZIP_STATUS_OK else {
            return PlatformPathNormalizationResult(
                originalPath: path,
                normalizedPath: "",
                isAbsolute: false,
                isUNCPath: false,
                isLongPath: false,
                containsWindowsReservedDeviceName: false,
                strippedAlternateDataStream: nil,
                win32FormattedPath: "",
                hasTraversalAttack: true
            )
        }
        
        let normalizedPath = withUnsafePointer(to: rawResult.normalized_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
        }
        let win32FormattedPath = withUnsafePointer(to: rawResult.win32_formatted_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
        }
        let strippedADS: String? = rawResult.has_stripped_ads ? withUnsafePointer(to: rawResult.stripped_ads) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) }
        } : nil
        
        return PlatformPathNormalizationResult(
            originalPath: path,
            normalizedPath: normalizedPath,
            isAbsolute: rawResult.is_absolute,
            isUNCPath: rawResult.is_unc,
            isLongPath: rawResult.is_long_path,
            containsWindowsReservedDeviceName: rawResult.is_windows_reserved,
            strippedAlternateDataStream: strippedADS,
            win32FormattedPath: win32FormattedPath,
            hasTraversalAttack: rawResult.has_traversal_attack
        )
    }
}
