// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveOrthogonalPipelineTests: XCTestCase {
    
    func testPipelineCompositionBasics() {
        let comp = ArchivePipelineCompositor.compose(container: .tar, filter: .zstd)
        XCTAssertEqual(comp.container, .tar)
        XCTAssertEqual(comp.filter, .zstd)
        XCTAssertEqual(comp.primaryFileExtension, "tar.zst")
        XCTAssertTrue(comp.supportsFastPathBypass, "Tar.Zst should support direct fast-path bypass")
    }
    
    func testFastPathBypassDecisions() {
        XCTAssertTrue(ArchivePipelineCompositor.isFastPathSupported(container: .zip, filter: .none))
        XCTAssertTrue(ArchivePipelineCompositor.isFastPathSupported(container: .sevenZip, filter: .none))
        XCTAssertTrue(ArchivePipelineCompositor.isFastPathSupported(container: .tar, filter: .zstd))
        XCTAssertTrue(ArchivePipelineCompositor.isFastPathSupported(container: .tar, filter: .none))
        
        XCTAssertFalse(ArchivePipelineCompositor.isFastPathSupported(container: .tar, filter: .lrzip))
        XCTAssertFalse(ArchivePipelineCompositor.isFastPathSupported(container: .cpio, filter: .gzip))
    }
    
    func testPipelineDecomposition() {
        let t1 = ArchivePipelineCompositor.decompose(filePath: "archive.tar.gz")
        XCTAssertEqual(t1.container, .tar)
        XCTAssertEqual(t1.filter, .gzip)
        
        let t2 = ArchivePipelineCompositor.decompose(filePath: "backup.7z")
        XCTAssertEqual(t2.container, .sevenZip)
        XCTAssertEqual(t2.filter, .none)
        
        let t3 = ArchivePipelineCompositor.decompose(filePath: "data.zst")
        XCTAssertEqual(t3.container, .raw)
        XCTAssertEqual(t3.filter, .zstd)
        
        let t4 = ArchivePipelineCompositor.decompose(filePath: "image.iso")
        XCTAssertEqual(t4.container, .iso)
        XCTAssertEqual(t4.filter, .none)
    }
}
