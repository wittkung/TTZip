// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class TTZipStatusAndRecoveryTests: XCTestCase {
    
    func testTTZipStatusHierarchy() {
        XCTAssertEqual(TTZipStatus.ok.rawValue, 0)
        XCTAssertEqual(TTZipStatus.eof.rawValue, 1)
        XCTAssertEqual(TTZipStatus.retry.rawValue, -10)
        XCTAssertEqual(TTZipStatus.warn.rawValue, -20)
        XCTAssertEqual(TTZipStatus.failed.rawValue, -25)
        XCTAssertEqual(TTZipStatus.fatal.rawValue, -30)
        
        XCTAssertTrue(TTZipStatus.fatal.isFatal)
        XCTAssertFalse(TTZipStatus.failed.isFatal)
        XCTAssertFalse(TTZipStatus.warn.isFatal)
        
        XCTAssertTrue(TTZipStatus.failed.allowsDataRecovery, "Item failure should allow data recovery state to proceed")
        XCTAssertTrue(TTZipStatus.warn.allowsDataRecovery)
        XCTAssertFalse(TTZipStatus.fatal.allowsDataRecovery)
    }
    
    func testEngineStateOptionSet() {
        var state: TTZipEngineState = .initial
        XCTAssertTrue(state.contains(.initial))
        
        state.insert(.header)
        XCTAssertTrue(state.contains(.header))
        
        state.insert(.dataRecovery)
        XCTAssertTrue(state.contains(.dataRecovery))
        XCTAssertFalse(state.contains(.fatalError))
    }
}
