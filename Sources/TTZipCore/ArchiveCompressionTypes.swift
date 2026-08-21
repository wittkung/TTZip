// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Compression Types Module Gateway
//
// This file serves as the unified types aggregation and compatibility gateway.
// Submodule definitions are decomposed across:
// - `Types/ArchiveCompressionFormat.swift`: Archive formats, extensions, MIME resolution.
// - `Types/ArchiveCompressionOptions.swift`: Compression levels, format options, advanced configurations.
// - `Types/ArchiveEntryMetadata.swift`: Structured entry-level metadata models.

/// Common typealiases for compression and archive specifications.
public typealias CompressionFormat = ArchiveCompressionFormat
public typealias CompressionLevel = ArchiveCompressionLevel
public typealias CompressionOptions = ArchiveAdvancedOptions
public typealias EntryMetadata = ArchiveEntryMetadata
