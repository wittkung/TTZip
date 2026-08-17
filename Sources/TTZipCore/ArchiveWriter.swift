import Foundation
import CryptoKit
import CTTZipBridge

/// 高性能归档文件压缩打包引擎
public final class ArchiveWriter: ArchiveWriting, @unchecked Sendable {
    internal let zipEngine: ZipEngineProtocol
    internal let sevenZipEngine: SevenZipEngineProtocol
    internal let zstdEngine: ZstdEngineProtocol
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?
    
    public init(
        zipEngine: ZipEngineProtocol = NativeZipEngine.shared,
        sevenZipEngine: SevenZipEngineProtocol = SevenZipParallelWriter.shared,
        zstdEngine: ZstdEngineProtocol = NativeZstdEngine.shared,
        hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.zipEngine = zipEngine
        self.sevenZipEngine = sevenZipEngine
        self.zstdEngine = zstdEngine
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }
    
    /// 异步将指定输入文件路径列表打包压缩为目标归档文件
    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let valCtx = ArchiveValidationContext.forCompress(
            sourcePaths: inputPaths,
            destinationPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitVolumeSizeBytes,
            options: ArchiveValidationOptions(
                isSplit: splitVolumeSizeBytes != nil && splitVolumeSizeBytes! > 0,
                splitVolumeSizeBytes: splitVolumeSizeBytes,
                isEncrypted: password != nil && !password!.isEmpty,
                compressionLevel: level,
                skipMacJunk: options.skipMacJunk,
                format: format
            )
        )
        try ArchiveValidationPipeline.buildDefaultCompressPipeline().validateOrThrow(context: valCtx)
        
        if level == .ultra && !LicenseManager.shared.canUseFeature(.ultraCompression) {
            throw ArchiveError.readFailed(code: -403)
        }
        
        try Task.checkCancellation()
        
        let template = ArchiveEngineTemplateRegistry.shared.template(for: format)
        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: format,
            level: level,
            password: password,
            options: options,
            advancedOptions: advancedOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            progressHandler: progressHandler
        )
        _ = try await template.performWorkflowAsync(context: context)
    }

    /// 同步创建归档文件 (零 Swift Task 队列切换开销，模板方法驱动)
    @inline(__always)
    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        let template = ArchiveEngineTemplateRegistry.shared.template(for: format)
        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: format,
            level: level,
            password: password,
            options: options,
            advancedOptions: advancedOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            progressHandler: progressHandler
        )
        _ = try template.performWorkflow(context: context)
    }

    /// 【3.6 模板方法模式 (Template Method Pattern)】使用算法骨架进行归档压缩打包
    public func createArchiveViaTemplate(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> WorkflowResult {
        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: format,
            level: level,
            password: password,
            options: options,
            advancedOptions: advancedOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            progressHandler: progressHandler
        )
        let template = ArchiveEngineTemplateRegistry.shared.template(for: format)
        return try template.performWorkflow(context: context)
    }
}



