import XCTest
@testable import TTZipCore
import CTTZipBridge

final class PerformanceIoTests: XCTestCase {
    
    func testAlignedMemoryAllocation() {
        let ptr = ttzip_aligned_alloc_16k(4 * 1024 * 1024)
        XCTAssertNotNil(ptr)
        let addr = UIntBitPattern(UInt(bitPattern: ptr))
        XCTAssertEqual(addr % 16384, 0, "Memory allocation must be aligned to 16KB physical page boundaries")
        free(ptr)
    }
    
    func testAppleSiliconThreadAllocation() {
        let tuner = AppleSiliconTuner.shared
        XCTAssertGreaterThan(tuner.optimalCompressionThreads, 0)
        XCTAssertEqual(tuner.optimalAlignedBufferSize % 16384, 0)
        XCTAssertTrue(tuner.hardwareSummary.contains("Apple") || tuner.hardwareSummary.contains("Silicon"))
    }
}

private typealias UIntBitPattern = UInt
