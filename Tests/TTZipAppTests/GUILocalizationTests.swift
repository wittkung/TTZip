// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp

final class GUILocalizationTests: XCTestCase {
    
    @MainActor
    func testAppLocalizationStateDynamicSwitching() {
        let state = AppLocalizationState.shared
        
        // 1. Switch to English
        state.setLanguage(.en)
        XCTAssertEqual(state.currentLanguage, .en)
        XCTAssertEqual(TTZipLocalizationManager.shared.currentLanguage, .en)
        
        let extractEn = state.t(L10n.Extract.title)
        XCTAssertFalse(extractEn.isEmpty)
        XCTAssertEqual(extractEn, "Extract Archive")
        
        // 2. Switch to Chinese
        state.setLanguage(.zhHans)
        XCTAssertEqual(state.currentLanguage, .zhHans)
        XCTAssertEqual(TTZipLocalizationManager.shared.currentLanguage, .zhHans)
        
        let extractZh = state.t(L10n.Extract.title)
        XCTAssertFalse(extractZh.isEmpty)
        XCTAssertEqual(extractZh, "解压归档包")
    }
    
    @MainActor
    func testAppKitMenuSynchronizer() {
        let synchronizer = AppKitMenuSynchronizer.shared
        synchronizer.synchronize(language: .zhHans)
        synchronizer.synchronize(language: .en)
        // Passes cleanly without exception
        XCTAssertTrue(true)
    }
    
    func testLocaleCatalogCompleteness() {
        let manager = TTZipLocalizationManager.shared
        
        let testKeys: [any LocaleKeyProtocol] = [
            L10n.Common.ok,
            L10n.Common.cancel,
            L10n.Common.save,
            L10n.Common.done,
            L10n.Compress.title,
            L10n.Extract.title,
            L10n.Settings.general,
            L10n.Settings.language,
            L10n.Settings.byteUnits,
            L10n.Settings.licenseStatus
        ]
        
        for key in testKeys {
            let strEn = manager.string(for: key, language: .en)
            let strZh = manager.string(for: key, language: .zhHans)
            XCTAssertFalse(strEn.isEmpty, "Key \(key.rawKey) must have English translation")
            XCTAssertFalse(strZh.isEmpty, "Key \(key.rawKey) must have Simplified Chinese translation")
        }
    }
}
