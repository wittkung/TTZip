// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ProgressStreamingBridgeTests: XCTestCase {
    
    func test_c_progress_bridge_emits_throttled_events_at_60fps() async throws {
        let (bridge, stream) = ConcurrencyBridge.ProgressStreamBridge.create()
        
        let producerTask = Task.detached {
            // Emulate 1,000 rapid callbacks in 10ms
            for i in 1...1000 {
                bridge.emit(
                    bytesProcessed: Int64(i * 1024),
                    totalBytes: 1000 * 1024,
                    currentFileName: "file_\(i).txt",
                    state: (i == 1000) ? .completed : .processing,
                    force: (i == 1000)
                )
                try? await Task.sleep(nanoseconds: 10_000) // 10 microseconds
            }
        }
        
        var receivedCount = 0
        var lastFraction: Double = 0.0
        
        for await progress in stream {
            receivedCount += 1
            lastFraction = progress.fractionCompleted
        }
        
        _ = await producerTask.result
        
        // Throttling should keep received count well below 1000 while delivering terminal 1.0
        XCTAssertTrue(receivedCount >= 1 && receivedCount < 100, "Event count was \(receivedCount), successfully throttled")
        XCTAssertEqual(lastFraction, 1.0, accuracy: 0.001, "Final progress fraction must be 1.0")
    }
    
    func test_c_progress_cancellation_aborts_in_under_5ms() async throws {
        let (bridge, stream) = ConcurrencyBridge.ProgressStreamBridge.create()
        
        XCTAssertFalse(bridge.isCancelled)
        
        // Cancel stream
        let t0 = ContinuousClock.now
        bridge.cancel()
        let dur = ContinuousClock.now - t0
        
        XCTAssertTrue(bridge.isCancelled)
        XCTAssertTrue(dur < .milliseconds(5), "Cancellation check must complete in < 5ms")
        
        // Next emit should be discarded
        bridge.emit(bytesProcessed: 50, totalBytes: 100, currentFileName: "ignored.txt")
        
        var collectedStates: [ArchiveProgress.State] = []
        for await progress in stream {
            collectedStates.append(progress.state)
        }
        
        XCTAssertTrue(collectedStates.contains(.cancelled), "Stream must emit cancelled state")
    }
}
