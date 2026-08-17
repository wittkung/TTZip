import XCTest
import Foundation
@testable import TTZipCore

/// 对标 libarchive test_common.h 的原语级 POSIX、内存与编码高精诊断断言库
public enum TTZipAssertions {
    
    /// 断言两个二进制数据完全一致，并在失败时输出 16 字节对齐 HexDump 差分窗口与延迟上下文
    public static func assertDataEqual(
        _ actual: Data,
        _ expected: Data,
        message: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if actual == expected {
            _ = DiagnosticContext.consumePendingMessage()
            return
        }
        
        let pending = DiagnosticContext.consumePendingMessage()
        let diff = FastHexDiffEngine.generateDiff(expected: expected, actual: actual, maxWindow: 256, useAnsi: true) ?? "Length mismatch"
        
        var failureMsg = "\n"
        if let msg = message ?? pending {
            failureMsg += "  \u{001B}[1;36mContext:\u{001B}[0m \(msg)\n"
        }
        failureMsg += diff
        
        XCTFail(failureMsg, file: file, line: line)
    }
    
    /// 断言两个字符串完全一致，并在失败时输出 Unicode 标量展开与 APFS NFD/NFC 差分分析
    public static func assertStringEqual(
        _ actual: String,
        _ expected: String,
        message: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if actual == expected {
            _ = DiagnosticContext.consumePendingMessage()
            return
        }
        
        let pending = DiagnosticContext.consumePendingMessage()
        let analysis = UnicodeDiagnosticFormatter.analyzeStringMismatch(expected: expected, actual: actual)
        
        var failureMsg = "\n"
        if let msg = message ?? pending {
            failureMsg += "  \u{001B}[1;36mContext:\u{001B}[0m \(msg)\n"
        }
        failureMsg += analysis
        
        XCTFail(failureMsg, file: file, line: line)
    }
    
    /// 断言文件内容与内存字节完全一致
    public static func assertFileContents(
        _ url: URL,
        expectedData: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actualData = try? Data(contentsOf: url) else {
            XCTFail("Assertion Failed: Unable to read file at \(url.path)", file: file, line: line)
            return
        }
        assertDataEqual(actualData, expectedData, message: "File: \(url.lastPathComponent)", file: file, line: line)
    }
    
    /// 断言文件 POSIX 权限模式 (mode_t)
    public static func assertFileMode(
        _ url: URL,
        expectedMode: mode_t,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        let actualMode = st.st_mode & 0o777
        XCTAssertEqual(actualMode, expectedMode & 0o777, "Assertion Failed: Expected mode \(String(expectedMode, radix: 8)) but got \(String(actualMode, radix: 8)) for \(url.path)", file: file, line: line)
    }
    
    /// 断言路径为普通文件
    public static func assertIsReg(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        XCTAssertTrue((st.st_mode & S_IFMT) == S_IFREG, "Assertion Failed: \(url.path) is not a regular file", file: file, line: line)
    }
    
    /// 断言路径为目录
    public static func assertIsDir(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        XCTAssertTrue((st.st_mode & S_IFMT) == S_IFDIR, "Assertion Failed: \(url.path) is not a directory", file: file, line: line)
    }
    
    /// 断言两个路径为相同 inode 的硬链接 (Hardlink)
    public static func assertIsHardlink(
        _ urlA: URL,
        _ urlB: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var stA = stat()
        var stB = stat()
        guard stat(urlA.path, &stA) == 0, stat(urlB.path, &stB) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(urlA.path) or \(urlB.path)", file: file, line: line)
            return
        }
        XCTAssertEqual(stA.st_ino, stB.st_ino, "Assertion Failed: Inode mismatch between \(urlA.path) and \(urlB.path)", file: file, line: line)
        XCTAssertEqual(stA.st_dev, stB.st_dev, "Assertion Failed: Device mismatch between \(urlA.path) and \(urlB.path)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(stA.st_nlink, 2, "Assertion Failed: Hardlink count for \(urlA.path) should be >= 2", file: file, line: line)
    }
    
    /// 断言文件为空文件 (0 字节)
    public static func assertEmptyFile(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var st = stat()
        guard stat(url.path, &st) == 0 else {
            XCTFail("Assertion Failed: stat() failed for \(url.path)", file: file, line: line)
            return
        }
        XCTAssertEqual(st.st_size, 0, "Assertion Failed: Expected empty file at \(url.path), but size is \(st.st_size)", file: file, line: line)
    }
}
