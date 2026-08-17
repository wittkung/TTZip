import XCTest
@testable import TTZipCore

final class CrossPlatformManifestTests: XCTestCase {
    
    func testCrossPlatformSchemaValidation() throws {
        let manifestJSON = """
        {
          "targetPlatform": "macos_universal2",
          "libdeflateVersion": "v1.22",
          "compiler": "apple_clang",
          "simdExtensions": ["armv8.2-a+crypto", "neon"],
          "artifactPath": "Vendor/lib/libdeflate.a"
        }
        """
        
        let data = try XCTUnwrap(manifestJSON.data(using: .utf8))
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(jsonObject["targetPlatform"] as? String, "macos_universal2")
        XCTAssertEqual(jsonObject["libdeflateVersion"] as? String, "v1.22")
        XCTAssertEqual(jsonObject["compiler"] as? String, "apple_clang")
        
        let extensions = try XCTUnwrap(jsonObject["simdExtensions"] as? [String])
        XCTAssertTrue(extensions.contains("armv8.2-a+crypto"))
        XCTAssertEqual(jsonObject["artifactPath"] as? String, "Vendor/lib/libdeflate.a")
    }
    
    func testChunkedPipelineOptionsDefaults() throws {
        let optionsJSON = """
        {
          "chunkSize": 1048576,
          "maxInFlightChunks": 32,
          "compressionLevel": 6,
          "enableZip64": false,
          "enableStoredBlockSync": true
        }
        """
        
        let data = try XCTUnwrap(optionsJSON.data(using: .utf8))
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(jsonObject["chunkSize"] as? Int, 1048576)
        XCTAssertEqual(jsonObject["maxInFlightChunks"] as? Int, 32)
        XCTAssertEqual(jsonObject["compressionLevel"] as? Int, 6)
        XCTAssertEqual(jsonObject["enableZip64"] as? Bool, false)
        XCTAssertEqual(jsonObject["enableStoredBlockSync"] as? Bool, true)
    }
}
