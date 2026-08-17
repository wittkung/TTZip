import Foundation

/// 强类型的基准测试与擂台赛配置结构体
public struct BenchmarkRunConfig: Sendable {
    /// 目标压缩格式过滤列表 (nil 表示按默认执行)
    public var selectedFormats: [ArchiveCompressionFormat]?
    
    /// 目标压缩等级过滤列表 (nil 表示按默认执行)
    public var selectedLevels: [ArchiveCompressionLevel]?
    
    /// 竞品软件工具过滤列表
    public var selectedTools: [String]?
    
    /// 大容量测试基准尺寸描述 (如 "500MB")
    public var hugeSizeFilter: String?
    
    /// 自定义测试文件/目录路径
    public var customFilePaths: [String]?
    
    /// 性能滞后或校验失败时是否立即强行中止
    public var stopOnLagOrError: Bool
    
    /// 是否自动识别并调度物理性能最强的竞品
    public var autoBestCompetitor: Bool
    
    /// 大考霸榜模式 (要求 100% 碾压全量竞品)
    public var verifyAllDominance: Bool
    
    /// 滞后过滤配置文件路径
    public var filterConfigPath: String?
    
    /// 是否仅测试 500MB 巨型 Payload
    public var hugeOnly: Bool
    
    public init(
        selectedFormats: [ArchiveCompressionFormat]? = nil,
        selectedLevels: [ArchiveCompressionLevel]? = nil,
        selectedTools: [String]? = nil,
        hugeSizeFilter: String? = nil,
        customFilePaths: [String]? = nil,
        stopOnLagOrError: Bool = false,
        autoBestCompetitor: Bool = false,
        verifyAllDominance: Bool = false,
        filterConfigPath: String? = nil,
        hugeOnly: Bool = false
    ) {
        self.selectedFormats = selectedFormats
        self.selectedLevels = selectedLevels
        self.selectedTools = selectedTools
        self.hugeSizeFilter = hugeSizeFilter
        self.customFilePaths = customFilePaths
        self.stopOnLagOrError = stopOnLagOrError
        self.autoBestCompetitor = autoBestCompetitor
        self.verifyAllDominance = verifyAllDominance
        self.filterConfigPath = filterConfigPath
        self.hugeOnly = hugeOnly
    }
}
