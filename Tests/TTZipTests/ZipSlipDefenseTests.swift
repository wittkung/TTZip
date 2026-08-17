import XCTest
import CTTZipBridge
@testable import TTZipCore

final class ZipSlipDefenseTests: XCTestCase {
    
    func testZipSlipPathTraversalBlockedInCBridge() {
        let baseDir = "/tmp/ttzip_test_extract"
        var dstBuf = [CChar](repeating: 0, count: 4096)
        
        let status = ttzip_common_join_path(&dstBuf, dstBuf.count, baseDir, "../../etc/passwd")
        XCTAssertNotEqual(status, 0, "Zip-Slip path traversal '../../etc/passwd' must be rejected by C bridge")
    }
    
    func testNormalRelativePathAllowedInCBridge() {
        let baseDir = "/tmp/ttzip_test_extract"
        var dstBuf = [CChar](repeating: 0, count: 4096)
        
        let status = ttzip_common_join_path(&dstBuf, dstBuf.count, baseDir, "subfolder/document.txt")
        XCTAssertEqual(status, 0, "Normal relative path must succeed")
        let result = dstBuf.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        XCTAssertEqual(result, "/tmp/ttzip_test_extract/subfolder/document.txt")
    }
}
