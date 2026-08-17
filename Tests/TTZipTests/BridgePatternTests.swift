import XCTest
@testable import TTZipCore

final class BridgePatternTests: XCTestCase {
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

    // MARK: - 1. 具体格式 Bridge Implementor 单元测试

    func testZipEngineBridgeImplementorCompressAndExtract() async throws {
        let file1 = try createTestFile(filename: "bridge_zip_test.txt", content: "Bridge Pattern Zip Compression Test Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("output_bridge.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("extract_zip")

        let implementor: ArchiveEngineImplementorProtocol = ZipEngineBridgeImplementor()
        XCTAssertEqual(implementor.supportedFormat, .zip)

        let bytesWritten = try await implementor.compressStream(
            inputPaths: [file1],
            outputPath: zipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipOutput))

        let bytesExtracted = try await implementor.extractStream(
            archivePath: zipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))
    }

    func testSevenZipEngineBridgeImplementorCompressAndExtract() async throws {
        let file1 = try createTestFile(filename: "bridge_7z_test.txt", content: "Bridge Pattern 7z Compression Test Content")
        let sevenZipOutput = (tempDir as NSString).appendingPathComponent("output_bridge.7z")
        let extractDir = (tempDir as NSString).appendingPathComponent("extract_7z")

        let implementor: ArchiveEngineImplementorProtocol = SevenZipEngineBridgeImplementor()
        XCTAssertEqual(implementor.supportedFormat, .sevenZip)

        let bytesWritten = try await implementor.compressStream(
            inputPaths: [file1],
            outputPath: sevenZipOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sevenZipOutput))

        let bytesExtracted = try await implementor.extractStream(
            archivePath: sevenZipOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))
    }

    func testZstdEngineBridgeImplementorCompressAndExtract() async throws {
        let file1 = try createTestFile(filename: "bridge_zstd_test.txt", content: "Bridge Pattern Zstd Compression Test Content")
        let zstdOutput = (tempDir as NSString).appendingPathComponent("output_bridge.zst")
        let extractDir = (tempDir as NSString).appendingPathComponent("extract_zstd")

        let implementor: ArchiveEngineImplementorProtocol = ZstdEngineBridgeImplementor()
        XCTAssertEqual(implementor.supportedFormat, .zst)

        let bytesWritten = try await implementor.compressStream(
            inputPaths: [file1],
            outputPath: zstdOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zstdOutput))

        let bytesExtracted = try await implementor.extractStream(
            archivePath: zstdOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))
    }

    func testTarEngineBridgeImplementorCompressAndExtract() async throws {
        let file1 = try createTestFile(filename: "bridge_tar_test.txt", content: "Bridge Pattern Tar Compression Test Content")
        let tarOutput = (tempDir as NSString).appendingPathComponent("output_bridge.tar")
        let extractDir = (tempDir as NSString).appendingPathComponent("extract_tar")

        let implementor: ArchiveEngineImplementorProtocol = TarEngineBridgeImplementor()
        XCTAssertEqual(implementor.supportedFormat, .tar)

        let bytesWritten = try await implementor.compressStream(
            inputPaths: [file1],
            outputPath: tarOutput,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tarOutput))

        let bytesExtracted = try await implementor.extractStream(
            archivePath: tarOutput,
            destinationDir: extractDir,
            options: .defaultOptions
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractDir))
    }

    // MARK: - 2. 桥接模式高层抽象与动态切换测试 (Bridge Abstraction & Dynamic Swapping)

    func testArchiveOperationAbstractionDynamicImplementorSwapping() async throws {
        let file1 = try createTestFile(filename: "dynamic_swap_test.txt", content: "Dynamic Bridge Implementor Swapping Content")
        let zipOutput = (tempDir as NSString).appendingPathComponent("dynamic_zip.zip")
        let sevenZipOutput = (tempDir as NSString).appendingPathComponent("dynamic_7z.7z")

        // 1. 初始化 Abstraction，持有一个 ZipImplementor
        let zipImplementor = ZipEngineBridgeImplementor()
        let abstraction = ArchiveOperationAbstraction(implementor: zipImplementor)
        XCTAssertEqual(abstraction.implementor.supportedFormat, .zip)

        let zipBytes = try await abstraction.compress(inputPaths: [file1], outputPath: zipOutput)
        XCTAssertGreaterThan(zipBytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipOutput))

        // 2. 动态解耦切换为 SevenZipImplementor
        let sevenZipImplementor = SevenZipEngineBridgeImplementor()
        abstraction.setImplementor(sevenZipImplementor)
        XCTAssertEqual(abstraction.implementor.supportedFormat, .sevenZip)

        let szBytes = try await abstraction.compress(inputPaths: [file1], outputPath: sevenZipOutput)
        XCTAssertGreaterThan(szBytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sevenZipOutput))
    }

    func testAdvancedArchiveOperationPipelineAbstractionMetrics() async throws {
        let file1 = try createTestFile(filename: "metrics_test.txt", content: String(repeating: "TTZip Metrics Bridge Test ", count: 100))
        let outputPath = (tempDir as NSString).appendingPathComponent("metrics_output.zip")
        let extractDir = (tempDir as NSString).appendingPathComponent("metrics_extract")

        let pipeline = AdvancedArchiveOperationPipelineAbstraction(implementor: ZipEngineBridgeImplementor())

        let (bytesWritten, duration, throughput) = try await pipeline.compressWithMetrics(
            inputPaths: [file1],
            outputPath: outputPath
        )
        XCTAssertGreaterThan(bytesWritten, 0)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertGreaterThanOrEqual(throughput, 0)

        let (bytesExtracted, extDuration, extThroughput) = try await pipeline.extractWithMetrics(
            archivePath: outputPath,
            destinationDir: extractDir
        )
        XCTAssertGreaterThan(bytesExtracted, 0)
        XCTAssertGreaterThan(extDuration, 0)
        XCTAssertGreaterThanOrEqual(extThroughput, 0)
    }

    // MARK: - 3. 工厂模式与策略模式 Bridge 集成测试

    func testArchiveEngineFactoryMakeBridgeComponents() {
        let zipImpl = ArchiveEngineFactory.makeImplementor(for: .zip)
        XCTAssertEqual(zipImpl.supportedFormat, .zip)
        XCTAssertTrue(zipImpl is ZipEngineBridgeImplementor)

        let szImpl = ArchiveEngineFactory.makeImplementor(for: .sevenZip)
        XCTAssertEqual(szImpl.supportedFormat, .sevenZip)
        XCTAssertTrue(szImpl is SevenZipEngineBridgeImplementor)

        let zstdImpl = ArchiveEngineFactory.makeImplementor(for: .zst)
        XCTAssertEqual(zstdImpl.supportedFormat, .zst)
        XCTAssertTrue(zstdImpl is ZstdEngineBridgeImplementor)

        let tarImpl = ArchiveEngineFactory.makeImplementor(for: .tar)
        XCTAssertEqual(tarImpl.supportedFormat, .tar)
        XCTAssertTrue(tarImpl is TarEngineBridgeImplementor)

        let zipAbs = ArchiveEngineFactory.makeOperationAbstraction(for: .zip)
        XCTAssertEqual(zipAbs.implementor.supportedFormat, .zip)
    }

    func testArchiveEngineStrategyBridgeIntegration() {
        let zipStrategy = ZipFormatEngineStrategy()
        XCTAssertEqual(zipStrategy.bridgeImplementor.supportedFormat, .zip)

        let sevenZipStrategy = SevenZipFormatEngineStrategy()
        XCTAssertEqual(sevenZipStrategy.bridgeImplementor.supportedFormat, .sevenZip)

        let tarStrategy = TarFormatEngineStrategy()
        XCTAssertEqual(tarStrategy.bridgeImplementor.supportedFormat, .tar)

        let zstdStrategy = ZstdFormatEngineStrategy()
        XCTAssertEqual(zstdStrategy.bridgeImplementor.supportedFormat, .zst)
    }

    // MARK: - 4. 抽象工厂与 Bridge 闭环与多线程 Data Race 保护测试

    func testArchiveOperationAbstractionConcurrentDataRaceProtection() async throws {
        let zipImpl = ZipEngineBridgeImplementor()
        let szImpl = SevenZipEngineBridgeImplementor()
        let zstdImpl = ZstdEngineBridgeImplementor()
        let abstraction = ArchiveOperationAbstraction(implementor: zipImpl)

        // 高并发多线程重写入与多线程读取并发测试，验证 NSLock 锁保护防 Data Race
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    if i % 3 == 0 {
                        abstraction.setImplementor(szImpl)
                    } else if i % 3 == 1 {
                        abstraction.setImplementor(zstdImpl)
                    } else {
                        abstraction.setImplementor(zipImpl)
                    }
                    _ = abstraction.implementor.supportedFormat
                }
            }
        }

        XCTAssertNotNil(abstraction.implementor)
    }

    func testEngineFamilyFactoryMakeImplementor() {
        let appleFactory: ArchiveEngineFamilyFactoryProtocol = AppleSiliconAcceleratedEngineFactory.shared
        let zipImpl = appleFactory.makeImplementor(for: .zip)
        XCTAssertEqual(zipImpl.supportedFormat, .zip)

        let portableFactory: ArchiveEngineFamilyFactoryProtocol = StandardPortableEngineFactory.shared
        let szImpl = portableFactory.makeImplementor(for: .sevenZip)
        XCTAssertEqual(szImpl.supportedFormat, .sevenZip)
    }
}
