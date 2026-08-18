// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension ArchiveError {
    
    /// Localized error description for the current or specified language.
    public func localizedDescription(for language: AppLanguage? = nil) -> String {
        let manager = TTZipLocalizationManager.shared
        switch self {
        case .fileNotFound:
            return manager.string(for: L10n.Errors.fileNotFound, language: language)
        case .readFailed(let code):
            let template = manager.string(for: L10n.Errors.corruptedHeader, language: language)
            return "\(template) (Code: \(code))"
        case .invalidFormat:
            return manager.string(for: L10n.Archive.unsupportedFormat, language: language)
        case .passwordRequired, .passwordRequiredDetailed:
            return manager.string(for: L10n.Archive.passwordRequired, language: language)
        case .wrongPassword:
            return manager.string(for: L10n.Archive.incorrectPassword, language: language)
        case .unsupportedEncryptionMethod(_, let method):
            let template = manager.string(for: L10n.Archive.unsupportedFormat, language: language)
            return "\(template) [\(method)]"
        case .corruptedData(_, let entryPath):
            let template = manager.string(for: L10n.Archive.corruptData, language: language)
            return "\(template): \(entryPath)"
        case .cancelled:
            return manager.string(for: L10n.Errors.operationCancelled, language: language)
        case .invalidState:
            return manager.string(for: L10n.Common.error, language: language)
        }
    }
}
