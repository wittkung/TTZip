// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
import CTTZipBridge

final class PipeStreamingTests: XCTestCase {
    
    private var tempDir: String!
    
    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_pipe_test_\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        tempDir = dir
    }
    
    override func tearDown() {
        if let dir = tempDir {
            try? FileManager.default.removeItem(atPath: dir)
        }
        super.tearDown()
    }
    
    func testSigpipeExitCodeIs141() {
        XCTAssertEqual(CLIExitCode.sigpipe.rawValue, 141, "SIGPIPE exit status must be 128 + 13 = 141")
    }
    
    func testStreamExecutionModeDetection() {
        let direct = StreamPipeAdapter.determineMode(inputPath: "/tmp/a.zip", outputPath: "/tmp/out")
        XCTAssertEqual(direct, .directFile)
        
        let stdinMode = StreamPipeAdapter.determineMode(inputPath: "-", outputPath: "/tmp/out")
        XCTAssertEqual(stdinMode, .standardInputPipe)
        
        let stdoutMode = StreamPipeAdapter.determineMode(inputPath: "/tmp/in", outputPath: "-")
        XCTAssertEqual(stdoutMode, .standardOutputPipe)
        
        let duplexMode = StreamPipeAdapter.determineMode(inputPath: "-", outputPath: "-")
        XCTAssertEqual(duplexMode, .duplexPipe)
        
        let catMode = StreamPipeAdapter.determineMode(inputPath: "/tmp/a.zip", outputPath: nil, isCat: true)
        XCTAssertEqual(catMode, .singleEntryStdout)
    }
    
    func testProgressRoutingDetermination() {
        let suppressed = StreamPipeAdapter.determineProgressRouting(mode: .standardOutputPipe, isQuiet: true)
        XCTAssertEqual(suppressed, .suppressed)
        
        let stdoutPipe = StreamPipeAdapter.determineProgressRouting(mode: .standardOutputPipe, isQuiet: false)
        XCTAssertTrue(stdoutPipe == .standardError || stdoutPipe == .suppressed)
        
        let direct = StreamPipeAdapter.determineProgressRouting(mode: .directFile, isQuiet: false)
        XCTAssertTrue(direct == .inlineTty || direct == .standardError || direct == .suppressed)
    }
    
    func testNativeTarZstStdoutStreamingRoundtrip() async throws {
        let srcDir = (tempDir as NSString).appendingPathComponent("src")
        let dstDir = (tempDir as NSString).appendingPathComponent("dst")
        try FileManager.default.createDirectory(atPath: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        
        let testFile = (srcDir as NSString).appendingPathComponent("hello.txt")
        let payload = "TTZip Direct Streaming Payload 2026"
        try payload.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let outArchive = (tempDir as NSString).appendingPathComponent("output.tar.zst")
        
        // 1. Create tar.zst direct
        let paths = [testFile]
        let createStatus = CUnsafeBufferAdapter.withCString(outArchive) { cOut in
            CUnsafeBufferAdapter.withCStringsArray(paths) { cIn in
                guard let cOut = cOut else { return Int32(-1) }
                return ttzip_create_tar_zstd_direct_c(cOut, cIn, paths.count, 3, false)
            }
        }
        XCTAssertEqual(createStatus, 0)
        
        // 2. Extract tar.zst direct
        let extractStatus = CUnsafeBufferAdapter.withCString(outArchive) { cArchive in
            CUnsafeBufferAdapter.withCString(dstDir) { cDst in
                guard let cArchive = cArchive, let cDst = cDst else { return Int32(-1) }
                return ttzip_extract_tar_zstd_direct_c(cArchive, cDst, false)
            }
        }
        XCTAssertEqual(extractStatus, 0)
        
        let extractedFile = (dstDir as NSString).appendingPathComponent("hello.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        let extractedContent = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, payload)
    }
    
    func testNativeTarGzStdoutStreaming() async throws {
        let srcDir = (tempDir as NSString).appendingPathComponent("src_gz")
        let dstDir = (tempDir as NSString).appendingPathComponent("dst_gz")
        try FileManager.default.createDirectory(atPath: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
        
        let testFile = (srcDir as NSString).appendingPathComponent("sample.txt")
        let payload = "Parallel Gzip Streaming Payload"
        try payload.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let outArchive = (tempDir as NSString).appendingPathComponent("output.tar.gz")
        
        let paths = [testFile]
        let createStatus = CUnsafeBufferAdapter.withCString(outArchive) { cOut in
            CUnsafeBufferAdapter.withCString("tar.gz") { cFmt in
                CUnsafeBufferAdapter.withCStringsArray(paths) { cIn in
                    guard let cOut = cOut else { return Int32(-1) }
                    return ttzip_create_tar_native_c(cOut, cFmt, cIn, paths.count, false, 1)
                }
            }
        }
        XCTAssertEqual(createStatus, 0)
        
        let extractStatus = CUnsafeBufferAdapter.withCString(outArchive) { cArchive in
            CUnsafeBufferAdapter.withCString(dstDir) { cDst in
                guard let cArchive = cArchive, let cDst = cDst else { return Int32(-1) }
                return ttzip_extract_tar_native_c(cArchive, cDst, false)
            }
        }
        XCTAssertEqual(extractStatus, 0)
        
        let extractedFile = (dstDir as NSString).appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
    }
    
    func testSingleEntryStdoutStream() async throws {
        let srcDir = (tempDir as NSString).appendingPathComponent("src_cat")
        try FileManager.default.createDirectory(atPath: srcDir, withIntermediateDirectories: true)
        
        let testFile = (srcDir as NSString).appendingPathComponent("doc.txt")
        let payload = "Direct single entry cat content"
        try payload.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        let archivePath = (tempDir as NSString).appendingPathComponent("doc.zip")
        let proxy = SecurityProtectionProxy()
        let res = try await proxy.quickCompress(
            inputs: [testFile],
            outputPath: archivePath,
            format: .zip,
            level: .fast
        )
        XCTAssertTrue(res.durationSeconds >= 0)
        
        // Test pipe reader with ttzip_stream_archive_entries_to_fd
        let pipe = Pipe()
        var errBuf = [CChar](repeating: 0, count: 512)
        var patterns: [UnsafePointer<CChar>?] = [("doc.txt" as NSString).utf8String]
        
        let rc = patterns.withUnsafeBufferPointer { ptr in
            return ttzip_stream_archive_entries_to_fd(
                archivePath,
                ptr.baseAddress,
                1,
                pipe.fileHandleForWriting.fileDescriptor,
                nil,
                true,
                &errBuf,
                512
            )
        }
        try? pipe.fileHandleForWriting.close()
        XCTAssertEqual(rc, 0)
        
        let streamedData = pipe.fileHandleForReading.readDataToEndOfFile()
        let streamedStr = String(data: streamedData, encoding: .utf8)
        XCTAssertEqual(streamedStr, payload)
    }
    
    func testPOSIXCLIArgumentParserFlagsForStreaming() {
        let res1 = POSIXCLIArgumentParser.parse(args: ["archive", "-f", "tar.zst", "-o", "-", "/tmp/data"])
        XCTAssertEqual(res1.options.outputPath, "-")
        XCTAssertEqual(res1.options.format, "tar.zst")
        
        let res2 = POSIXCLIArgumentParser.parse(args: ["extract", "-i", "-", "-d", "/tmp/out"])
        XCTAssertEqual(res2.options.inputPath, "-")
        
        let res3 = POSIXCLIArgumentParser.parse(args: ["extract", "-O", "/tmp/archive.zip", "entry.txt"])
        XCTAssertTrue(res3.options.toStdout)
        
        let res4 = POSIXCLIArgumentParser.parse(args: ["extract", "-c", "/tmp/archive.zip"])
        XCTAssertTrue(res4.options.toStdout)
    }
}
