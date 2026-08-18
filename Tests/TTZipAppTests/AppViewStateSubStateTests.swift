// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipApp
@testable import TTZipCore

@MainActor
final class AppViewStateSubStateTests: XCTestCase {
    
    func testAppViewStateSubStateIsolationAndForwarding() {
        let navState = NavigationState()
        let explorerState = ArchiveExplorerState()
        let taskState = TaskExecutionState()
        let overlayState = OverlayState()
        
        let coordinator = AppViewState(
            navigationState: navState,
            explorerState: explorerState,
            taskState: taskState,
            overlayState: overlayState
        )
        
        // 1. NavigationState
        navState.activeTab = .compressWorkspace
        XCTAssertEqual(coordinator.activeTab, .compressWorkspace)
        
        coordinator.activeTab = .vault
        XCTAssertEqual(navState.activeTab, .vault)
        
        // 2. ArchiveExplorerState
        explorerState.currentArchivePath = "/tmp/test.zip"
        XCTAssertEqual(coordinator.currentArchivePath, "/tmp/test.zip")
        
        coordinator.currentArchivePath = "/tmp/new.7z"
        XCTAssertEqual(explorerState.currentArchivePath, "/tmp/new.7z")
        
        // 3. TaskExecutionState
        taskState.statusMessage = "正在解压..."
        XCTAssertEqual(coordinator.statusMessage, "正在解压...")
        
        coordinator.statusMessage = "完成"
        XCTAssertEqual(taskState.statusMessage, "完成")
        
        // 4. OverlayState
        overlayState.showCompressModal = true
        XCTAssertTrue(coordinator.showCompressModal)
        
        coordinator.showCompressModal = false
        XCTAssertFalse(overlayState.showCompressModal)
    }
}
