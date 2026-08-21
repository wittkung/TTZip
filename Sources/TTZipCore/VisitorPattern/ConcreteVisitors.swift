// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Concrete Visitors Module Gateway
//
// Visitor implementations are decomposed across dedicated submodules:
// - `SecurityScannerVisitor.swift`: Security threat scanning (ZipSlip, ZipBomb, executables).
// - `FolderStatsVisitor.swift`: Hierarchical directory metrics and file type distribution.
// - `ChecksumCalculatorVisitor.swift`: Fast CRC32 & SHA-256 composite hashing.
// - `TreeRendererVisitor.swift`: Formatted ASCII tree text representation.
