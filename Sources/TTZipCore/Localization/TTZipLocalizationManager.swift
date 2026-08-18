// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Centralized thread-safe localization manager.
public final class TTZipLocalizationManager: @unchecked Sendable {
    public static let shared = TTZipLocalizationManager()
    
    private let lock = NSLock()
    private var _currentLanguage: AppLanguage
    
    /// Current active application and CLI interaction language.
    public var currentLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLanguage
        }
        set {
            lock.lock()
            _currentLanguage = newValue
            lock.unlock()
        }
    }
    
    private init() {
        // 1. Inspect POSIX environment variables (LC_ALL / LANG)
        let env = ProcessInfo.processInfo.environment
        if let lcAll = env["LC_ALL"], let parsed = AppLanguage.from(identifier: lcAll) {
            self._currentLanguage = parsed
            return
        }
        if let lang = env["LANG"], let parsed = AppLanguage.from(identifier: lang) {
            self._currentLanguage = parsed
            return
        }
        
        // 2. Query system preferred languages
        if let preferred = Locale.preferredLanguages.first, let parsed = AppLanguage.from(identifier: preferred) {
            self._currentLanguage = parsed
            return
        }
        
        // 3. Fallback to English (en)
        self._currentLanguage = .en
    }
    
    /// Resolves localized string for a key in the target or current active language.
    public func string(for key: LocaleKeyProtocol, language: AppLanguage? = nil) -> String {
        let targetLanguage = language ?? currentLanguage
        let rawKey = key.rawKey
        
        // 1. Search in target language catalog
        if let val = catalog(for: targetLanguage)[rawKey] {
            return val
        }
        
        // 2. Cascade fallback to English (en)
        if targetLanguage != .en, let fallbackVal = LocaleCatalogEn.strings[rawKey] {
            return fallbackVal
        }
        
        // 3. Ultimate fallback: Raw Key
        return rawKey
    }
    
    /// Maps language enum to corresponding string catalog dictionary.
    private func catalog(for language: AppLanguage) -> [String: String] {
        switch language {
        case .en: return LocaleCatalogEn.strings
        case .zhHans: return LocaleCatalogZhHans.strings
        case .zhHant: return LocaleCatalogZhHant.strings
        case .ja: return LocaleCatalogJa.strings
        case .de: return LocaleCatalogDe.strings
        case .fr: return LocaleCatalogFr.strings
        case .es: return LocaleCatalogEs.strings
        }
    }
}
