import Foundation

/// Swift 6 线程安全 Sync 包装 Task 结果承载器
public final class SyncResultBox: @unchecked Sendable {
    public var result: WorkflowResult?
    public var error: Error?
    public init() {}
}

/// 归档处理工作流执行结果
public struct WorkflowResult: Sendable, Equatable {
    public var isSuccess: Bool
    public var outputPath: String
    public var destinationDir: String
    public var processedBytes: Int64
    public var compressedBytes: Int64
    public var durationSeconds: Double
    public var unlockedPassword: String?
    public var crc32: String?
    public var sha256: String?
    public var entriesCount: Int
    public var metrics: [String: String]

    public init(
        isSuccess: Bool = true,
        outputPath: String = "",
        destinationDir: String = "",
        processedBytes: Int64 = 0,
        compressedBytes: Int64 = 0,
        durationSeconds: Double = 0.0,
        unlockedPassword: String? = nil,
        crc32: String? = nil,
        sha256: String? = nil,
        entriesCount: Int = 0,
        metrics: [String: String] = [:]
    ) {
        self.isSuccess = isSuccess
        self.outputPath = outputPath
        self.destinationDir = destinationDir
        self.processedBytes = processedBytes
        self.compressedBytes = compressedBytes
        self.durationSeconds = durationSeconds
        self.unlockedPassword = unlockedPassword
        self.crc32 = crc32
        self.sha256 = sha256
        self.entriesCount = entriesCount
        self.metrics = metrics
    }

    public mutating func setMetadata(_ value: String, forKey key: String) {
        metrics[key] = value
    }

    public func getMetadata(forKey key: String) -> String? {
        return metrics[key]
    }
}

/// 模板方法模式归档工作流统一上下文
public final class ArchiveTemplateContext: @unchecked Sendable {
    public let operation: ArchiveOperationType
    public let archivePath: String
    public let inputPaths: [String]
    public let destinationDir: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public var password: String?
    public let options: ArchiveFilterOptions
    public let advancedOptions: ArchiveAdvancedOptions?
    public let splitVolumeSizeBytes: Int64?
    public var tempDir: String?
    public let dictionary: [String]
    public let stateMachine: ArchiveTaskStateMachine?
    public let progressHandler: (@Sendable (ArchiveProgress) -> Void)?

    private var metadata: [String: String] = [:]
    private let metadataLock = NSLock()

    public init(
        operation: ArchiveOperationType,
        archivePath: String = "",
        inputPaths: [String] = [],
        destinationDir: String = "",
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        options: ArchiveFilterOptions = .defaultClean,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        tempDir: String? = nil,
        dictionary: [String] = [],
        stateMachine: ArchiveTaskStateMachine? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) {
        self.operation = operation
        self.archivePath = archivePath
        self.inputPaths = inputPaths
        self.destinationDir = destinationDir
        self.format = format
        self.level = level
        self.password = password
        self.options = options
        self.advancedOptions = advancedOptions
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        self.tempDir = tempDir
        self.dictionary = dictionary
        self.stateMachine = stateMachine
        self.progressHandler = progressHandler
    }

    public func setMetadata(_ value: String, forKey key: String) {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        metadata[key] = value
    }

    public func getMetadata(forKey key: String) -> String? {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        return metadata[key]
    }

    public func getAllMetadata() -> [String: String] {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        return metadata
    }
}

// MARK: - Fluent Builder Extension for ArchiveTemplateContext

/// ArchiveTemplateContext 链式建造者 (Fluent Builder Pattern)
public struct ArchiveTemplateContextBuilder: Sendable {
    public var operation: ArchiveOperationType
    public var archivePath: String = ""
    public var inputPaths: [String] = []
    public var destinationDir: String = ""
    public var format: ArchiveCompressionFormat = .zip
    public var level: ArchiveCompressionLevel = .normal
    public var password: String? = nil
    public var options: ArchiveFilterOptions = .defaultClean
    public var advancedOptions: ArchiveAdvancedOptions? = nil
    public var splitVolumeSizeBytes: Int64? = nil
    public var tempDir: String? = nil
    public var dictionary: [String] = []
    public var stateMachine: ArchiveTaskStateMachine? = nil
    public var progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil

    public init(operation: ArchiveOperationType) {
        self.operation = operation
    }

    public func withArchivePath(_ path: String) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.archivePath = path
        return copy
    }

    public func withInputPaths(_ paths: [String]) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.inputPaths = paths
        return copy
    }

    public func withDestinationDir(_ dir: String) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.destinationDir = dir
        return copy
    }

    public func withFormat(_ format: ArchiveCompressionFormat) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.format = format
        return copy
    }

    public func withLevel(_ level: ArchiveCompressionLevel) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.level = level
        return copy
    }

    public func withPassword(_ pwd: String?) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.password = pwd
        return copy
    }

    public func withFilterOptions(_ options: ArchiveFilterOptions) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.options = options
        return copy
    }

    public func withAdvancedOptions(_ options: ArchiveAdvancedOptions?) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.advancedOptions = options
        return copy
    }

    public func withSplitVolumeSize(_ bytes: Int64?) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.splitVolumeSizeBytes = bytes
        return copy
    }

    public func withProgressHandler(_ handler: (@Sendable (ArchiveProgress) -> Void)?) -> ArchiveTemplateContextBuilder {
        var copy = self
        copy.progressHandler = handler
        return copy
    }

    public func build() -> ArchiveTemplateContext {
        return ArchiveTemplateContext(
            operation: operation,
            archivePath: archivePath,
            inputPaths: inputPaths,
            destinationDir: destinationDir,
            format: format,
            level: level,
            password: password,
            options: options,
            advancedOptions: advancedOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            tempDir: tempDir,
            dictionary: dictionary,
            stateMachine: stateMachine,
            progressHandler: progressHandler
        )
    }
}

public extension ArchiveTemplateContext {
    static func builder(for operation: ArchiveOperationType) -> ArchiveTemplateContextBuilder {
        return ArchiveTemplateContextBuilder(operation: operation)
    }
}
