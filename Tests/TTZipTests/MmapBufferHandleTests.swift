// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class MmapBufferHandleTests: XCTestCase {
    
    private var tempFileURL: URL!
    private let sampleContent = "TTZip World-Class Open Source Engine Mmap Safety Test Payload"
    
    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("ttzip_mmap_test_\(UUID().uuidString).bin")
        try sampleContent.data(using: .utf8)?.write(to: tempFileURL)
    }
    
    override func tearDownWithError() throws {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func testMmapBufferHandleBasicLifecycle() throws {
        let handle = try MmapBufferHandle.mapReadOnly(path: tempFileURL.path)
        XCTAssertGreaterThan(handle.count, 0)
        XCTAssertEqual(handle.count, sampleContent.utf8.count)
        
        let readBack = String(decoding: handle.bytes, as: UTF8.self)
        XCTAssertEqual(readBack, sampleContent)
        
        // Slice test with bounds checking
        let slice = handle.slice(offset: 0, length: 5)
        XCTAssertNotNil(slice)
        XCTAssertEqual(String(decoding: slice!, as: UTF8.self), "TTZip")
        
        // Out of bounds slice
        let oobSlice = handle.slice(offset: handle.count - 2, length: 10)
        XCTAssertNil(oobSlice)
    }
    
    func testMmapBufferHandleConcurrentReading() throws {
        let handle = try MmapBufferHandle.mapReadOnly(path: tempFileURL.path)
        
        let expectedCount = sampleContent.utf8.count
        // Concurrent multi-threaded reads across threads without data races
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let bytes = handle.bytes
            XCTAssertEqual(bytes.count, expectedCount)
            XCTAssertEqual(bytes[0], UInt8(ascii: "T"))
        }

    }
    
    func testMmapBufferHandleInvalidPath() {
        XCTAssertThrowsError(try MmapBufferHandle.mapReadOnly(path: "/invalid/nonexistent/path_\(UUID().uuidString)"))
    }
    
    func testZipMemoryEngineWithMmapBufferHandle() throws {
        // Build minimal valid ZIP
        let minimalZipStub = Data([
            0x50, 0x4B, 0x03, 0x04, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x74, 0x65,
            0x73, 0x74, 0x50, 0x4B, 0x01, 0x02, 0x0A, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x74, 0x65, 0x73, 0x74, 0x50, 0x4B, 0x05, 0x06, 0x00, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x36, 0x00, 0x00, 0x00,
            0x20, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_stub_\(UUID().uuidString).zip")
        try minimalZipStub.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }
        
        let handle = try MmapBufferHandle.mapReadOnly(path: zipURL.path)
        let extracted = ZipMemoryEngine.shared.extractInMemory(handle: handle)
        XCTAssertNotNil(extracted)
    }
}

