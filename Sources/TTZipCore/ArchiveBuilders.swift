import Foundation

/// 针对归档高级配置参数的链式建造者 (Fluent Builder Pattern)
public struct ArchiveOptionsBuilder: Sendable, Equatable {
    public var format: ArchiveCompressionFormat?
    public var level: ArchiveCompressionLevel?
    public var password: String?
    public var cpuThreads: Int
    public var zipOptions: ZipFormatOptions
    public var sevenZipOptions: SevenZipFormatOptions
    public var zstdOptions: ZstdFormatOptions
    public var tarOptions: TarFormatOptions
    public var appleArchiveOptions: AppleArchiveFormatOptions
    public var diskImageOptions: DiskImageFormatOptions
    public var wimOptions: WimFormatOptions
    
    public init(baseOptions: ArchiveAdvancedOptions = .defaultOptions) {
        self.cpuThreads = baseOptions.cpuThreads
        self.zipOptions = baseOptions.zipOptions
        self.sevenZipOptions = baseOptions.sevenZipOptions
        self.zstdOptions = baseOptions.zstdOptions
        self.tarOptions = baseOptions.tarOptions
        self.appleArchiveOptions = baseOptions.appleArchiveOptions
        self.diskImageOptions = baseOptions.diskImageOptions
        self.wimOptions = baseOptions.wimOptions
    }
    
    @discardableResult
    public func withFormat(_ format: ArchiveCompressionFormat) -> ArchiveOptionsBuilder {
        var copy = self
        copy.format = format
        return copy
    }
    
    @discardableResult
    public func withLevel(_ level: ArchiveCompressionLevel) -> ArchiveOptionsBuilder {
        var copy = self
        copy.level = level
        return copy
    }
    
    @discardableResult
    public func withPassword(_ password: String?) -> ArchiveOptionsBuilder {
        var copy = self
        copy.password = password
        return copy
    }
    
    @discardableResult
    public func withCpuThreads(_ threads: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.cpuThreads = threads
        return copy
    }
    
    @discardableResult
    public func withSolidArchive(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.enableSolidArchive = enable
        return copy
    }
    
    @discardableResult
    public func withZipEncryption(_ method: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.zipEncryptionMethod = method
        return copy
    }
    
    @discardableResult
    public func withZstdLevel(_ level: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdLevel = level
        return copy
    }
    
    @discardableResult
    public func withZipEncodingUTF8(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.zipEncodingUTF8 = enable
        return copy
    }
    
    @discardableResult
    public func withPreservePosixAttributes(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.preservePosixAttributes = enable
        return copy
    }
    
    @discardableResult
    public func withZip64Mode(_ mode: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.zip64Mode = mode
        return copy
    }
    
    @discardableResult
    public func withEnableZeroCopy(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zipOptions.enableZeroCopy = enable
        return copy
    }
    
    @discardableResult
    public func withAlgorithm(_ algorithm: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.algorithm = algorithm
        return copy
    }
    
    @discardableResult
    public func withDictionarySizeMB(_ sizeMB: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.dictionarySizeMB = sizeMB
        return copy
    }
    
    @discardableResult
    public func withEncryptFileNames(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.encryptFileNames = enable
        return copy
    }
    
    @discardableResult
    public func withMatchFinder(_ matchFinder: String) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.matchFinder = matchFinder
        return copy
    }
    
    @discardableResult
    public func withNumFastBytes(_ numFastBytes: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.sevenZipOptions.numFastBytes = numFastBytes
        return copy
    }
    
    @discardableResult
    public func withZstdEnableLDM(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdEnableLDM = enable
        return copy
    }
    
    @discardableResult
    public func withZstdJobSizeMB(_ sizeMB: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdJobSizeMB = sizeMB
        return copy
    }
    
    @discardableResult
    public func withZstdWindowLog(_ windowLog: Int) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdWindowLog = windowLog
        return copy
    }
    
    @discardableResult
    public func withZstdChecksum(_ enable: Bool) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdChecksum = enable
        return copy
    }
    
    @discardableResult
    public func withZstdDictPath(_ path: String?) -> ArchiveOptionsBuilder {
        var copy = self
        copy.zstdOptions.zstdDictPath = path
        return copy
    }
    
    @discardableResult
    public func withTarOptions(_ options: TarFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.tarOptions = options
        return copy
    }
    
    @discardableResult
    public func withAppleArchiveOptions(_ options: AppleArchiveFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.appleArchiveOptions = options
        return copy
    }
    
    @discardableResult
    public func withDiskImageOptions(_ options: DiskImageFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.diskImageOptions = options
        return copy
    }
    
    @discardableResult
    public func withWimOptions(_ options: WimFormatOptions) -> ArchiveOptionsBuilder {
        var copy = self
        copy.wimOptions = options
        return copy
    }
    
    public func build() -> ArchiveAdvancedOptions {
        return ArchiveAdvancedOptions(
            cpuThreads: cpuThreads,
            zipOptions: zipOptions,
            sevenZipOptions: sevenZipOptions,
            zstdOptions: zstdOptions,
            tarOptions: tarOptions,
            appleArchiveOptions: appleArchiveOptions,
            diskImageOptions: diskImageOptions,
            wimOptions: wimOptions
        )
    }
}

