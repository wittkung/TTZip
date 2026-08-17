import XCTest
@testable import TTZipCore

final class ArchiveBuilderTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveBuilderTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - ArchiveOptionsBuilder 单元测试
    
    func testArchiveOptionsBuilderDefaultInitialization() {
        let builder = ArchiveOptionsBuilder()
        let options = builder.build()
        
        XCTAssertEqual(options.cpuThreads, AppleSiliconTuner.shared.topology.totalCores)
        XCTAssertEqual(options.sevenZipOptions.algorithm, "LZMA2")
        XCTAssertEqual(options.sevenZipOptions.dictionarySizeMB, 64)
        XCTAssertTrue(options.sevenZipOptions.enableSolidArchive)
        XCTAssertFalse(options.sevenZipOptions.encryptFileNames)
        XCTAssertEqual(options.zipOptions.zipEncryptionMethod, "AES-256")
        XCTAssertTrue(options.zipOptions.zipEncodingUTF8)
        XCTAssertEqual(options.zstdOptions.zstdLevel, 3)
        XCTAssertFalse(options.zstdOptions.zstdEnableLDM)
    }
    
    func testArchiveOptionsBuilderFluentInterface() {
        let builder = ArchiveAdvancedOptions.builder()
            .withFormat(.sevenZip)
            .withLevel(.ultra)
            .withPassword("SecretP@ss123")
            .withCpuThreads(8)
            .withSolidArchive(false)
            .withZipEncryption("ZipCrypto")
            .withZstdLevel(19)
            .withZipEncodingUTF8(false)
            .withPreservePosixAttributes(false)
            .withZip64Mode("Always")
            .withEnableZeroCopy(true)
            .withAlgorithm("PPMd")
            .withDictionarySizeMB(128)
            .withEncryptFileNames(true)
            .withMatchFinder("HC4")
            .withNumFastBytes(64)
            .withZstdEnableLDM(true)
            .withZstdJobSizeMB(128)
            .withZstdWindowLog(25)
            .withZstdChecksum(true)
            .withZstdDictPath("/tmp/custom.dict")
        
        XCTAssertEqual(builder.format, .sevenZip)
        XCTAssertEqual(builder.level, .ultra)
        XCTAssertEqual(builder.password, "SecretP@ss123")
        
        let options = builder.build()
        
        XCTAssertEqual(options.cpuThreads, 8)
        XCTAssertFalse(options.sevenZipOptions.enableSolidArchive)
        XCTAssertEqual(options.zipOptions.zipEncryptionMethod, "ZipCrypto")
        XCTAssertEqual(options.zstdOptions.zstdLevel, 19)
        XCTAssertFalse(options.zipOptions.zipEncodingUTF8)
        XCTAssertFalse(options.zipOptions.preservePosixAttributes)
        XCTAssertEqual(options.zipOptions.zip64Mode, "Always")
        XCTAssertTrue(options.zipOptions.enableZeroCopy)
        XCTAssertEqual(options.sevenZipOptions.algorithm, "PPMd")
        XCTAssertEqual(options.sevenZipOptions.dictionarySizeMB, 128)
        XCTAssertTrue(options.sevenZipOptions.encryptFileNames)
        XCTAssertEqual(options.sevenZipOptions.matchFinder, "HC4")
        XCTAssertEqual(options.sevenZipOptions.numFastBytes, 64)
        XCTAssertTrue(options.zstdOptions.zstdEnableLDM)
        XCTAssertEqual(options.zstdOptions.zstdJobSizeMB, 128)
        XCTAssertEqual(options.zstdOptions.zstdWindowLog, 25)
        XCTAssertTrue(options.zstdOptions.zstdChecksum)
        XCTAssertEqual(options.zstdOptions.zstdDictPath, "/tmp/custom.dict")
    }
    
    func testArchiveOptionsBuilderWithBaseOptions() {
        let base = ArchiveAdvancedOptions(
            cpuThreads: 4,
            zipOptions: ZipFormatOptions(zipEncryptionMethod: "AES-128"),
            sevenZipOptions: SevenZipFormatOptions(dictionarySizeMB: 16),
            zstdOptions: ZstdFormatOptions(zstdLevel: 5)
        )
        let builder = ArchiveOptionsBuilder(baseOptions: base)
            .withCpuThreads(12)
            .withZstdLevel(12)
        
        let built = builder.build()
        XCTAssertEqual(built.cpuThreads, 12)
        XCTAssertEqual(built.zipOptions.zipEncryptionMethod, "AES-128")
        XCTAssertEqual(built.sevenZipOptions.dictionarySizeMB, 16)
        XCTAssertEqual(built.zstdOptions.zstdLevel, 12)
    }
    
    // MARK: - ArchivePipelineBuilder 单元测试
    
    func testArchivePipelineBuilderValidationErrors() async {
        // 无 OutputPath 尝试 create
        do {
            _ = try await ArchivePipelineBuilder()
                .withInputPaths(["/tmp/test.txt"])
                .executeCreate()
            XCTFail("Should fail without output path")
        } catch {
            XCTAssertTrue(error is ArchiveError)
        }
        
        // 无 InputPaths 尝试 create
        do {
            _ = try await ArchivePipelineBuilder()
                .withOutputPath("/tmp/out.zip")
                .executeCreate()
            XCTFail("Should fail without input paths")
        } catch {
            XCTAssertTrue(error is ArchiveError)
        }
        
        // 无 ArchivePath 尝试 extract
        do {
            _ = try await ArchivePipelineBuilder()
                .withDestinationDir("/tmp/out")
                .executeExtract()
            XCTFail("Should fail without archive path")
        } catch {
            XCTAssertTrue(error is ArchiveError)
        }
        
        // 无 DestinationDir 尝试 extract
        do {
            _ = try await ArchivePipelineBuilder()
                .withArchivePath("/tmp/arc.zip")
                .executeExtract()
            XCTFail("Should fail without destination dir")
        } catch {
            XCTAssertTrue(error is ArchiveError)
        }
    }
    
    func testArchivePipelineBuilderEndToEndExecution() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("sample.txt")
        let sampleContent = "Builder Pattern End-To-End Verification Content 2026"
        try sampleContent.write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let outputZip = (tempDirPath as NSString).appendingPathComponent("output_builder.zip")
        let extractDir = (tempDirPath as NSString).appendingPathComponent("ExtractedBuilder")
        
        nonisolated(unsafe) var reportedProgress = false
        
        let result = try await ArchivePipelineBuilder()
            .withOutputPath(outputZip)
            .withFormat(.zip)
            .withLevel(.normal)
            .addInputPath(sampleFile)
            .withFilterOptions(.defaultClean)
            .configureOptions { builder in
                builder = builder
                    .withZipEncryption("AES-256")
                    .withZipEncodingUTF8(true)
            }
            .withProgressHandler { prog in
                reportedProgress = true
            }
            .executeCreate()
        
        XCTAssertGreaterThan(result.compressedBytes, 0)
        XCTAssertGreaterThan(result.durationSeconds, 0)
        XCTAssertGreaterThanOrEqual(result.throughputMBs, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip))
        XCTAssertTrue(reportedProgress)
        
        let elapsed = try await ArchivePipelineBuilder()
            .withArchivePath(outputZip)
            .withDestinationDir(extractDir)
            .executeExtract()
        
        XCTAssertGreaterThan(elapsed, 0)
        let extractedFile = (extractDir as NSString).appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        let extractedContent = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, sampleContent)
    }
    
    func testArchivePipelineBuilderFactorySwapping() async throws {
        let sampleFile = (tempDirPath as NSString).appendingPathComponent("sample_factory.txt")
        try "Factory Swapping Content".write(toFile: sampleFile, atomically: true, encoding: .utf8)
        
        let outputZip = (tempDirPath as NSString).appendingPathComponent("factory_out.zip")
        
        let factory = StandardPortableEngineFactory.shared
        let pipelineBuilder = ArchiveOperationPipeline.builder()
            .withFamilyFactory(factory)
            .withOutputPath(outputZip)
            .withFormat(.zip)
            .withInputPaths([sampleFile])
        
        let result = try await pipelineBuilder.executeCreate()
        XCTAssertGreaterThan(result.compressedBytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip))
    }
}
