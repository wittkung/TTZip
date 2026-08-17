import XCTest
@testable import TTZipCore

final class ProfessionalAlgorithmsTests: XCTestCase {
    
    func testLZ4LzoEngineRoundtrip() {
        let engine = LZ4LzoEngine()
        let sample = Data("AAAAABBBBBCCCCCDDDDD123456789AAAAABBBBBCCCCCDDDDD123456789".utf8)
        
        let compressed = engine.compress(data: sample)
        let decompressed = engine.decompress(data: compressed, originalSizeHint: sample.count)
        
        XCTAssertEqual(decompressed, sample)
    }
    
    func testZstdDictionaryEngineRoundtrip() throws {
        let engine = ZstdDictionaryEngine(compressionLevel: 3)
        let payload = Data("{\"user_id\": 1001, \"action\": \"login\", \"payload\": \"TTZip Zstd Engine Native Test 2026\"}".utf8)
        
        let compressed = engine.compressPayload(data: payload)
        let decompressed = try engine.decompressPayload(data: compressed, uncompressedCapacityHint: payload.count)
        
        XCTAssertEqual(decompressed, payload)
    }
    
    func testDeltaRLEFilterRoundtrip() {
        let filter = DeltaRLEFilter()
        let originalData = Data([10, 12, 14, 16, 18, 20, 22, 24, 26, 28])
        
        let deltaFiltered = filter.applyDeltaFilter(data: originalData)
        let restoredData = filter.removeDeltaFilter(data: deltaFiltered)
        
        XCTAssertEqual(restoredData, originalData)
    }
}
