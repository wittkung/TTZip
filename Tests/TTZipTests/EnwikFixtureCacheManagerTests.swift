// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class EnwikFixtureCacheManagerTests: XCTestCase {
    
    func testCacheDirectoryResolution() {
        let url = EnwikFixtureCacheManager.cacheDirectoryURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Cache directory must exist")
    }
    
    func testMemoryTelemetrySnapshot() {
        let snapshot = PlatformMemory.currentMemoryUsage()
        XCTAssertGreaterThan(snapshot.currentRSSBytes, 0, "Current RSS must be greater than zero")
        XCTAssertGreaterThan(snapshot.peakRSSBytes, 0, "Peak RSS high-water mark must be greater than zero")
        XCTAssertGreaterThanOrEqual(snapshot.peakRSSBytes, snapshot.currentRSSBytes, "Peak RSS must be >= Current RSS")
    }
    
    func testFileLockConcurrency() throws {
        let tempLockFile = NSTemporaryDirectory() + "ttzip_test_lock_\(UUID().uuidString).lock"
        defer { try? FileManager.default.removeItem(atPath: tempLockFile) }
        
        final class LockedCounter: @unchecked Sendable {
            var value: Int = 0
        }
        let counter = LockedCounter()
        
        let queue = DispatchQueue(label: "com.ttzip.locktest", attributes: .concurrent)
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            group.enter()
            queue.async {
                do {
                    try PlatformFileSystem.withFileLock(atPath: tempLockFile, type: .exclusive) {
                        let current = counter.value
                        usleep(1000) // 1ms
                        counter.value = current + 1
                    }
                } catch {
                    XCTFail("Lock failed with error: \(error)")
                }
                group.leave()
            }
        }
        
        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "Concurrent locks must complete without deadlock")
        XCTAssertEqual(counter.value, 10, "Counter must reflect serialized increments under lock")
    }
}
