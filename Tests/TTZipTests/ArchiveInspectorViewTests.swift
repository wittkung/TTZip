// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
@testable import TTZipApp

final class ArchiveInspectorViewTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_inspector_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        ArchiveDiagnosticsCache.shared.clear()
    }
    
    override func tearDown() async throws {
        if let t = tempDir {
            try? FileManager.default.removeItem(at: t)
        }
        ArchiveDiagnosticsCache.shared.clear()
        try await super.tearDown()
    }
    
    @MainActor
    func testArchiveInspectorViewModelInitialState() {
        let vm = ArchiveInspectorViewModel()
        XCTAssertFalse(vm.state.isScanning)
        XCTAssertEqual(vm.state.filePath, "")
        XCTAssertNil(vm.state.detectedFormat)
    }
    
    @MainActor
    func testArchiveInspectorViewModelOnRealZipArchive() async throws {
        let zipURL = tempDir.appendingPathComponent("sample.zip")
        let docURL = tempDir.appendingPathComponent("hello.txt")
        try "Hello TTZip Diagnostic Inspector".write(to: docURL, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zipURL.path,
            format: .zip,
            level: .fast,
            inputPaths: [docURL.path]
        )
        
        let vm = ArchiveInspectorViewModel()
        vm.inspectArchive(atPath: zipURL.path)
        
        // Wait for async task to complete
        let expectation = XCTestExpectation(description: "Scan finished")
        
        for _ in 0..<50 {
            if !vm.state.isScanning && vm.state.detectedFormat != nil {
                expectation.fulfill()
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(vm.state.detectedFormat, .zip)
        XCTAssertEqual(vm.state.fileName, "sample.zip")
        XCTAssertNotNil(vm.state.standardSpec)
        XCTAssertEqual(vm.state.standardSpec?.officialName, "PKWARE ZIP File Format Specification")
        XCTAssertEqual(vm.state.complianceReport?.isCompliant, true)
        XCTAssertGreaterThan(vm.state.scanDurationMs, 0.0)
        XCTAssertNil(vm.state.errorMessage)
    }
    
    @MainActor
    func testArchiveDiagnosticsCacheHit() async throws {
        let tarURL = tempDir.appendingPathComponent("sample.tar")
        let docURL = tempDir.appendingPathComponent("doc.txt")
        try "Diagnostic Caching Payload".write(to: docURL, atomically: true, encoding: .utf8)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: tarURL.path,
            format: .tar,
            level: .fast,
            inputPaths: [docURL.path]
        )
        
        let vm1 = ArchiveInspectorViewModel()
        vm1.inspectArchive(atPath: tarURL.path)
        
        // Wait for initial scan
        for _ in 0..<50 {
            if !vm1.state.isScanning && vm1.state.detectedFormat != nil {
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        
        XCTAssertEqual(vm1.state.detectedFormat, .tar)
        
        // Immediate second inspection with new ViewModel should be instant cache hit
        let vm2 = ArchiveInspectorViewModel()
        vm2.inspectArchive(atPath: tarURL.path)
        
        XCTAssertFalse(vm2.state.isScanning)
        XCTAssertEqual(vm2.state.detectedFormat, .tar)
        XCTAssertEqual(vm2.state.standardSpec?.officialName, "POSIX.1-2001 / IEEE Std 1003.1 ustar/pax Format")
    }
}
