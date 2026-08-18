// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Pipeline compositor synthesizing orthogonal combinations of containers and stream filters.
public enum ArchivePipelineCompositor: Sendable {
    
    /// Composes container and stream filter into pipeline configuration.
    public static func compose(
        container: ArchiveContainerFormat,
        filter: ArchiveStreamFilter = .none
    ) -> ArchivePipelineComposition {
        let isFastPath = isFastPathSupported(container: container, filter: filter)
        let ext = formatExtension(container: container, filter: filter)
        let name = formatDisplayName(container: container, filter: filter)
        
        return ArchivePipelineComposition(
            container: container,
            filter: filter,
            supportsFastPathBypass: isFastPath,
            displayName: name,
            primaryFileExtension: ext
        )
    }
    
    /// Decomposes file path suffix into container format and stream filter.
    public static func decompose(filePath: String) -> ArchivePipelineComposition {
        let lower = filePath.lowercased()
        
        // 1. Compound extension matching
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            return compose(container: .tar, filter: .gzip)
        }
        if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".tbz") {
            return compose(container: .tar, filter: .bzip2)
        }
        if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") {
            return compose(container: .tar, filter: .xz)
        }
        if lower.hasSuffix(".tar.zst") || lower.hasSuffix(".tzst") {
            return compose(container: .tar, filter: .zstd)
        }
        if lower.hasSuffix(".tar.lz4") {
            return compose(container: .tar, filter: .lz4)
        }
        if lower.hasSuffix(".tar.br") {
            return compose(container: .tar, filter: .brotli)
        }
        if lower.hasSuffix(".tar.lz") {
            return compose(container: .tar, filter: .lzip)
        }
        if lower.hasSuffix(".tar.lrz") {
            return compose(container: .tar, filter: .lrzip)
        }
        
        // 2. Single container extension matching
        if lower.hasSuffix(".zip") || lower.hasSuffix(".zipx") {
            return compose(container: .zip, filter: .none)
        }
        if lower.hasSuffix(".7z") {
            return compose(container: .sevenZip, filter: .none)
        }
        if lower.hasSuffix(".tar") {
            return compose(container: .tar, filter: .none)
        }
        if lower.hasSuffix(".cpio") {
            return compose(container: .cpio, filter: .none)
        }
        if lower.hasSuffix(".a") || lower.hasSuffix(".ar") {
            return compose(container: .ar, filter: .none)
        }
        if lower.hasSuffix(".iso") {
            return compose(container: .iso, filter: .none)
        }
        if lower.hasSuffix(".wim") {
            return compose(container: .wim, filter: .none)
        }
        
        // 3. Raw stream filter matching
        if lower.hasSuffix(".gz") {
            return compose(container: .raw, filter: .gzip)
        }
        if lower.hasSuffix(".bz2") {
            return compose(container: .raw, filter: .bzip2)
        }
        if lower.hasSuffix(".xz") {
            return compose(container: .raw, filter: .xz)
        }
        if lower.hasSuffix(".zst") {
            return compose(container: .raw, filter: .zstd)
        }
        if lower.hasSuffix(".lz4") {
            return compose(container: .raw, filter: .lz4)
        }
        if lower.hasSuffix(".br") {
            return compose(container: .raw, filter: .brotli)
        }
        if lower.hasSuffix(".lz") {
            return compose(container: .raw, filter: .lzip)
        }
        if lower.hasSuffix(".lrz") {
            return compose(container: .raw, filter: .lrzip)
        }
        
        return compose(container: .zip, filter: .none)
    }
    
    /// Determines whether combination supports native hardware-accelerated Fast-Path bypass.
    @inlinable
    public static func isFastPathSupported(
        container: ArchiveContainerFormat,
        filter: ArchiveStreamFilter
    ) -> Bool {
        switch (container, filter) {
        case (.zip, .none):
            return true // ZipParallelExtractor / ZipParallelWriter
        case (.sevenZip, .none):
            return true // SevenZipEngine ARM NEON
        case (.tar, .zstd):
            return true // ttzip_tar_zstd_direct
        case (.tar, .none):
            return true // ttzip_create_tar_direct_c
        default:
            return false
        }
    }
    
    private static func formatExtension(container: ArchiveContainerFormat, filter: ArchiveStreamFilter) -> String {
        if container == .raw {
            return filter.filterExtension ?? "raw"
        }
        if filter == .none {
            return container.defaultExtension
        }
        return "\(container.defaultExtension).\(filter.filterExtension ?? "")"
    }
    
    private static func formatDisplayName(container: ArchiveContainerFormat, filter: ArchiveStreamFilter) -> String {
        if container == .raw {
            return (filter.filterExtension ?? "RAW").uppercased()
        }
        if filter == .none {
            return container.rawValue.uppercased()
        }
        return "\(container.rawValue.uppercased()) + \(filter.rawValue.uppercased())"
    }
}
