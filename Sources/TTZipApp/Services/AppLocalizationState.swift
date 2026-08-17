// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
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
    
    @Published public private(set) var currentLanguage: AppLanguage {
        didSet {
            TTZipLocalizationManager.shared.currentLanguage = currentLanguage
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.kLanguageStorageKey)
            AppKitMenuSynchronizer.shared.synchronize(language: currentLanguage)
        }
    }
    
    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.kLanguageStorageKey),
           let lang = AppLanguage(rawValue: stored) ?? AppLanguage.from(identifier: stored) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = TTZipLocalizationManager.shared.currentLanguage
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
        return String(format: formatStr, arguments: args)
    }
}
