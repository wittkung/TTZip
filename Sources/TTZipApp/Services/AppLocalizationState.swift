// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

/// Reactive state manager bridging TTZipCore's zero-I/O localization catalogs with SwiftUI views.
@MainActor
public final class AppLocalizationState: ObservableObject {
    
    public static let shared = AppLocalizationState()
    
    private static let kLanguageStorageKey = "TTZip_AppSelectedLanguage"
    private static let kByteUnitStandardStorageKey = "TTZip_ByteUnitStandard"
    
    @Published public private(set) var currentLanguage: AppLanguage {
        didSet {
            TTZipLocalizationManager.shared.currentLanguage = currentLanguage
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.kLanguageStorageKey)
            AppKitMenuSynchronizer.shared.synchronize(language: currentLanguage)
        }
    }
    
    @Published public var byteUnitStandard: ByteSizeStandard {
        didSet {
            UserDefaults.standard.set(byteUnitStandard == .metricSI ? "metricSI" : "binaryIEC", forKey: Self.kByteUnitStandardStorageKey)
        }
    }
    
    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.kLanguageStorageKey),
           let lang = AppLanguage(rawValue: stored) ?? AppLanguage.from(identifier: stored) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = TTZipLocalizationManager.shared.currentLanguage
        }
        
        let storedUnit = UserDefaults.standard.string(forKey: Self.kByteUnitStandardStorageKey)
        if storedUnit == "binaryIEC" {
            self.byteUnitStandard = .binaryIEC
        } else {
            self.byteUnitStandard = .metricSI
        }
        
        TTZipLocalizationManager.shared.currentLanguage = self.currentLanguage
    }
    
    /// Switches the application's active language dynamically in real time (< 10ms).
    public func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        self.currentLanguage = language
        self.objectWillChange.send()
    }
    
    /// Resolves a localized string for the specified key in the current language.
    public func t(_ key: any LocaleKeyProtocol) -> String {
        return TTZipLocalizationManager.shared.string(for: key)
    }
    
    /// Resolves a formatted localized string with positional arguments.
    public func format(_ key: any LocaleKeyProtocol, _ args: CVarArg...) -> String {
        let formatStr = TTZipLocalizationManager.shared.string(for: key)
        return String(format: formatStr, locale: Locale(identifier: currentLanguage.bcp47), arguments: args)
    }
    
    /// Formats a byte count into localized string using the active ByteSizeStandard.
    public func formatBytes(_ bytes: Int64, standard: ByteSizeStandard? = nil) -> String {
        let targetStandard = standard ?? self.byteUnitStandard
        return ByteSizeFormatter.format(bytes: bytes, style: targetStandard, language: currentLanguage)
    }
    
    /// Formats throughput rate into localized string (e.g. "1250.5 MB/s").
    public func formatThroughput(_ mbPerSec: Double) -> String {
        return ThroughputFormatter.format(mbPerSec: mbPerSec, language: currentLanguage)
    }
    
    /// Formats a fraction (e.g. 0.425) into localized percentage string (e.g. "42.5%").
    public func formatPercent(_ fraction: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale(identifier: currentLanguage.bcp47)
        return formatter.string(from: NSNumber(value: fraction)) ?? String(format: "%.1f%%", fraction * 100.0)
    }
    
    /// Formats a date into a localized long date string.
    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: currentLanguage.bcp47)
        return formatter.string(from: date)
    }
    
    /// Evaluates plural category and returns formatted string.
    public func plural(key: any LocaleKeyProtocol, count: Int) -> String {
        let template = t(key)
        return String(format: template, locale: Locale(identifier: currentLanguage.bcp47), count)
    }
}
