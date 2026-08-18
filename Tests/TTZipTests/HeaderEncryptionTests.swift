// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class HeaderEncryptionTests: XCTestCase {
    
    func testTouchIDAuthenticatorAPI() {
        let auth = TouchIDAuthenticator.shared
        // On simulator/headless CI, this safely returns false or true depending on hardware availability without crashing
        _ = auth.canEvaluateBiometrics()
        XCTAssertNotNil(auth)
    }
    
    func testArchiveEncryptionTierEnum() {
        let headerTier = ArchiveEncryptionTier.headerAndData
        let dataTier = ArchiveEncryptionTier.dataOnly
        let noneTier = ArchiveEncryptionTier.none
        
        XCTAssertNotEqual(headerTier, dataTier)
        XCTAssertNotEqual(headerTier, noneTier)
        XCTAssertNotEqual(dataTier, noneTier)
    }
    
    func testArchiveErrorPasswordRequiredDetailed() {
        let errHeader = ArchiveError.passwordRequiredDetailed(archivePath: "/path/to/archive.7z", tier: .headerAndData)
        XCTAssertTrue(errHeader.localizedDescription.contains("header and entries are encrypted"))
        
        let errData = ArchiveError.passwordRequiredDetailed(archivePath: "/path/to/archive.zip", tier: .dataOnly)
        XCTAssertTrue(errData.localizedDescription.contains("payload data is encrypted"))
    }
}
