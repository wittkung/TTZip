import Foundation

/// 竞品全维度性能对比测试数据行
public struct CompetitorBenchmarkRow: Sendable, Identifiable, Codable {
    public var id: String { "\(toolName)_\(dimensionName)_\(format.rawValue)_\(level.rawValue)_\(isEncrypted)" }
    public let toolName: String                   // 竞品工具名称 (如 "Apple ditto", "7-Zip 7zz CLI", "System tar+zstd")
    public let dimensionName: String              // 数据集名称
    public let format: ArchiveCompressionFormat   // 归档格式
    public let level: ArchiveCompressionLevel     // 压缩等级
    public let isEncrypted: Bool                  // 是否加密
    public let datasetSizeBytes: Int64            // 原始数据集体积
    public let archiveSizeBytes: Int64            // 压缩包体积
    public let compressDurationSeconds: Double    // 竞品打包耗时
    public let compressThroughputMBs: Double       // 竞品打包吞吐 (MB/s)
    public let extractDurationSeconds: Double     // 竞品解压耗时
    public let extractThroughputMBs: Double        // 竞品解压吞吐 (MB/s)
    public let compressionRatioPercent: Double     // 竞品压缩体积占比 (%)
    public let ttzipArchiveSizeBytes: Int64       // TTZip 压缩包体积
    public let ttzipCompressionRatioPercent: Double// TTZip 压缩体积占比 (%)
    public let ttzipCompressMBs: Double           // 同场景 TTZip 打包吞吐
    public let ttzipExtractMBs: Double            // 同场景 TTZip 解压吞吐
    public let compressSpeedupVsCompetitor: Double // TTZip 打包超越倍数 (TTZip MBs / Competitor MBs)
    public let extractSpeedupVsCompetitor: Double  // TTZip 解压超越倍数 (TTZip MBs / Competitor MBs)
    public let topAopStage: String                 // AOP 切片瓶颈阶段名称与占比

    public init(
        toolName: String,
        dimensionName: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        isEncrypted: Bool,
        datasetSizeBytes: Int64,
        archiveSizeBytes: Int64,
        compressDurationSeconds: Double,
        compressThroughputMBs: Double,
        extractDurationSeconds: Double,
        extractThroughputMBs: Double,
        compressionRatioPercent: Double,
        ttzipArchiveSizeBytes: Int64,
        ttzipCompressionRatioPercent: Double,
        ttzipCompressMBs: Double,
        ttzipExtractMBs: Double,
        compressSpeedupVsCompetitor: Double,
        extractSpeedupVsCompetitor: Double,
        topAopStage: String = ""
    ) {
        self.toolName = toolName
        self.dimensionName = dimensionName
        self.format = format
        self.level = level
        self.isEncrypted = isEncrypted
        self.datasetSizeBytes = datasetSizeBytes
        self.archiveSizeBytes = archiveSizeBytes
        self.compressDurationSeconds = compressDurationSeconds
        self.compressThroughputMBs = compressThroughputMBs
        self.extractDurationSeconds = extractDurationSeconds
        self.extractThroughputMBs = extractThroughputMBs
        self.compressionRatioPercent = compressionRatioPercent
        self.ttzipArchiveSizeBytes = ttzipArchiveSizeBytes
        self.ttzipCompressionRatioPercent = ttzipCompressionRatioPercent
        self.ttzipCompressMBs = ttzipCompressMBs
        self.ttzipExtractMBs = ttzipExtractMBs
        self.compressSpeedupVsCompetitor = compressSpeedupVsCompetitor
        self.extractSpeedupVsCompetitor = extractSpeedupVsCompetitor
        self.topAopStage = topAopStage
    }
}

/// 历史最高实测速度记录结构体 (Peak Performance Matrix Record)
public struct PeakPerformanceRecord: Codable, Sendable {
    public let formatRaw: String
    public let levelRaw: Int
    public let isEncrypted: Bool
    public let dimensionName: String
    public var peakCompressMBs: Double
    public var peakExtractMBs: Double
    public var lastUpdated: Date

    public init(
        formatRaw: String,
        levelRaw: Int,
        isEncrypted: Bool,
        dimensionName: String,
        peakCompressMBs: Double,
        peakExtractMBs: Double,
        lastUpdated: Date = Date()
    ) {
        self.formatRaw = formatRaw
        self.levelRaw = levelRaw
        self.isEncrypted = isEncrypted
        self.dimensionName = dimensionName
        self.peakCompressMBs = peakCompressMBs
        self.peakExtractMBs = peakExtractMBs
        self.lastUpdated = lastUpdated
    }
}

