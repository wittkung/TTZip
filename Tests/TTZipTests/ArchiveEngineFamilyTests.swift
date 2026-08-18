// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveEngineFamilyTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        ArchiveEngineFamilyProvider.shared.reset()
        try super.tearDownWithError()
    }
    
    // MARK: - Section Tests
    
    func testAppleSiliconAcceleratedEngineFactoryCreation() {
        let factory = AppleSiliconAcceleratedEngineFactory.shared
        XCTAssertNotNil(factory.makeWriter())
        XCTAssertNotNil(factory.makeExtractor())
        XCTAssertNotNil(factory.makeReader())
        XCTAssertNotNil(factory.makeIntegrityChecker())
        XCTAssertNotNil(factory.makeHashCalculator())
        XCTAssertNotNil(factory.tuner)
    }
    
    func testStandardPortableEngineFactoryCreation() {
        let factory = StandardPortableEngineFactory.shared
        XCTAssertNotNil(factory.makeWriter())
        XCTAssertNotNil(factory.makeExtractor())
        XCTAssertNotNil(factory.makeReader())
        XCTAssertNotNil(factory.makeIntegrityChecker())
        XCTAssertNotNil(factory.makeHashCalculator())
        XCTAssertNotNil(factory.tuner)
        XCTAssertGreaterThan(factory.tuner.totalCores, 0)
        XCTAssertEqual(factory.tuner.optimalAlignedBufferSize, 64 * 1024)
    }
    
    // MARK: - ArchiveEngineFamilyProvider
    
    func testEngineFamilyProviderModeSwitching() {
        let provider = ArchiveEngineFamilyProvider.shared
        
        provider.mode = .appleSiliconAccelerated
        XCTAssertTrue(provider.currentFactory is AppleSiliconAcceleratedEngineFactory)
        
        provider.mode = .standardPortable
        XCTAssertTrue(provider.currentFactory is StandardPortableEngineFactory)
        
        provider.mode = .auto
        if provider.isAppleSiliconEnvironment {
            XCTAssertTrue(provider.currentFactory is AppleSiliconAcceleratedEngineFactory)
        } else {
            XCTAssertTrue(provider.currentFactory is StandardPortableEngineFactory)
        }
    }
    
    func testEngineFamilyProviderOverrideFactory() {
        let provider = ArchiveEngineFamilyProvider.shared
        let customPortable = StandardPortableEngineFactory()
        
        provider.setOverrideFactory(customPortable)
        XCTAssertTrue(provider.currentFactory is StandardPortableEngineFactory)
        
        provider.setOverrideFactory(nil)
        provider.mode = .appleSiliconAccelerated
        XCTAssertTrue(provider.currentFactory is AppleSiliconAcceleratedEngineFactory)
    }
    
    func testEngineFamilyProviderReset() {
        let provider = ArchiveEngineFamilyProvider.shared
        provider.mode = .standardPortable
        provider.setOverrideFactory(StandardPortableEngineFactory.shared)
        
        provider.reset()
        
        XCTAssertEqual(provider.mode, .auto)
        if provider.isAppleSiliconEnvironment {
            XCTAssertTrue(provider.currentFactory is AppleSiliconAcceleratedEngineFactory)
        } else {
            XCTAssertTrue(provider.currentFactory is StandardPortableEngineFactory)
        }
    }
    
    func testDefaultEngineTunerDecoupling() {
        let provider = ArchiveEngineFamilyProvider.shared
        provider.mode = .standardPortable
        
        let writer = ArchiveWriter()
        XCTAssertTrue(writer.hardwareTuner is StandardPortableTuner)
        
        let extractor = ArchiveExtractor()
        XCTAssertTrue(extractor.hardwareTuner is StandardPortableTuner)
        
        let reader = ArchiveReader()
        XCTAssertTrue(reader.hardwareTuner is StandardPortableTuner)
        
        let hasher = HashCalculator()
        XCTAssertTrue(hasher.hardwareTuner is StandardPortableTuner)
    }
    
    // MARK: - End-to-End Pipeline & Family Swapping
    
    func testEndToEndArchiveWorkflowWithPortableFamily() async throws {
        // Standard Portable
        ArchiveEngineFamilyProvider.shared.mode = .standardPortable
        
        let srcFile = (tempDirPath as NSString).appendingPathComponent("test_portable.txt")
        let content = "Abstract Factory Standard Portable Engine Test Content 2026"
        try content.write(toFile: srcFile, atomically: true, encoding: .utf8)
        
        let archivePath = (tempDirPath as NSString).appendingPathComponent("portable_test.zip")
        
        let pipeline = ArchiveOperationPipeline()
        let result = try await pipeline.createArchive(
            outputPath: archivePath,
            format: .zip,
            level: .normal,
            inputPaths: [srcFile]
        )
        XCTAssertGreaterThan(result.compressedBytes, 0)
        
        let extractDir = (tempDirPath as NSString).appendingPathComponent("ExtractedPortable")
        let elapsed = try await pipeline.extractArchive(archivePath: archivePath, destinationDir: extractDir)
        XCTAssertGreaterThan(elapsed, 0)
        
        let extractedFile = (extractDir as NSString).appendingPathComponent("test_portable.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        
        // Verify expected invariant
        let reader = ArchiveEngineFactory.makeReader()
        let entries = try await reader.inspect(archivePath: archivePath)
        XCTAssertFalse(entries.isEmpty)
        
        let checker = ArchiveEngineFactory.makeIntegrityChecker()
        let crc = checker.computeCRC32(filePath: extractedFile)
        XCTAssertFalse(crc.isEmpty)
    }
    
    func testEndToEndArchiveWorkflowWithAcceleratedFamily() async throws {
        // Apple Silicon Accelerated
        ArchiveEngineFamilyProvider.shared.mode = .appleSiliconAccelerated
        
        let srcFile = (tempDirPath as NSString).appendingPathComponent("test_accelerated.txt")
        let content = "Abstract Factory Apple Silicon Accelerated Engine Test Content 2026"
        try content.write(toFile: srcFile, atomically: true, encoding: .utf8)
        
        let archivePath = (tempDirPath as NSString).appendingPathComponent("accelerated_test.zip")
        
        let factory = ArchiveEngineFactory.currentFamilyFactory
        let writer = factory.makeWriter()
        try await writer.createArchive(
            outputPath: archivePath,
            format: .zip,
            level: .normal,
            inputPaths: [srcFile]
        )
        
        let extractDir = (tempDirPath as NSString).appendingPathComponent("ExtractedAccelerated")
        let extractor = factory.makeExtractor()
        try await extractor.extract(archivePath: archivePath, destinationDir: extractDir)
        
        let extractedFile = (extractDir as NSString).appendingPathComponent("test_accelerated.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        
        let hasher = factory.makeHashCalculator()
        let sha256 = try await hasher.computeHash(filePath: extractedFile, type: .sha256)
        XCTAssertEqual(sha256.count, 64)
    }
}
