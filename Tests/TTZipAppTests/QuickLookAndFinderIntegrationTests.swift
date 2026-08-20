// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipApp
@testable import TTZipCore

final class QuickLookAndFinderIntegrationTests: XCTestCase {
    
    func test_ephemeral_preview_cache_staging_and_cleanup() async throws {
        let manager = EphemeralPreviewCacheManager.shared
        let sampleData = Data("QuickLook Test Content 2026".utf8)
        let fileName = "sample_test_entry.txt"
        
        let stagedURL = try await manager.stageFile(data: sampleData, suggestedFileName: fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedURL.path))
        
        let readData = try Data(contentsOf: stagedURL)
        XCTAssertEqual(readData, sampleData)
        
        await manager.cleanupAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
    }
    
    @MainActor
    func test_quicklook_preview_coordinator_disk_toggle() throws {
        let coordinator = QuickLookPreviewCoordinator.shared
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_toggle_file.txt")
        try Data("dummy".utf8).write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            coordinator.dismissPreview()
        }
        
        coordinator.previewDiskFile(url: tempURL)
        XCTAssertEqual(coordinator.activePreviewURL, tempURL)
        
        // Toggling same file dismisses preview
        coordinator.previewDiskFile(url: tempURL)
        XCTAssertNil(coordinator.activePreviewURL)
    }
    
    func test_archive_drag_item_provider_factory() {
        let itemProvider = ArchiveDragItemProviderFactory.createItemProvider(
            archivePath: "/tmp/fake_archive.zip",
            entryPath: "docs/spec.pdf",
            suggestedFileName: "spec.pdf"
        )
        
        XCTAssertNotNil(itemProvider)
        XCTAssertEqual(itemProvider.suggestedName, "spec.pdf")
    }
}
