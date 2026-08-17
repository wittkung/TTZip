import Foundation

/// 本地化 Key 统一协议
public protocol LocaleKeyProtocol: Sendable {
    var rawKey: String { get }
}

/// 强类型命名空间化本地化 Key
public enum L10n {
    
    // MARK: - 通用 Actions & States
    public enum Common: String, LocaleKeyProtocol, CaseIterable {
        case cancel = "common.cancel"
        case ok = "common.ok"
        case done = "common.done"
        case save = "common.save"
        case close = "common.close"
        case retry = "common.retry"
        case success = "common.success"
        case failed = "common.failed"
        case loading = "common.loading"
        case warning = "common.warning"
        case error = "common.error"
        case processing = "common.processing"
        
        public var rawKey: String { rawValue }
    }
    
    // MARK: - 压缩与解压操作 (Archive)
    public enum Archive: String, LocaleKeyProtocol, CaseIterable {
        case compress = "archive.compress"
        case extract = "archive.extract"
        case compressing = "archive.compressing"
        case extracting = "archive.extracting"
        case compressSuccess = "archive.compress_success"
        case extractSuccess = "archive.extract_success"
        case compressFailed = "archive.compress_failed"
        case extractFailed = "archive.extract_failed"
        case passwordRequired = "archive.password_required"
        case incorrectPassword = "archive.incorrect_password"
        case corruptData = "archive.corrupt_data"
        case unsupportedFormat = "archive.unsupported_format"
        case format = "archive.format"
        case compressionLevel = "archive.compression_level"
        case splitVolume = "archive.split_volume"
        case encryption = "archive.encryption"
        
        public var rawKey: String { rawValue }
    }
    
    // MARK: - 命令行 (CLI)
    public enum CLI: String, LocaleKeyProtocol, CaseIterable {
        case usageHeader = "cli.usage_header"
        case subcommands = "cli.subcommands"
        case globalOptions = "cli.global_options"
        case errorMissingArg = "cli.error_missing_arg"
        case errorFileNotFound = "cli.error_file_not_found"
        case errorInvalidFormat = "cli.error_invalid_format"
        case dryRunPrefix = "cli.dry_run_prefix"
        case benchRunning = "cli.bench_running"
        case testSummary = "cli.test_summary"
        
        public var rawKey: String { rawValue }
    }
    
    // MARK: - 性能基准与度量 (Benchmark)
    public enum Benchmark: String, LocaleKeyProtocol, CaseIterable {
        case throughput = "benchmark.throughput"
        case compressionRatio = "benchmark.compression_ratio"
        case duration = "benchmark.duration"
        case memoryUsage = "benchmark.memory_usage"
        case peakThroughput = "benchmark.peak_throughput"
        case speedup = "benchmark.speedup"
        
        public var rawKey: String { rawValue }
    }
    
    // MARK: - 错误代码与多语言描述 (Errors)
    public enum Errors: String, LocaleKeyProtocol, CaseIterable {
        case fileNotFound = "error.file_not_found"
        case permissionDenied = "error.permission_denied"
        case diskFull = "error.disk_full"
        case zipSlipDetected = "error.zip_slip_detected"
        case corruptedHeader = "error.corrupted_header"
        case crcMismatch = "error.crc_mismatch"
        case outOfMemory = "error.out_of_memory"
        case operationCancelled = "error.operation_cancelled"
        
        public var rawKey: String { rawValue }
    }
    
    // MARK: - 偏好设置 (Settings)
    public enum Settings: String, LocaleKeyProtocol, CaseIterable {
        case title = "settings.title"
        case general = "settings.general"
        case language = "settings.language"
        case byteUnits = "settings.byte_units"
        case licenseStatus = "settings.license_status"
        case hardwareTopology = "settings.hardware_topology"
        
        public var rawKey: String { rawValue }
    }
    
    // MARK: - 密码钥匙串 (Vault)
    public enum Vault: String, LocaleKeyProtocol, CaseIterable {
        case title = "vault.title"
        case unlockPrompt = "vault.unlock_prompt"
        case addPassword = "vault.add_password"
        case emptyVault = "vault.empty_vault"
        
        public var rawKey: String { rawValue }
    }
    
    /// 获取全部已定义的 Raw Keys
    public static var allRawKeys: [String] {
        var keys: [String] = []
        keys.append(contentsOf: Common.allCases.map(\.rawKey))
        keys.append(contentsOf: Archive.allCases.map(\.rawKey))
        keys.append(contentsOf: CLI.allCases.map(\.rawKey))
        keys.append(contentsOf: Benchmark.allCases.map(\.rawKey))
        keys.append(contentsOf: Errors.allCases.map(\.rawKey))
        keys.append(contentsOf: Settings.allCases.map(\.rawKey))
        keys.append(contentsOf: Vault.allCases.map(\.rawKey))
        return keys
    }
}
