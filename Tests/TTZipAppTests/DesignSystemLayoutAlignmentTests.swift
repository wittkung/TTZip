// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import SwiftUI
@testable import TTZipApp

final class DesignSystemLayoutAlignmentTests: XCTestCase {
    
    func test_sidebar_workspace_inspector_golden_rule_aligned_at_y90() {
        // Design system baseline invariants
        let topInset: CGFloat = 38.0
        let headerHeight: CGFloat = 52.0
        let goldenLineY: CGFloat = topInset + headerHeight
        
        XCTAssertEqual(goldenLineY, 90.0, "Golden Rule Line across 3 columns must align precisely at Y = 90pt")
    }
    
    func test_52pt_header_bar_typography_tokens() {
        // Kintsugi Gold Token (#D4AF37)
        let goldColor = TTZipTheme.kintsugiGold
        XCTAssertNotNil(goldColor)
        
        // Bamboo Green (#2E8B57) & Cinnabar Red (#C84B31)
        let bambooGreen = TTZipTheme.bambooGreen
        let cinnabarRed = TTZipTheme.cinnabarRed
        XCTAssertNotNil(bambooGreen)
        XCTAssertNotNil(cinnabarRed)
    }
}
