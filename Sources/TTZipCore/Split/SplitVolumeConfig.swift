// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Predefined media size presets for split volume generation.
public enum VolumePreset: String, Sendable, Codable, CaseIterable {
    case cd700MB = "cd_700mb"
    case dvd4700MB = "dvd_4700mb"
    case fat32_4GB = "fat32_4gb"
    case email25MB = "email_25mb"
    case wechat100MB = "wechat_100mb"
    case custom = "custom"
}

/// Volume naming conventions for spanned archives.
public enum VolumeNamingPattern: String, Sendable, Codable, CaseIterable {
    case numberedExtension = "numbered_extension" // .7z.001, .zip.001, .tar.001
    case pkzipSpanned = "pkzip_spanned"           // .z01, .z02, .zip
    case rawSplit = "raw_split"                   // .001, .002
}

/// Configuration for creating multi-volume / split archives.
public struct SplitVolumeConfig: Sendable, Codable, Equatable {
    public let volumeSizeBytes: Int64
    public let preset: VolumePreset
    public let namingPattern: VolumeNamingPattern
    public let cleanOnFailure: Bool

    public init(
        volumeSizeBytes: Int64,
        preset: VolumePreset = .custom,
        namingPattern: VolumeNamingPattern = .numberedExtension,
        cleanOnFailure: Bool = true
    ) {
        self.volumeSizeBytes = volumeSizeBytes
        self.preset = preset
        self.namingPattern = namingPattern
        self.cleanOnFailure = cleanOnFailure
    }
}
