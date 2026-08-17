import Foundation
import XCTest
import CTTZipBridge

/// 单项格式测试配置定义
public struct FormatDiagnosticConfig: Sendable {
    public let format: ArchiveCompressionFormat
    public let levelsToTest: [ArchiveCompressionLevel]
    public let testPasswordEncryption: Bool
    public let passwordToTest: String
    public let sampleFileCount: Int
    public let lineRepeatCount: Int
    
    public init(
        format: ArchiveCompressionFormat,
        levelsToTest: [ArchiveCompressionLevel] = [.store, .level1, .level6, .level9],
        testPasswordEncryption: Bool = true,
        passwordToTest: String = "TTZipTestPassword#2026!",
        sampleFileCount: Int = 100,
        lineRepeatCount: Int = 2000
    ) {
        self.format = format
        self.levelsToTest = format.supportedLevels.filter { levelsToTest.contains($0) }
        self.testPasswordEncryption = testPasswordEncryption && format.supportsPasswordEncryption
        self.passwordToTest = passwordToTest
        self.sampleFileCount = sampleFileCount
        self.lineRepeatCount = lineRepeatCount
    }
}

/// 全格式通用单项诊断测试运行引擎 (统一封装 数据集生成、打包、解压与 100% 精准 CRC32 校验)
public final class FormatDiagnosticSuiteRunner: @unchecked Sendable {
    public static let shared = FormatDiagnosticSuiteRunner()
    
    private init() {}
    
