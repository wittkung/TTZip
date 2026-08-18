// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Delegate facade dispatching parallel 7z extraction operations.
public final class SevenZipParallelExtractor: @unchecked Sendable {
    public static let shared = SevenZipParallelExtractor()
    
    private init() {}
    
    public func extract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipEngine.shared.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password
        )
    }
}
