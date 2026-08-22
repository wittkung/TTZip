// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension ArchiveExtractor {
    /// Dispatches format-specific fast-path extraction pipelines directly via Rust microkernel C-ABI.
    internal func dispatchFastExtraction(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) -> Bool {
        let fmt = ArchiveCompressionFormat.from(extensionOrName: archivePath)
        if fmt == .sevenZip || archivePath.lowercased().contains(".7z") {
            if let ok = try? SevenZipCAdapter.shared.extractArchive(
                archivePath: archivePath,
                destinationDir: destinationDir,
                skipMacJunk: options.skipMacJunk,
                password: password
            ), ok {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }

        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let status = CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
            CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                CUnsafeBufferAdapter.withCString(pwd) { pPtr in
                    guard let aPtr = aPtr, let dPtr = dPtr else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    var opt = TTZipExtractOptions(
                        destination_path: dPtr,
                        password: pPtr,
                        thread_budget: 0,
                        overwrite_existing: true,
                        preserve_permissions: true,
                        dry_run: false,
                        progress_callback: nil,
                        user_data: nil
                    )
                    return ttzip_rust_archive_extract_unified(aPtr, dPtr, &opt)
                }
            }
        }

        let items = ((try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []).filter { $0 != ".noindex" && $0 != ".DS_Store" && !$0.hasPrefix("._") }
        if status == TTZIP_STATUS_OK && !items.isEmpty {
            Self.cleanupQuarantineAttributes(at: destinationDir)
            return true
        }

        return false
    }
}