    /// 运行指定格式的单项物理打包解压诊断测试
    @discardableResult
    public func runDiagnosticSuite(config: FormatDiagnosticConfig) throws -> Bool {
        let fmt = config.format
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("\(fmt.rawValue.capitalized)Debug_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }
        
        let sourceFolder = tempDir.appendingPathComponent("small_files")
        try fm.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        
        // 1. 统一生成标准测试数据集
        let line = "Apple Silicon TTZip High-Precision \(fmt.rawValue.uppercased()) Diagnostic Benchmark Line...\n"
        let sampleContent = String(repeating: line, count: config.lineRepeatCount)
        let sampleData = sampleContent.data(using: .utf8)!
        let singleFileSize = Int64(sampleData.count)
        
        for i in 0..<config.sampleFileCount {
            let fURL = sourceFolder.appendingPathComponent("file_\(i).txt")
            try sampleData.write(to: fURL)
        }
        let expectedTotalBytes = singleFileSize * Int64(config.sampleFileCount)
        
        SingleTestDiagnosticRunner.shared.logBanner(
            format: fmt,
            level: config.levelsToTest.first ?? .store,
            password: config.testPasswordEncryption ? config.passwordToTest : nil,
            sandboxPath: tempDir.path
        )
        TTLogger.info("  - 数据集就绪: 路径 \(sourceFolder.path) | 总计 \(config.sampleFileCount) 个文件 | 期望字节数: \(expectedTotalBytes)")
        
        let writer = ArchiveEngineFactory.makeWriter(for: fmt)
        let extractor = ArchiveEngineFactory.makeExtractor(for: fmt)
        let checker = ArchiveEngineFactory.makeIntegrityChecker()
        var allPassed = true
        
        // 2. 遍历测试选定的压缩级别
        for level in config.levelsToTest {
            TTLogger.info("\n🔍 [\(fmt.rawValue.uppercased()) 诊断测试] 尝试 \(level.title) (Level \(level.rawValue)) 打包与解压...")
            let archiveName = "archive_\(level.rawValue)\(fmt.fileExtension)"
            let archivePath = tempDir.appendingPathComponent(archiveName).path
            
            let startCompress = Date()
            do {
                try writer.createArchiveSync(
                    outputPath: archivePath,
                    format: fmt,
                    level: level,
                    inputPaths: [sourceFolder.path]
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .compressionExecution,
                    format: fmt,
                    level: level,
                    error: error,
                    errorMessage: "压缩打包阶段捕获异常",
                    archivePath: archivePath,
                    sandboxPath: tempDir.path
                )
                allPassed = false
                continue
            }
            
            let compressDuration = max(0.001, Date().timeIntervalSince(startCompress))
            let archiveSize = (try? fm.attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0
            if archiveSize == 0 {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .archiveValidation,
                    format: fmt,
                    level: level,
                    errorMessage: "生成的归档压缩包大小为 0 字节",
                    archivePath: archivePath,
                    sandboxPath: tempDir.path
                )
                allPassed = false
                continue
            }
            
            let compressMBs = (Double(expectedTotalBytes) / (1024 * 1024)) / compressDuration
            TTLogger.info("  - \(fmt.rawValue.uppercased()) \(level.title) 打包成功, 压缩包大小: \(archiveSize) 字节 | 耗时: \(String(format: "%.3f", compressDuration))s (\(String(format: "%.1f", compressMBs)) MB/s)")
            
            let outDir = tempDir.appendingPathComponent("out_\(level.rawValue)").path
            try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            
            let startExtract = Date()
            do {
                try extractor.extractSync(
                    archivePath: archivePath,
                    destinationDir: outDir
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .extractionExecution,
                    format: fmt,
                    level: level,
                    error: error,
                    errorMessage: "解压缩提解阶段捕获异常",
                    archivePath: archivePath,
                    destinationDir: outDir,
                    sandboxPath: tempDir.path
                )
                allPassed = false
                continue
            }
            let extractDuration = max(0.001, Date().timeIntervalSince(startExtract))
            let extractMBs = (Double(expectedTotalBytes) / (1024 * 1024)) / extractDuration
            TTLogger.info("  - 解压完成, 提解耗时: \(String(format: "%.3f", extractDuration))s (\(String(format: "%.1f", extractMBs)) MB/s)")
            
            let res = checker.verifyExtractedDirectory(
                directoryPath: outDir,
                expectedOriginalBytes: expectedTotalBytes,
                sourceFilePath: sourceFolder.path,
                label: "\(fmt.rawValue.uppercased()) \(level.title)"
            )
            if !res.isValid {
                allPassed = false
            }
        }
        
        // 3. 若支持密码加密，测试密码加密打包与解压
        if config.testPasswordEncryption {
            let encLevel: ArchiveCompressionLevel = config.levelsToTest.contains(.level1) ? .level1 : (config.levelsToTest.first ?? .store)
            TTLogger.info("\n🔍 [\(fmt.rawValue.uppercased()) 诊断测试] 尝试 AES-256 加密 \(encLevel.title) 打包与解压...")
            let encArchiveName = "archive_enc\(fmt.fileExtension)"
            let encArchivePath = tempDir.appendingPathComponent(encArchiveName).path
            
            do {
                try writer.createArchiveSync(
                    outputPath: encArchivePath,
                    format: fmt,
                    level: encLevel,
                    inputPaths: [sourceFolder.path],
                    password: config.passwordToTest
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .compressionExecution,
                    format: fmt,
                    level: encLevel,
                    password: config.passwordToTest,
                    error: error,
                    errorMessage: "加密打包阶段捕获异常",
                    archivePath: encArchivePath,
                    sandboxPath: tempDir.path
                )
                return false
            }
            
            let encOutDir = tempDir.appendingPathComponent("out_enc").path
            try fm.createDirectory(atPath: encOutDir, withIntermediateDirectories: true)
            
            do {
                try extractor.extractSync(
                    archivePath: encArchivePath,
                    destinationDir: encOutDir,
                    password: config.passwordToTest
                )
            } catch {
                SingleTestDiagnosticRunner.shared.reportFailure(
                    stage: .extractionExecution,
                    format: fmt,
                    level: encLevel,
                    password: config.passwordToTest,
                    error: error,
                    errorMessage: "加密解压阶段捕获异常",
                    archivePath: encArchivePath,
                    destinationDir: encOutDir,
                    sandboxPath: tempDir.path
                )
                return false
            }
            
            let encRes = checker.verifyExtractedDirectory(
                directoryPath: encOutDir,
                expectedOriginalBytes: expectedTotalBytes,
                sourceFilePath: sourceFolder.path,
                label: "\(fmt.rawValue.uppercased()) AES-256 加密"
            )
            if !encRes.isValid {
                allPassed = false
            }
        }
        
        TTLogger.info("--------------------------------------------------------------------------------\n")
        return allPassed
    }
}
