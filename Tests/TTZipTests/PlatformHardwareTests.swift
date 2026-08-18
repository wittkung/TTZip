// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class PlatformHardwareTests: XCTestCase {
    
    func testPlatformOperatingSystemDetection() {
        let os = PlatformOperatingSystem.current
        #if os(macOS)
        XCTAssertEqual(os, .macOS)
        XCTAssertTrue(os.isPOSIX)
        XCTAssertFalse(os.isWindows)
        #elseif os(Windows)
        XCTAssertEqual(os, .windows)
        XCTAssertTrue(os.isWindows)
        #endif
    }
    
    func testHardwareCapabilitiesDetection() {
        let caps = PlatformHardware.capabilities
        XCTAssertGreaterThan(caps.logicalCores, 0)
        XCTAssertGreaterThanOrEqual(caps.physicalPageSize, 4096)
        
        #if arch(arm64)
        XCTAssertEqual(caps.architecture, "arm64")
        XCTAssertTrue(caps.hasARMNeon)
        XCTAssertTrue(caps.hasARMCrypto)
        XCTAssertTrue(caps.hasHardwareCRC32)
        #endif
    }
    
    func testBoostThreadPriority() {
        // Verify expected invariant
        PlatformHardware.boostCurrentThreadPriority()
    }
}
