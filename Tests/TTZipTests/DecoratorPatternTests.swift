// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _progresses: [ArchiveProgress] = []
    private var _count: Int = 0

    func record(_ progress: ArchiveProgress) {
        lock.lock()
        _progresses.append(progress)
        _count += 1
        lock.unlock()
    }

    var last: ArchiveProgress? {
        lock.lock()
        defer { lock.unlock() }
        return _progresses.last
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
}

final class DecoratorPatternTests: XCTestCase {
    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    private func createTestFile(filename: String, content: String) throws -> String {
        let path = (tempDir as NSString).appendingPathComponent(filename)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - 1. Base Decorator Passthrough

    func testBaseArchiveOperationDecoratorPassthrough() async throws {
        let file1 = try createTestFile(filename: "decorator_base.txt", content: "Base Decorator Passthrough Test Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("base_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("base_extract")

        let baseImplementor = ZipEngineBridgeImplementor()
        let decorator = ArchiveOperationDecorator(inner: baseImplementor)

        XCTAssertEqual(decorator.supportedFormat, .zip)

        let bytesWritten = try await decorator.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipOutput))

        let bytesExtracted = try await decorator.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))
    }

    // MARK: - 2. EncryptionDecorator

    func testEncryptionDecoratorPassthroughAndEncryptionConfig() async throws {
        let file1 = try createTestFile(filename: "encrypted_file.txt", content: "Top Secret Decoded Content for Decorator")
        let zipOutput = (tempDir as NSString).appendingPathComponent("encrypted_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("encrypted_extract")

        let baseImplementor = ZipEngineBridgeImplementor()
        let encDecorator = EncryptionDecorator(inner: baseImplementor, password: "SecretPassword123")

        let bytesWritten = try await encDecorator.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipOutput))

        let bytesExtracted = try await encDecorator.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))
    }

    // MARK: - 3. ProgressMonitoringDecorator ETA

    func testProgressMonitoringDecoratorProgressReporting() async throws {
        let file1 = try createTestFile(filename: "progress_file.txt", content: String(repeating: "Progress Decorator Payload ", count: 200))
        let zipOutput = (tempDir as NSString).appendingPathComponent("progress_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("progress_extract")

        let recorder = ProgressRecorder()
        let baseImplementor = ZipEngineBridgeImplementor()
        let progressDecorator = ProgressMonitoringDecorator(inner: baseImplementor) { progress in
            recorder.record(progress)
        }

        let bytesWritten = try await progressDecorator.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)

        let bytesExtracted = try await progressDecorator.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)

        XCTAssertGreaterThan(recorder.count, 0)
        XCTAssertEqual(recorder.last?.state, .completed)
    }

    // MARK: - 4. SplitVolumeDecorator

    func testSplitVolumeDecoratorMultiVolumeHandling() async throws {
        let file1 = try createTestFile(filename: "split_file.txt", content: "Split Volume Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("split_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("split_extract")

        let baseImplementor = ZipEngineBridgeImplementor()
        let splitDecorator = SplitVolumeDecorator(inner: baseImplementor, splitVolumeSizeBytes: 1024 * 1024)

        XCTAssertEqual(splitDecorator.splitVolumeSizeBytes, 1024 * 1024)

        let bytesWritten = try await splitDecorator.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)

        let bytesExtracted = try await splitDecorator.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
    }

    // MARK: - 5. ChecksumVerificationDecorator

    func testChecksumVerificationDecoratorHashComputation() async throws {
        let file1 = try createTestFile(filename: "checksum_file.txt", content: "Checksum Integrity Test Data Payload")
        let zipOutput = (tempDir as NSString).appendingPathComponent("checksum_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("checksum_extract")

        let baseImplementor = ZipEngineBridgeImplementor()
        let checksumDecorator = ChecksumVerificationDecorator(inner: baseImplementor, algorithm: .crc32)

        let bytesWritten = try await checksumDecorator.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertNotNil(checksumDecorator.lastSourceChecksum)
        XCTAssertNotNil(checksumDecorator.lastOutputChecksum)
        XCTAssertTrue(checksumDecorator.isVerified)

        let bytesExtracted = try await checksumDecorator.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertNotNil(checksumDecorator.lastOutputChecksum)
        XCTAssertTrue(checksumDecorator.isVerified)
    }

    // MARK: - 6. PerformanceMetricsDecorator

    func testPerformanceMetricsDecoratorMeasurement() async throws {
        let file1 = try createTestFile(filename: "metrics_file.txt", content: String(repeating: "TTZip Performance Metrics Test ", count: 300))
        let zipOutput = (tempDir as NSString).appendingPathComponent("metrics_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("metrics_extract")

        let baseImplementor = ZipEngineBridgeImplementor()
        let metricsDecorator = PerformanceMetricsDecorator(inner: baseImplementor)

        let bytesWritten = try await metricsDecorator.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)

        guard let cMetrics = metricsDecorator.lastCompressMetrics else {
            XCTFail("lastCompressMetrics should not be nil")
            return
        }
        XCTAssertEqual(cMetrics.bytesProcessed, bytesWritten)
        XCTAssertGreaterThan(cMetrics.durationSeconds, 0)
        XCTAssertGreaterThanOrEqual(cMetrics.throughputMBs, 0)

        let bytesExtracted = try await metricsDecorator.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)

        guard let eMetrics = metricsDecorator.lastExtractMetrics else {
            XCTFail("lastExtractMetrics should not be nil")
            return
        }
        XCTAssertEqual(eMetrics.bytesProcessed, bytesExtracted)
        XCTAssertGreaterThan(eMetrics.durationSeconds, 0)
        XCTAssertGreaterThanOrEqual(eMetrics.throughputMBs, 0)
    }

    // MARK: - 7. 5 Decorator Chain Composition

    func testDecoratorChainComposition() async throws {
        let file1 = try createTestFile(filename: "chain_file.txt", content: "Decorator Chain Multi-Layer Dynamic Overlay Test Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("chain_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("chain_extract")

        let progressCount = SafeAtomicInt64(0)
        let baseImplementor = ZipEngineBridgeImplementor()

        // 5 Decorator Chain
        let decoratedEngine = baseImplementor
            .withEncryption(password: "ChainPwd")
            .withSplitVolume(splitVolumeSizeBytes: 10 * 1024 * 1024)
            .withProgressMonitoring(progressHandler: { _ in progressCount.val += 1 })
            .withChecksumVerification(algorithm: .crc32)
            .withPerformanceMetrics()

        let bytesWritten = try await decoratedEngine.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipOutput))

        let bytesExtracted = try await decoratedEngine.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))

        // Metrics
        XCTAssertNotNil(decoratedEngine.lastCompressMetrics)
        XCTAssertNotNil(decoratedEngine.lastExtractMetrics)
    }

    // MARK: - 8. ArchiveEngineFactory

    func testArchiveEngineFactoryMakeDecoratedImplementor() async throws {
        let file1 = try createTestFile(filename: "factory_dec_file.txt", content: "Factory Decorated Implementor Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("factory_dec_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("factory_dec_extract")

        let engine = ArchiveEngineFactory.makeDecoratedImplementor(
            for: .zip,
            password: "FactoryPassword",
            splitVolumeSizeBytes: 5 * 1024 * 1024,
            progressHandler: { _ in },
            enableChecksum: true,
            enableMetrics: true
        )

        let bytesWritten = try await engine.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)

        let bytesExtracted = try await engine.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
    }

    // MARK: - 9. ArchivePipelineBuilder Builder

    func testArchivePipelineBuilderDecoratedImplementorIntegration() async throws {
        let file1 = try createTestFile(filename: "builder_dec_file.txt", content: "Builder Decorated Implementor Integration Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("builder_dec_out.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("builder_dec_extract")

        let engine = ArchiveOperationPipeline.builder()
            .withFormat(.zip)
            .withPassword("BuilderPwd")
            .withSplitVolumeSize(20 * 1024 * 1024)
            .buildDecoratedImplementor()

        let bytesWritten = try await engine.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)

        let bytesExtracted = try await engine.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
    }
}