/// 针对归档流水线任务装配的链式建造者 (Fluent Pipeline Builder Pattern)
public struct ArchivePipelineBuilder: Sendable {
    public var writer: ArchiveWriting?
    public var extractor: ArchiveExtracting?
    public var familyFactory: ArchiveEngineFamilyFactoryProtocol?
    public var outputPath: String?
    public var archivePath: String?
    public var destinationDir: String?
    public var inputPaths: [String] = []
    public var format: ArchiveCompressionFormat = .sevenZip
    public var level: ArchiveCompressionLevel = .normal
    public var filterOptions: ArchiveFilterOptions = .defaultClean
    public var splitVolumeSizeBytes: Int64? = nil
    public var password: String? = nil
    public var optionsBuilder: ArchiveOptionsBuilder = ArchiveOptionsBuilder()
    public var progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    
    public init(writer: ArchiveWriting? = nil, extractor: ArchiveExtracting? = nil) {
        self.writer = writer
        self.extractor = extractor
    }
    
    public init(familyFactory: ArchiveEngineFamilyFactoryProtocol) {
        self.familyFactory = familyFactory
        self.writer = familyFactory.makeWriter()
        self.extractor = familyFactory.makeExtractor()
    }
    
    public init(pipeline: ArchiveOperationPipeline) {
        self.writer = pipeline.writer
        self.extractor = pipeline.extractor
    }

    @discardableResult
    public func withCompressionLevel(_ level: ArchiveCompressionLevel) -> ArchivePipelineBuilder {
        return withLevel(level)
    }

    @discardableResult
    public func withSplitVolume(_ bytes: Int64?) -> ArchivePipelineBuilder {
        return withSplitVolumeSize(bytes)
    }
    
    @discardableResult
    public func withWriter(_ writer: ArchiveWriting) -> ArchivePipelineBuilder {
        var copy = self
        copy.writer = writer
        return copy
    }
    
    @discardableResult
    public func withExtractor(_ extractor: ArchiveExtracting) -> ArchivePipelineBuilder {
        var copy = self
        copy.extractor = extractor
        return copy
    }
    
    @discardableResult
    public func withFamilyFactory(_ factory: ArchiveEngineFamilyFactoryProtocol) -> ArchivePipelineBuilder {
        var copy = self
        copy.familyFactory = factory
        copy.writer = factory.makeWriter()
        copy.extractor = factory.makeExtractor()
        return copy
    }
    
    @discardableResult
    public func withOutputPath(_ path: String) -> ArchivePipelineBuilder {
        var copy = self
        copy.outputPath = path
        return copy
    }
    
    @discardableResult
    public func withArchivePath(_ path: String) -> ArchivePipelineBuilder {
        var copy = self
        copy.archivePath = path
        return copy
    }
    
    @discardableResult
    public func withDestinationDir(_ dir: String) -> ArchivePipelineBuilder {
        var copy = self
        copy.destinationDir = dir
        return copy
    }
    
    @discardableResult
    public func withInputPaths(_ paths: [String]) -> ArchivePipelineBuilder {
        var copy = self
        copy.inputPaths = paths
        return copy
    }
    
    @discardableResult
    public func addInputPath(_ path: String) -> ArchivePipelineBuilder {
        var copy = self
        copy.inputPaths.append(path)
        return copy
    }
    
    @discardableResult
    public func withFormat(_ format: ArchiveCompressionFormat) -> ArchivePipelineBuilder {
        var copy = self
        copy.format = format
        copy.optionsBuilder = copy.optionsBuilder.withFormat(format)
        return copy
    }
    
    @discardableResult
    public func withLevel(_ level: ArchiveCompressionLevel) -> ArchivePipelineBuilder {
        var copy = self
        copy.level = level
        copy.optionsBuilder = copy.optionsBuilder.withLevel(level)
        return copy
    }
    
    @discardableResult
    public func withFilterOptions(_ options: ArchiveFilterOptions) -> ArchivePipelineBuilder {
        var copy = self
        copy.filterOptions = options
        return copy
    }
    
