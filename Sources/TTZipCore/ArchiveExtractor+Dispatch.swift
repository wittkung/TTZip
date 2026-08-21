// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension ArchiveExtractor {
    
    /// Dispatches format-specific fast-path extraction pipelines (100% in-process C engines).
    internal func dispatchFastExtraction(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) -> Bool {
        let pathLower = archivePath.lowercased()

        // 1. Apple DMG (UDIF with LZFSE / ZLIB / RAW / LZMA chunks)
        if targetFormat == .dmg || pathLower.hasSuffix(".dmg") {
            if extractWithRust(archivePath: archivePath, destinationDir: destinationDir, password: password) {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }

        // 1.1 7Z / ISO / Split Volume (.001) / Generic container fallback
        if targetFormat == .sevenZip || targetFormat == .iso || ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { pathLower.hasSuffix($0) }) || pathLower.contains(".7z.") {
            if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: password), ok {
                return true
            }
        }

        // 2. TAR.ZST / ZSTD in-process decompression
        if targetFormat == .tarZst || targetFormat == .zst || pathLower.hasSuffix(".tar.zst") || pathLower.hasSuffix(".tzst") || pathLower.hasSuffix(".zst") {
            if extractWithRust(archivePath: archivePath, destinationDir: destinationDir, password: password) {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
            if extractZstdNative(archivePath: archivePath, destinationDir: destinationDir, options: options, password: password, advancedOptions: advancedOptions) {
                return true
            }
        }

        // 3. TAR derivatives and uncompressed TAR extraction
        if targetFormat == .tar || targetFormat == .tarGz || targetFormat == .tarBz2 || targetFormat == .tarXz || ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { pathLower.hasSuffix($0) }) {
            if extractWithRust(archivePath: archivePath, destinationDir: destinationDir, password: password) {
                if unpackNestedTarFiles(destinationDir: destinationDir, options: options, password: password) {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return true
                }
            }
        }

        // 4. Apple Archive (AAR) streaming decompression
        if targetFormat == .aar || pathLower.hasSuffix(".aar") {
            if let ok = try? NativeAppleArchiveEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir), ok {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }
        
        // 4.1 Brotli (.br / .brotli / .tar.br) native decompression
        if targetFormat == .brotli || pathLower.hasSuffix(".br") || pathLower.hasSuffix(".brotli") || pathLower.contains(".tar.br") {
            if let ok = try? NativeBrotliEngine.shared.extractArchive(archivePath: archivePath, destinationDir: destinationDir, skipMacJunk: options.skipMacJunk), ok {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }
        
        // 5. WIM archive extraction
        if targetFormat == .wim || pathLower.hasSuffix(".wim") {
            if extractWithRust(archivePath: archivePath, destinationDir: destinationDir, password: password) {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }

        // 6. ZIP in-process multi-threaded extraction
        if targetFormat == .zip || pathLower.hasSuffix(".zip") {
            if extractWithRust(archivePath: archivePath, destinationDir: destinationDir, password: password) {
                let items = ((try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []).filter { $0 != ".noindex" && $0 != ".DS_Store" && !$0.hasPrefix("._") }
                if !items.isEmpty {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return true
                }
            }
            if let ok = try? SevenZipCAdapter.shared.extractArchive(archivePath: archivePath, destinationDir: destinationDir, skipMacJunk: options.skipMacJunk, password: password), ok {
                let items = ((try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []).filter { $0 != ".noindex" && $0 != ".DS_Store" && !$0.hasPrefix("._") }
                if !items.isEmpty {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return true
                }
            }
        }

        return false
    }

    private func extractWithRust(archivePath: String, destinationDir: String, password: String?) -> Bool {
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        return CUnsafeBufferAdapter.withCString(archivePath) { aPtr in
            CUnsafeBufferAdapter.withCString(destinationDir) { dPtr in
                CUnsafeBufferAdapter.withCString(pwd) { pPtr in
                    guard let aPtr = aPtr, let dPtr = dPtr else { return false }
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
                    return ttzip_rust_extract_archive(aPtr, dPtr, &opt) == TTZIP_STATUS_OK
                }
            }
        }
    }

    private func extractZstdNative(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions?
    ) -> Bool {
        if extractWithRust(archivePath: archivePath, destinationDir: destinationDir, password: password) {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
            if !items.isEmpty {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }
        
        let archiveUrl = URL(fileURLWithPath: archivePath)
        var targetName = archiveUrl.deletingPathExtension().lastPathComponent
        if targetName.isEmpty || targetName.hasPrefix("arc_") {
            targetName = "decompressed_file"
        }
        let outPath = (destinationDir as NSString).appendingPathComponent(targetName)
        if let ok = try? NativeZstdEngine.shared.decompressFile(srcPath: archivePath, dstPath: outPath, dictPath: advancedOptions?.zstdOptions.zstdDictPath, progressHandler: nil), ok {
            if targetName.lowercased().hasSuffix(".tar") || extractWithRust(archivePath: outPath, destinationDir: destinationDir, password: password) {
                try? FileManager.default.removeItem(atPath: outPath)
            }
            Self.cleanupQuarantineAttributes(at: destinationDir)
            return true
        }
        return false
    }

    internal func unpackNestedTarFiles(destinationDir: String, options: ArchiveFilterOptions, password: String?) -> Bool {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty else {
            return false
        }
        let tarItems = items.filter { $0.lowercased().hasSuffix(".tar") }
        for tarItem in tarItems {
            let tarPath = (destinationDir as NSString).appendingPathComponent(tarItem)
            _ = extractWithRust(archivePath: tarPath, destinationDir: destinationDir, password: password)
            try? FileManager.default.removeItem(atPath: tarPath)
        }
        return true
    }
}
