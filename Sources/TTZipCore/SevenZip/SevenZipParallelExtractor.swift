// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Fast parallel 7z extraction facade directly interfacing with native C/Rust engine.
public final class SevenZipParallelExtractor: Sendable {
    public static let shared = SevenZipParallelExtractor()
    
    private init() {}
    
    /// Extracts 7z archive directly via `SevenZipCAdapter`.
    @inline(__always)
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipCAdapter.shared.extractArchive(
            archivePath: archivePath,
            destinationDir: destinationDir,
            skipMacJunk: skipMacJunk,
            password: password
        )
    }
}