    @discardableResult
    public func withSplitVolumeSize(_ bytes: Int64?) -> ArchivePipelineBuilder {
        var copy = self
        copy.splitVolumeSizeBytes = bytes
        return copy
    }
    
    @discardableResult
    public func withPassword(_ password: String?) -> ArchivePipelineBuilder {
        var copy = self
        copy.password = password
        copy.optionsBuilder = copy.optionsBuilder.withPassword(password)
        return copy
    }
    
    @discardableResult
    public func withAdvancedOptions(_ options: ArchiveAdvancedOptions) -> ArchivePipelineBuilder {
        var copy = self
        copy.optionsBuilder = ArchiveOptionsBuilder(baseOptions: options)
        return copy
    }
    
    @discardableResult
    public func withOptionsBuilder(_ builder: ArchiveOptionsBuilder) -> ArchivePipelineBuilder {
        var copy = self
        copy.optionsBuilder = builder
        if let f = builder.format { copy.format = f }
        if let l = builder.level { copy.level = l }
        if let p = builder.password { copy.password = p }
        return copy
    }
    
    @discardableResult
    public func configureOptions(_ configure: (inout ArchiveOptionsBuilder) -> Void) -> ArchivePipelineBuilder {
        var copy = self
        configure(&copy.optionsBuilder)
        if let f = copy.optionsBuilder.format { copy.format = f }
        if let l = copy.optionsBuilder.level { copy.level = l }
        if let p = copy.optionsBuilder.password { copy.password = p }
        return copy
    }
    
    @discardableResult
    public func withProgressHandler(_ handler: @Sendable @escaping (ArchiveProgress) -> Void) -> ArchivePipelineBuilder {
        var copy = self
        copy.progressHandler = handler
        return copy
    }
    
    public func buildPipeline() -> ArchiveOperationPipeline {
        if let ff = familyFactory {
            return ArchiveOperationPipeline(familyFactory: ff)
        } else if let w = writer, let e = extractor {
            return ArchiveOperationPipeline(writer: w, extractor: e)
        } else if let w = writer {
            return ArchiveOperationPipeline(writer: w, extractor: ArchiveEngineFactory.makeExtractor())
        } else if let e = extractor {
            return ArchiveOperationPipeline(writer: ArchiveEngineFactory.makeWriter(), extractor: e)
        } else {
            return ArchiveOperationPipeline()
        }
    }
    
    /// 使用装饰器链 (Decorator Chain) 构建全层解耦与能力动态叠加的归档执行引擎
    public func buildDecoratedImplementor() -> ArchiveEngineImplementorProtocol {
        let finalFormat = optionsBuilder.format ?? format
        let finalPassword = password ?? optionsBuilder.password
        return ArchiveEngineFactory.makeDecoratedImplementor(
            for: finalFormat,
            password: finalPassword,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            progressHandler: progressHandler,
            enableChecksum: true,
            enableMetrics: true
        )
    }
    
    public func executeCreate() async throws -> ArchiveOperationResult {
        guard let outPath = outputPath, !outPath.isEmpty else {
            throw ArchiveError.readFailed(code: -1)
        }
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let pipeline = buildPipeline()
        let finalFormat = optionsBuilder.format ?? format
        let finalLevel = optionsBuilder.level ?? level
        let finalPassword = password ?? optionsBuilder.password
        let advancedOpts = optionsBuilder.build()
        
        return try await pipeline.createArchive(
            outputPath: outPath,
            format: finalFormat,
            level: finalLevel,
            inputPaths: inputPaths,
            options: filterOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: finalPassword,
            advancedOptions: advancedOpts,
            progressHandler: progressHandler
        )
    }
    
    public func executeExtract() async throws -> Double {
        guard let arcPath = archivePath, !arcPath.isEmpty else {
            throw ArchiveError.readFailed(code: -2)
        }
        guard let destDir = destinationDir, !destDir.isEmpty else {
            throw ArchiveError.readFailed(code: -3)
        }
        
        let pipeline = buildPipeline()
        let finalPassword = password ?? optionsBuilder.password
        let advancedOpts = optionsBuilder.build()
        
        return try await pipeline.extractArchive(
            archivePath: arcPath,
            destinationDir: destDir,
            options: filterOptions,
            password: finalPassword,
            advancedOptions: advancedOpts
        )
    }
}

extension ArchiveAdvancedOptions {
    public static func builder() -> ArchiveOptionsBuilder {
        return ArchiveOptionsBuilder()
    }
}

extension ArchiveOperationPipeline {
    public static func builder() -> ArchivePipelineBuilder {
        return ArchivePipelineBuilder()
    }
}
