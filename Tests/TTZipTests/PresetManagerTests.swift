// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class PresetManagerTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        PresetManager.shared.resetToDefaults()
    }
    
    func testDefaultBuiltInPresets() {
        let presets = PresetManager.shared.presets
        XCTAssertGreaterThanOrEqual(presets.count, 4)
        
        let split20G = presets.first { $0.name.contains("20G") }
        XCTAssertNotNil(split20G)
        XCTAssertEqual(split20G?.level, .store)
        XCTAssertEqual(split20G?.splitVolumeSizeBytes, 20 * 1024 * 1024 * 1024)
        XCTAssertNil(split20G?.defaultPassword)
    }
    
    func testCustomPresetAddAndDelete() {
        let manager = PresetManager.shared
        let initialCount = manager.presets.count
        
        let custom = CompressionPreset(
            name: "7z 20G 自定义试用包",
            format: .zip,
            level: .store,
            splitVolumeSizeBytes: 20 * 1024 * 1024 * 1024,
            defaultPassword: "MyPrivatePassword123"
        )
        
        manager.savePreset(custom)
        XCTAssertEqual(manager.presets.count, initialCount + 1)
        
        let fetched = manager.presets.first { $0.id == custom.id }
        XCTAssertEqual(fetched?.name, "7z 20G 自定义试用包")
        XCTAssertEqual(fetched?.defaultPassword, "MyPrivatePassword123")
        
        manager.deletePreset(id: custom.id)
        XCTAssertEqual(manager.presets.count, initialCount)
    }
}
