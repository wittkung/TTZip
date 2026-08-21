// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Concrete Repositories Module Gateway
//
// Repository implementations are decomposed across dedicated submodules:
// - `UserDefaultsPresetRepository.swift`: Compression preset persistence via UserDefaults.
// - `KeychainPasswordRepository.swift`: Encrypted credential storage via macOS Keychain.
// - `JSONFileArchiveHistoryRepository.swift`: Execution history persistence via atomic JSON.
