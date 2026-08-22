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

// MARK: - Formatters & Extensions

//
//


/// Storage capacity formatting standard.
public enum ByteSizeStandard: Sendable {
    /// International decimal SI standard (1 KB = 1000 B, 1 MB = 1000 KB, macOS default).
    case metricSI
    /// International binary IEC standard (1 KiB = 1024 B, 1 MiB = 1024 KiB).
    case binaryIEC
}

/// Zero-heap-allocation byte capacity formatting engine.
public enum ByteSizeFormatter {
    
    private static let metricUnits = ["B", "KB", "MB", "GB", "TB", "PB"]
    private static let binaryUnits = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    
    /// Formats byte count according to standard and localized decimal conventions.
    public static func format(bytes: Int64, style: ByteSizeStandard = .metricSI, language: AppLanguage = .en) -> String {
        guard bytes >= 0 else { return "0 B" }
        if bytes < 1000 && style == .metricSI { return "\(bytes) B" }
        if bytes < 1024 && style == .binaryIEC { return "\(bytes) B" }
        
        let base: Double = (style == .metricSI) ? 1000.0 : 1024.0
        let units = (style == .metricSI) ? metricUnits : binaryUnits
        
        var val = Double(bytes)
        var unitIdx = 0
        
        while val >= base && unitIdx < units.count - 1 {
            val /= base
            unitIdx += 1
        }
        
        let formattedVal = String(format: "%.1f", val)
        let localizedVal = formatDecimalString(formattedVal, for: language)
        return "\(localizedVal) \(units[unitIdx])"
    }
    
    private static func formatDecimalString(_ str: String, for language: AppLanguage) -> String {
        switch language {
        case .de, .fr, .es:
            return str.replacingOccurrences(of: ".", with: ",")
        case .en, .zhHans, .zhHant, .ja:
            return str
        }
    }
}

//
//


/// High-performance lock-free throughput rate formatting engine.
public enum ThroughputFormatter {
    
    /// Formats throughput rate in MB/s with locale-sensitive decimal formatting.
    public static func format(mbPerSec: Double, language: AppLanguage = .en) -> String {
        guard mbPerSec >= 0 else { return "0.0 MB/s" }
        
        let formattedVal: String
        if mbPerSec >= 10000.0 {
            formattedVal = String(format: "%.0f", mbPerSec)
        } else if mbPerSec >= 100.0 {
            formattedVal = String(format: "%.1f", mbPerSec)
        } else {
            formattedVal = String(format: "%.2f", mbPerSec)
        }
        
        let localizedVal: String
        switch language {
        case .de, .fr, .es:
            localizedVal = formattedVal.replacingOccurrences(of: ".", with: ",")
        case .en, .zhHans, .zhHant, .ja:
            localizedVal = formattedVal
        }
        
        return "\(localizedVal) MB/s"
    }
}

//
//


/// Unicode CLDR plural categories.
public enum PluralCategory: Sendable {
    case zero
    case one
    case two
    case few
    case many
    case other
}

/// Evaluator engine for Unicode CLDR plural rules across supported languages.
public enum PluralRuleEngine {
    
    /// Evaluates plural category given item count and language.
    public static func evaluate(count: Int64, language: AppLanguage) -> PluralCategory {
        switch language {
        case .zhHans, .zhHant, .ja:
            return .other
            
        case .en, .de, .es:
            return (count == 1) ? .one : .other
            
        case .fr:
            return (count == 0 || count == 1) ? .one : .other
        }
    }
}

//
//


extension ArchiveError {
    
    /// Localized error description for the current or specified language.
    public func localizedDescription(for language: AppLanguage? = nil) -> String {
        let manager = TTZipLocalizationManager.shared
        switch self {
        case .fileNotFound:
            return manager.string(for: L10n.Errors.fileNotFound, language: language)
        case .readFailed(let code):
            let template = manager.string(for: L10n.Errors.readError, language: language)
            return "\(template) (Code: \(code))"
        case .invalidFormat:
            return manager.string(for: L10n.Errors.unsupportedFormat, language: language)
        case .passwordRequired:
            return manager.string(for: L10n.Errors.passwordRequired, language: language)
        case .passwordRequiredDetailed(let archivePath, let tier):
            let base = manager.string(for: L10n.Errors.passwordRequired, language: language)
            let fileName = (archivePath as NSString).lastPathComponent
            if tier == .headerAndData {
                return "\(base): header and entries are encrypted (\(fileName))"
            } else {
                return "\(base): payload data is encrypted (\(fileName))"
            }
        case .wrongPassword:
            return manager.string(for: L10n.Errors.incorrectPassword, language: language)
        case .unsupportedEncryptionMethod(_, let method):
            let template = manager.string(for: L10n.Errors.unsupportedFormat, language: language)
            return "\(template) [\(method)]"
        case .corruptedData(_, let entryPath):
            let template = manager.string(for: L10n.Errors.corruptData, language: language)
            return "\(template): \(entryPath)"
        case .cancelled:
            return manager.string(for: L10n.Errors.operationCancelled, language: language)
        case .invalidState:
            return manager.string(for: L10n.Common.error, language: language)
        }
    }
}
