import XCTest
@testable import TTZipCore

final class PlatformMonotonicTimerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        PlatformMonotonicTimer.initialize()
    }

    func testTimerCalibrationDiagnostics() {
        let info = PlatformMonotonicTimer.calibrationInfo()
        
        XCTAssertFalse(info.platformOS.isEmpty, "Platform OS should not be empty")
        XCTAssertFalse(info.architecture.isEmpty, "Architecture should not be empty")
        XCTAssertFalse(info.timerBackend.isEmpty, "Timer backend should not be empty")
        XCTAssertGreaterThan(info.frequencyHz, 0, "Frequency should be positive")
        XCTAssertGreaterThan(info.timebaseNumer, 0, "Timebase numer should be positive")
        XCTAssertGreaterThan(info.timebaseDenom, 0, "Timebase denom should be positive")
        XCTAssertGreaterThan(info.resolutionNanos, 0.0, "Resolution in nanos should be positive")
        XCTAssertLessThanOrEqual(info.resolutionNanos, 100.0, "Resolution should be sub-100ns")
    }

    func testMonotonicityUnderTightLoop() {
        var prevNanos = PlatformMonotonicTimer.nowNanoseconds()
        for _ in 0..<100_000 {
            let currNanos = PlatformMonotonicTimer.nowNanoseconds()
            XCTAssertGreaterThanOrEqual(currNanos, prevNanos, "Platform monotonic timer must never jump backward")
            prevNanos = currNanos
        }
    }

    func testTickToNanosecondConversion() {
        let ticks1 = PlatformMonotonicTimer.rawTicks()
        // Simulate small delay
        var sum: UInt64 = 0
        for i in 0..<1000 {
            sum &+= UInt64(i)
        }
        let ticks2 = PlatformMonotonicTimer.rawTicks()
        XCTAssertGreaterThanOrEqual(ticks2, ticks1)
        
        let deltaTicks = ticks2 - ticks1
        let deltaNanos = PlatformMonotonicTimer.ticksToNanoseconds(deltaTicks)
        let deltaSec = PlatformMonotonicTimer.ticksToSeconds(deltaTicks)
        
        XCTAssertGreaterThanOrEqual(deltaNanos, 0)
        XCTAssertEqual(deltaSec, Double(deltaNanos) / 1_000_000_000.0, accuracy: 1e-9)
    }

    func testMeasureBlockHelpers() {
        let (result, nanos, sec) = PlatformMonotonicTimer.measure {
            var val = 0
            for i in 0..<1000 {
                val += i
            }
            return val
        }
        
        XCTAssertEqual(result, 499500)
        XCTAssertGreaterThan(nanos, 0)
        XCTAssertGreaterThan(sec, 0.0)
        XCTAssertEqual(sec, Double(nanos) / 1_000_000_000.0, accuracy: 1e-9)
    }

    func testAsyncMeasureBlockHelpers() async {
        let (result, nanos, sec) = await PlatformMonotonicTimer.measureAsync {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return "ok"
        }
        
        XCTAssertEqual(result, "ok")
        XCTAssertGreaterThanOrEqual(nanos, 8_000_000, "Should measure at least ~8ms")
        XCTAssertGreaterThanOrEqual(sec, 0.008)
    }
}
