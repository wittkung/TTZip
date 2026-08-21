// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Builders Module Gateway
//
// Builder pattern definitions are decomposed across:
// - `ArchiveOptionsBuilder.swift`: Fine-grained compression, algorithm, and container parameters.
// - `ArchivePipelineBuilder.swift`: End-to-end archiving and extraction pipeline assembly.
