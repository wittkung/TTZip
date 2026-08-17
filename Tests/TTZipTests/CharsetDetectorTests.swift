import XCTest
@testable import TTZipCore

final class CharsetDetectorTests: XCTestCase {
    
    func testASCIICharsetDetection() {
        let asciiData = "hello_world.txt".data(using: .utf8)!
        let charset = CharsetDetector.detectCharset(data: asciiData)
        XCTAssertEqual(charset, "ASCII", "ASCII strings should be detected as ASCII")
    }
    
    func testUTF8ChineseCharsetDetection() {
        let utf8Data = "中文测试文档.docx".data(using: .utf8)!
        let sanitized = CharsetDetector.sanitizeFilename(bytes: utf8Data)
        XCTAssertEqual(sanitized, "中文测试文档.docx")
    }
    
    func testGBKChineseCharsetDetection() {
        // "你好测试文件.txt" 在 GBK 编码下的字节序列 (16 bytes)
        let gbkString = "你好测试文件.txt"
        let gbkEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let data = gbkString.data(using: gbkEncoding)!
        
        let sanitized = CharsetDetector.sanitizeFilename(bytes: data)
        XCTAssertEqual(sanitized, "你好测试文件.txt", "GBK encoded bytes should be sanitized to proper Chinese string")
    }
    
    func testEmptyDataDetection() {
        let charset = CharsetDetector.detectCharset(data: Data())
        XCTAssertEqual(charset, "ASCII")
    }
}
