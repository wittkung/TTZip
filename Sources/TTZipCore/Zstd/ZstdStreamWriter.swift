// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-throughput streaming writer for Zstandard (.zst) format compression.
public final class ZstdStreamWriter: @unchecked Sendable {
    public static let shared = ZstdStreamWriter()
    
    private init() {}
    
    /// Stream-compresses a file or directory into Zstandard format.
    public func compress(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        enableLDM: Bool = false,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZstdCAdapter.shared.compressFile(
            srcPath: srcPath,
            dstPath: dstPath,
            level: level,
            enableLDM: enableLDM,
            dictPath: dictPath,
            progressHandler: progressHandler
        )
    }
}
