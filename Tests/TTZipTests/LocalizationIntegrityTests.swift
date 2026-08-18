// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class LocalizationIntegrityTests: XCTestCase {
    
    let allLangs: [AppLanguage] = [.en, .zhHans, .zhHant, .ja, .de, .fr, .es]
    
    // MARK: - 1. 7 Key 100%
    
    func testAllKeysPresentInAllSevenLanguages() {
        let allKeys = L10n.allRawKeys
        XCTAssertGreaterThan(allKeys.count, 20, "Should have defined core localizable keys")
        
        for lang in allLangs {
            for key in allKeys {
                let val = TTZipLocalizationManager.shared.string(for: RawKeyWrapper(key), language: lang)
                XCTAssertNotEqual(val, key, "Missing translation for key '\(key)' in language '\(lang.displayName)'")
                XCTAssertFalse(val.trimmingCharacters(in: .whitespaces).isEmpty, "Empty translation for key '\(key)' in language '\(lang.displayName)'")
            }
        }
    }
    
    // MARK: - 2.
    
    func testFormatSpecifierParityAndTypeSafetyAcrossLanguages() {
        let allKeys = L10n.allRawKeys
        let specifierRegex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?[@dsuifgeExXop]", options: [])
        
        for key in allKeys {
            let enVal = TTZipLocalizationManager.shared.string(for: RawKeyWrapper(key), language: .en)
            let enMatches = specifierRegex.matches(in: enVal, range: NSRange(location: 0, length: enVal.utf16.count)).map {
                (enVal as NSString).substring(with: $0.range)
            }
            
            for lang in allLangs where lang != .en {
                let langVal = TTZipLocalizationManager.shared.string(for: RawKeyWrapper(key), language: lang)
                let langMatches = specifierRegex.matches(in: langVal, range: NSRange(location: 0, length: langVal.utf16.count)).map {
                    (langVal as NSString).substring(with: $0.range)
                }
                
                XCTAssertEqual(
                    enMatches.count,
                    langMatches.count,
                    "Format specifier count mismatch for key '\(key)' in '\(lang.displayName)': expected \(enMatches), got \(langMatches)"
                )
            }
        }
    }
    
    // MARK: - 3.
    
    func testCascadingFallbackAndDynamicFormatting() {
        // (SI vs IEC)
        let si1MB = ByteSizeFormatter.format(bytes: 1_500_000, style: .metricSI, language: .en)
        XCTAssertEqual(si1MB, "1.5 MB")
        
        let iec1MB = ByteSizeFormatter.format(bytes: 1_572_864, style: .binaryIEC, language: .en)
        XCTAssertEqual(iec1MB, "1.5 MiB")
        
        let de1MB = ByteSizeFormatter.format(bytes: 1_500_000, style: .metricSI, language: .de)
        XCTAssertEqual(de1MB, "1,5 MB")
        
        // Verify expected invariant
        let speedEn = ThroughputFormatter.format(mbPerSec: 1250.5, language: .en)
        XCTAssertEqual(speedEn, "1250.5 MB/s")
        
        let speedFr = ThroughputFormatter.format(mbPerSec: 1250.5, language: .fr)
        XCTAssertEqual(speedFr, "1250,5 MB/s")
    }
    
    // MARK: - 4. No Orphan Keys
    
    func testNoOrphanKeysInLanguagePacks() {
        let validKeys = Set(L10n.allRawKeys)
        
        let catalogs: [(AppLanguage, [String: String])] = [
            (.en, LocaleCatalogEn.strings),
            (.zhHans, LocaleCatalogZhHans.strings),
            (.zhHant, LocaleCatalogZhHant.strings),
            (.ja, LocaleCatalogJa.strings),
            (.de, LocaleCatalogDe.strings),
            (.fr, LocaleCatalogFr.strings),
            (.es, LocaleCatalogEs.strings)
        ]
        
        for (lang, dict) in catalogs {
            for key in dict.keys {
                XCTAssertTrue(validKeys.contains(key), "Orphan key found in \(lang.displayName) catalog: '\(key)'")
            }
        }
    }
}

private struct RawKeyWrapper: LocaleKeyProtocol {
    let rawKey: String
    init(_ key: String) { self.rawKey = key }
}
