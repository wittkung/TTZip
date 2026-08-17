import Foundation
import TTZipCore

/// 强类型的 CLI 解析选项数据模型
public struct CLIOptions: Sendable {
    /// 位置参数列表
    public var positionals: [String] = []
    
    /// 归档或解密密码
    public var password: String? = nil
    
    /// 压缩格式 (如 "zip", "7z", "ALL")
    public var format: String? = nil
    
    /// 分卷包尺寸 (如 "100m", "1g")
    public var splitSize: String? = nil
    
    /// 压缩等级 (如 "store", "fast", "ultra", "1", "9")
    public var level: String? = nil
    
    /// 竞品工具列表 (如 "pigz,7zz")
    public var competitorTools: String? = nil
    
    /// 测试数据集尺寸 (如 "500MB")
    public var hugeSize: String? = nil
    
    /// 是否仅测试 500MB 巨型 Payload
    public var hugeOnly: Bool = false
    
    /// 输入路径
    public var inputPath: String? = nil
    
    /// 是否开启零拷贝内存引擎
    public var enableZeroCopy: Bool = false
    
    /// 配置文件路径
    public var filterConfigPath: String? = nil
    
    /// 滞后/错误时是否强行中止
    public var stopOnLag: Bool = false
    
    /// 是否选择全部 16 种格式
    public var allFormats: Bool = false
    
    /// 是否自动对标物理最强竞品
    public var autoBestCompetitor: Bool = false
    
    /// 是否开启大考 100% 霸榜校验
    public var verifyAllDominance: Bool = false
    
    // MARK: - 测试驱动与诊断选项 (Feature 044: Libarchive Harness Alignment)
    
    /// 测试过滤正则/关键字 (如 --filter "GoldenCorpus")
    public var filterPattern: String? = nil
    
    /// 详细度等级 (-1: 极简 -q, 0: 默认, 1: 详细 -v, 2: 全量调试 -vv)
    public var verbosity: Int = 0
    
    /// 是否保留沙盒与解压临时目录 (-k, --keep-temp)
    public var keepTempFiles: Bool = false
    
    /// 断言失败时是否保留现场/Dump (--dump-on-failure)
    public var dumpOnFailure: Bool = false
    
    /// 是否仅执行进程内极速诊断测试 (--fast)
    public var fast: Bool = false
    
    /// JSON 结构化报告输出路径 (--json-report <path>)
    public var jsonReportPath: String? = nil
    
    /// Markdown 报告输出路径 (--markdown-report <path>)
    public var markdownReportPath: String? = nil
    
    /// 是否针对 Silesia 211MB 真实语料库进行基准测试 (--silesia)
    public var silesia: Bool = false
    
    // MARK: - 纯内存与 TurboBench / lzbench 对齐选项 (Feature 052)
    
    /// 是否开启纯内存基准测试模式 (--in-memory, --mem)
    public var inMemory: Bool = false
    
    /// 是否采用 TurboBench 标准 Markdown 表格输出格式 (--compat-turbobench, --turbobench)
    public var turboBenchCompat: Bool = false
    
    /// 单个测试项的最短执行时间窗口（毫秒，默认 500ms）
    public var minDurationMs: Int = 500
    
    /// 预热轮次（默认 2 轮）
    public var warmupPasses: Int = 2
    
    /// 是否使用二进制单位 MiB/s 代替十进制 MB/s
    public var binaryUnits: Bool = false
    
    public init() {}
}

/// 支持的 CLI 子命令
public enum CLICommand: String, Sendable {
    case inspect
    case extract
    case create
    case recover
    case bench
    case benchPk = "bench_pk"
    case competitorBench = "competitor_bench"
    case clean
    case cleanCache = "clean-cache"
    case purge
    case customBench = "custom_bench"
    case test
    case repair
    case batch
    case uninstall
    case preset
    case version = "--version"
    case shortVersion = "-v"
    case help = "--help"
    case shortHelp = "-h"
    case unknown
    
    public init(commandString: String) {
        let lower = commandString.lowercased()
        if let val = CLICommand(rawValue: lower) {
            self = val
        } else if lower == "clean-cache" || lower == "purge" {
            self = .clean
        } else if lower == "competitor_bench" {
            self = .benchPk
        } else if lower == "batch" || lower == "macro" {
            self = .batch
        } else {
            self = .unknown
        }
    }
}
