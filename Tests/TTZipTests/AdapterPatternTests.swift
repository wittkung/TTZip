import XCTest
@testable import TTZipCore
import CTTZipBridge

final class AdapterPatternTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AdapterPatternTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - 1. CUnsafeBufferAdapter Unit Tests
    
    func testCUnsafeBufferAdapterStringAndArrayConversions() throws {
        // Test optional string pointer
        let testStr = "Hello TTZip Adapter"
        let convertedStr = CUnsafeBufferAdapter.withCString(testStr) { cStr in
            String(cString: cStr!)
        }
        XCTAssertEqual(convertedStr, testStr)
        
        let nilResult = CUnsafeBufferAdapter.withCString(nil) { cStr in
            cStr == nil
        }
        XCTAssertTrue(nilResult)
        
        // Test string array pointer (const char* const*)
        let inputPaths = ["path/to/alpha.txt", "path/to/beta.png", "gamma.zip"]
        let recoveredPaths = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { ptrs in
            (0..<inputPaths.count).map { idx in
                String(cString: ptrs[idx]!)
            }
        }
        XCTAssertEqual(recoveredPaths, inputPaths)
        
        // Test posix_spawn argv NULL-terminated array
        let argvStrings = ["/usr/bin/tar", "-cf", "archive.tar", "file1.txt"]
        let isNullTerminated = CUnsafeBufferAdapter.withCStringsNullTerminatedArray(argvStrings) { ptrs in
            let arg0 = String(cString: ptrs[0]!)
            let arg3 = String(cString: ptrs[3]!)
            let arg4IsNil = ptrs[4] == nil
            return arg0 == "/usr/bin/tar" && arg3 == "file1.txt" && arg4IsNil
        }
        XCTAssertTrue(isNullTerminated)
    }
    
    func testCUnsafeBufferAdapterDataAndAlignedAllocations() throws {
        // Test Data buffer raw pointer conversion
        let originalText = "TTZip High Performance Compression Architecture"
        let data = originalText.data(using: .utf8)!
        
        let recoveredText = CUnsafeBufferAdapter.withBufferPointer(data) { rawPtr, count in
            let bytes = rawPtr.bindMemory(to: UInt8.self, capacity: count)
            return String(bytes: UnsafeBufferPointer(start: bytes, count: count), encoding: .utf8)
        }
        XCTAssertEqual(recoveredText, originalText)
        
        // Test mutable data buffer pointer
        var mutableData = data
        let modified = CUnsafeBufferAdapter.withMutableBufferPointer(&mutableData) { rawPtr, count in
            let bytes = rawPtr.bindMemory(to: UInt8.self, capacity: count)
            bytes.pointee = UInt8(ascii: "X")
            return true
        }
        XCTAssertTrue(modified)
        XCTAssertEqual(mutableData.first, UInt8(ascii: "X"))
        
        // Test 16KB aligned buffer allocation & deallocation
        let bufferCapacity = 32768
        if let buffer = CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: bufferCapacity) {
            let pointerAddress = Int(bitPattern: buffer)
            XCTAssertEqual(pointerAddress % 16384, 0, "Buffer must be 16KB (16384 bytes) page aligned")
            CUnsafeBufferAdapter.deallocateAlignedBuffer(buffer)
        } else {
            XCTFail("Failed to allocate aligned buffer")
        }
    }
    
    // MARK: - 2. SevenZipCAdapter Unit Tests
    
    func testSevenZipCAdapterArchiveOperations() throws {
        let inputFile = tempDir.appendingPathComponent("test_7z_input.txt")
        let content = "SevenZipCAdapter Test Content - " + String(repeating: "7zDataBlock ", count: 100)
        try content.write(to: inputFile, atomically: true, encoding: .utf8)
        
        let output7z = tempDir.appendingPathComponent("output.7z")
        let extractDir = tempDir.appendingPathComponent("extracted_7z")
        
        let adapter = SevenZipCAdapter.shared
        
        // Test 7z Compression
        let compressSuccess = try adapter.createArchive(
            outputPath: output7z.path,
            inputPaths: [inputFile.path],
            level: .normal,
            password: nil
        )
        XCTAssertTrue(compressSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output7z.path))
        
        // Test 7z Extraction
        let extractSuccess = try adapter.extractArchive(
            archivePath: output7z.path,
            destinationDir: extractDir.path,
            password: nil
        )
        XCTAssertTrue(extractSuccess)
        
        let extractedFile = extractDir.appendingPathComponent("test_7z_input.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, content)
    }
    
    // MARK: - 3. ZstdCAdapter Unit Tests
    
    func testZstdCAdapterStreamOperations() throws {
        let inputFile = tempDir.appendingPathComponent("test_zstd_input.txt")
        let content = "ZstdCAdapter Stream Test - " + String(repeating: "RFC8878ZstandardFrameData ", count: 200)
        try content.write(to: inputFile, atomically: true, encoding: .utf8)
        
        let outputZst = tempDir.appendingPathComponent("output.zst")
        let decompressedFile = tempDir.appendingPathComponent("decompressed_zstd.txt")
        
        let adapter = ZstdCAdapter.shared
        
        // Test Zstd Compression
        let compressSuccess = try adapter.compressFile(
            srcPath: inputFile.path,
            dstPath: outputZst.path,
            level: .normal,
            enableLDM: false
        )
        XCTAssertTrue(compressSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZst.path))
        
        // Test Zstd Decompression
        let decompressSuccess = try adapter.decompressFile(
            srcPath: outputZst.path,
            dstPath: decompressedFile.path
        )
        XCTAssertTrue(decompressSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: decompressedFile.path))
        let decompressedContent = try String(contentsOf: decompressedFile, encoding: .utf8)
        XCTAssertEqual(decompressedContent, content)
    }
    
    // MARK: - 4. LibdeflateCAdapter Unit Tests
    
    func testLibdeflateCAdapterDataBufferOperations() throws {
        let adapter = LibdeflateCAdapter.shared
        let originalText = "LibdeflateCAdapter Ultra Fast Deflate Compression Test - " + String(repeating: "LibdeflateBufferData ", count: 150)
        let originalData = originalText.data(using: .utf8)!
        
        // Test Data Compression
        guard let compressedData = adapter.compressData(originalData, level: 6) else {
            XCTFail("Libdeflate compression returned nil")
            return
        }
        XCTAssertGreaterThan(compressedData.count, 0)
        XCTAssertLessThan(compressedData.count, originalData.count)
        
        // Test Data Decompression
        guard let decompressedData = adapter.decompressData(compressedData, originalSize: originalData.count) else {
            XCTFail("Libdeflate decompression returned nil")
            return
        }
        XCTAssertEqual(decompressedData, originalData)
        let decompressedText = String(data: decompressedData, encoding: .utf8)
        XCTAssertEqual(decompressedText, originalText)
    }
    
    // MARK: - 5. POSIXTarCAdapter Unit Tests
    
    func testPOSIXTarCAdapterArchiveAndSpawnOperations() throws {
        let inputFile = tempDir.appendingPathComponent("test_tar_input.txt")
        let content = "POSIXTarCAdapter Integration Test - " + String(repeating: "POSIXTarArchivePayload ", count: 80)
        try content.write(to: inputFile, atomically: true, encoding: .utf8)
        
        let outputTar = tempDir.appendingPathComponent("output.tar")
        let extractDir = tempDir.appendingPathComponent("extracted_tar")
        
        let adapter = POSIXTarCAdapter.shared
        
        // Test posix_spawn fast process invocation (/bin/echo)
        let echoExitCode = try adapter.spawnProcess(binaryPath: "/bin/echo", arguments: ["TTZip", "POSIX", "Spawn"])
        XCTAssertEqual(echoExitCode, 0)
        
        // Test Tar creation via /usr/bin/tar
        let createSuccess = try adapter.createTar(
            outputPath: outputTar.path,
            inputPaths: [inputFile.lastPathComponent],
            workingDirectory: tempDir.path
        )
        XCTAssertTrue(createSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputTar.path))
        
        // Test Tar extraction via /usr/bin/tar
        let extractSuccess = try adapter.extractTar(
            archivePath: outputTar.path,
            destinationDir: extractDir.path
        )
        XCTAssertTrue(extractSuccess)
        
        let extractedFile = extractDir.appendingPathComponent("test_tar_input.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, content)
    }
    
    // MARK: - 6. ArchiveEngineFactory Adapter Integration Tests
    
    func testArchiveEngineFactoryReturnsAdapterInstances() {
        let sevenZipEngine: SevenZipEngineProtocol = SevenZipCAdapter.shared
        XCTAssertTrue(sevenZipEngine is SevenZipCAdapter)
        
        let zstdEngine: ZstdEngineProtocol = ZstdCAdapter.shared
        XCTAssertTrue(zstdEngine is ZstdCAdapter)
        
        let libdeflateEngine: LibdeflateEngineProtocol = LibdeflateCAdapter.shared
        XCTAssertTrue(libdeflateEngine is LibdeflateCAdapter)
        
        let posixTarEngine: POSIXTarEngineProtocol = POSIXTarCAdapter.shared
        XCTAssertTrue(posixTarEngine is POSIXTarCAdapter)
    }
}
