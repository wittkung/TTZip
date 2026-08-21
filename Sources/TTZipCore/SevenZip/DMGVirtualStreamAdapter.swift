// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance adapter for Apple UDIF DMG extraction.
public final class DMGVirtualStreamAdapter: Sendable {
    public static let shared = DMGVirtualStreamAdapter()
    
    private init() {}
    
    /// Probes if the target archive is an Apple UDIF DMG file.
    public func isUDIFDmg(at archivePath: String) -> Bool {
        return archivePath.lowercased().hasSuffix(".dmg")
    }
    
    /// Extracts an Apple DMG directly into target destination directory.
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true
    ) throws -> Bool {
        let extractor = ArchiveExtractor()
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: skipMacJunk ? .defaultClean : .preserveAll,
            password: password
        )
        return true
    }
}
