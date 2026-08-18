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

        // 1. 7Z / DMG / ISO / Split Volume (.001)
        if targetFormat == .sevenZip || targetFormat == .dmg || targetFormat == .iso || ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { pathLower.hasSuffix($0) }) || pathLower.contains(".7z.") {
            if let ok = try? SevenZipEngine.shared.extract(archivePath: archivePath, destinationDir: destinationDir, password: password), ok {
                return true
            }
        }

        // 2. TAR.ZST / ZSTD in-process C Direct decompression
        if targetFormat == .tarZst || targetFormat == .zst || pathLower.hasSuffix(".tar.zst") || pathLower.hasSuffix(".tzst") || pathLower.hasSuffix(".zst") {
            let status = ttzip_extract_tar_zstd_direct_c(archivePath, destinationDir, options.skipMacJunk)
            if status == 0 {
                let items = (try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []
                if !items.isEmpty {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return true
                }
            }
            if extractZstdNative(archivePath: archivePath, destinationDir: destinationDir, options: options, password: password, advancedOptions: advancedOptions) {
                return true
            }
        }

        // 3. TAR derivatives and uncompressed TAR extraction
        if targetFormat == .tar || targetFormat == .tarGz || targetFormat == .tarBz2 || targetFormat == .tarXz || ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { pathLower.hasSuffix($0) }) {
            let status = ttzip_extract_archive_advanced(archivePath, destinationDir, options.skipMacJunk, password)
            if status == 0 {
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
        
        // 5. WIM archive extraction
        if targetFormat == .wim || pathLower.hasSuffix(".wim") {
            let status = ttzip_extract_archive_advanced(archivePath, destinationDir, options.skipMacJunk, password)
            if status == 0 {
                Self.cleanupQuarantineAttributes(at: destinationDir)
                return true
            }
        }

        // 6. ZIP in-process multi-threaded extraction
        // 🔒 API CONTRACT: ZIP Parallel Decompression Engine Route (mmap + libdeflate + NEON SIMD)
        // SEE: .agents/rules/zip-engine-freeze.md
        if targetFormat == .zip || pathLower.hasSuffix(".zip") {
            if ttzip_extract_zip_c_parallel(archivePath, destinationDir, options.skipMacJunk, password) == 0 {
                if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return true
                }
            }
            let status = ttzip_extract_archive_advanced(archivePath, destinationDir, options.skipMacJunk, password)
            if status == 0 {
                if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
                    Self.cleanupQuarantineAttributes(at: destinationDir)
                    return true
                }
            }
        }

        return false
    }

    private func extractZstdNative(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions?
    ) -> Bool {
        if ttzip_extract_archive_advanced(archivePath, destinationDir, options.skipMacJunk, password) == 0 {
            if let items = try? FileManager.default.contentsOfDirectory(atPath: destinationDir), !items.isEmpty {
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
            if targetName.lowercased().hasSuffix(".tar") || ttzip_extract_archive_advanced(outPath, destinationDir, options.skipMacJunk, password) == 0 {
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
            _ = ttzip_extract_archive_advanced(tarPath, destinationDir, options.skipMacJunk, password)
            try? FileManager.default.removeItem(atPath: tarPath)
        }
        return true
    }
}
