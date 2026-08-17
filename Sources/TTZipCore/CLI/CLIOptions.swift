import Foundation

/// 目标文件冲突覆盖策略
public enum FileCollisionPolicy: String, Sendable, CaseIterable {
    case prompt
    case always
    case never
    case newer
    case backup
}

/// 强类型的 CLI 解析选项数据模型 (符合 POSIX / GNU 规范)
public struct CLIOptions: Sendable {
    /// 位置参数列表
    public var positionals: [String] = []
    
    /// 输出路径 (-o, --output)
    public var outputPath: String? = nil
    
    /// 归档或解密密码 (-p, --password)
    public var password: String? = nil
    
    /// 密码文件路径 (--password-file, -P)
    public var passwordFile: String? = nil
    
    /// 压缩格式 (如 "zip", "7z", "tar.zst", "ALL") (-f, --format)
    public var format: String? = nil
    
    /// 分卷包尺寸 (如 "100m", "1g") (-s, --split)
    public var splitSize: String? = nil
    
    /// 压缩等级 (如 "store", "fast", "ultra", "1", "9") (-l, --level)
    public var level: String? = nil
    
    /// 是否为模拟运行 (--dry-run)
    public var dryRun: Bool = false
    
    /// 是否输出机器可读 NDJSON 格式 (--json)
    public var jsonOutput: Bool = false
    
    /// 是否禁用 ANSI 颜色 (--no-color)
    public var noColor: Bool = false
    
    /// 是否对所有提示自动确认 (-y, --yes, --assume-yes)
    public var assumeYes: Bool = false
    
    /// 强制操作 / 绕过 TTY 终端保护 (-f, --force)
    public var force: Bool = false
    
    /// 覆盖冲突策略 ("prompt", "always", "never", "newer", "backup") (--overwrite)
    public var overwritePolicy: String = "prompt"
    
    /// 排除文件模式列表 (-x, --exclude)
    public var excludePatterns: [String] = []
    
    /// 包含文件模式列表 (-i, --include)
    public var includePatterns: [String] = []
    
    /// 路径前缀截取级数 (--strip-components)
    public var stripComponents: Int = 0
    
    /// 是否排除版本控制相关文件 (--exclude-vcs)
    public var excludeVCS: Bool = false
    
    /// 是否排除 macOS 特有元数据文件 (.DS_Store, __MACOSX) (--no-mac-metadata)
    public var noMacMetadata: Bool = false
    
    /// 是否扁平化输出目录层级 (-j, --flatten, --junk-paths)
    public var flattenPaths: Bool = false
    
    /// 是否输出至标准输出流 (-O, -c, --to-stdout)
    public var toStdout: Bool = false
    
    /// 外部文件清单文件路径 (--files-from, -T)
    public var filesFromPath: String? = nil
    
    /// 文件清单是否以 NUL (\0) 分隔 (-0, --null)
    public var nullDelimiter: Bool = false
    
    /// 目录树渲染最大深度 (--depth, -d)
    public var treeDepth: Int? = nil
    
    /// 是否禁用分页器输出 (--no-pager)
    public var noPager: Bool = false
    
    /// 并发线程数 (-T, --threads)
    public var threads: Int = 0
    
    /// 交互语言 (--lang)
    public var language: String? = nil
    
    /// 竞品工具列表 (如 "pigz,7zz")
    public var competitorTools: String? = nil
    
    /// 测试数据集尺寸 (如 "500MB")
    public var hugeSize: String? = nil
    
    /// 是否仅测试 500MB 巨型 Payload
    public var hugeOnly: Bool = false
    
    /// 输入路径 (-i, --input)
    public var inputPath: String? = nil
    
    /// 是否开启零拷贝内存引擎
    public var enableZeroCopy: Bool = false
    
    /// 配置文件路径
    public var filterConfigPath: String? = nil
    
    /// 滞后/错误时是否强行中止 (--strict, --stop-on-lag)
    public var stopOnLag: Bool = false
    
    /// 是否选择全部 16 种格式
    public var allFormats: Bool = false
    
    /// 是否自动对标物理最强竞品
    public var autoBestCompetitor: Bool = false
    
    /// 是否开启大考 100% 霸榜校验
    public var verifyAllDominance: Bool = false
    
    // MARK: - 测试驱动与诊断选项
    
    /// 测试分层过滤 (--tier "0,1,2")
    public var tier: String? = nil
    
    /// 测试过滤正则/关键字 (如 --filter "GoldenCorpus")
    public var filterPattern: String? = nil
    
    /// 详细度等级 (-1: 极简 -q, 0: 默认, 1: 详细 -v, 2: 全量调试 -vv)
    public var verbosity: Int = 0
    
    /// 是否保留沙盒与解压临时目录 (-k, --keep)
    public var keepTempFiles: Bool = false
    
    /// 断言失败时是否保留现场/Dump (--dump-on-failure)
    public var dumpOnFailure: Bool = false
    
    /// 是否仅执行进程内极速诊断测试 (--fast)
    public var fast: Bool = false
    
    /// JUnit XML 报告输出路径 (--report-junit <path>)
    public var junitReportPath: String? = nil
    
    /// JSON 结构化报告输出路径 (--report-json <path>, --json-report <path>)
    public var jsonReportPath: String? = nil
    
    /// Markdown 报告输出路径 (--markdown-report <path>)
    public var markdownReportPath: String? = nil
    
    /// 标准格式测试 (--standard <format>)
    public var standardFormat: String? = nil
    
    /// 差分预言机测试 (--differential <oracle>)
    public var differentialOracle: String? = nil
    
    /// 是否执行确定性变异模糊测试 (--fuzz)
    public var fuzz: Bool = false
    
    /// 是否针对 Silesia 211MB 真实语料库进行基准测试 (--silesia)
    public var silesia: Bool = false
    
    // MARK: - 纯内存与 TurboBench / lzbench 对齐选项
    
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
    
    // MARK: - 领域实体转换辅助
    
    public var collisionPolicy: FileCollisionPolicy {
        get {
            FileCollisionPolicy(rawValue: overwritePolicy) ?? .prompt
        }
        set {
            overwritePolicy = newValue.rawValue
        }
    }
    
    public init() {}
}

/// 支持的 CLI 子命令
public enum CLICommand: String, Sendable {
    case archive
    case create
    case extract
    case list
    case test
    case bench
    case benchPk = "bench_pk"
    case competitorBench = "competitor_bench"
    case inspect
    case diff
    case recover
    case repair
    case clean
    case cleanCache = "clean-cache"
    case purge
    case customBench = "custom_bench"
    case batch
    case uninstall
    case preset
    case completion
    case man
    case cat
    case tree
    case hash
    case delete
    case update
    case explore
    case version = "--version"
    case shortVersion = "-v"
    case help = "--help"
    case shortHelp = "-h"
    case unknown
    
    public init(commandString: String) {
        let lower = commandString.lowercased()
        switch lower {
        case "archive", "a":
            self = .archive
        case "create", "c":
            self = .create
        case "extract", "x", "e":
            self = .extract
        case "list", "l", "ls":
            self = .list
        case "test", "t", "verify":
            self = .test
        case "explore", "tui", "browse":
            self = .explore
        case "bench", "b", "benchmark":
            self = .bench
        case "bench_pk", "benchpk", "pk":
            self = .benchPk
        case "competitor_bench", "competitor":
            self = .competitorBench
        case "inspect", "i", "info":
            self = .inspect
        case "diff":
            self = .diff
        case "recover":
            self = .recover
        case "repair":
            self = .repair
        case "clean":
            self = .clean
        case "clean-cache":
            self = .cleanCache
        case "purge":
            self = .purge
        case "custom_bench":
            self = .customBench
        case "batch":
            self = .batch
        case "uninstall":
            self = .uninstall
        case "preset":
            self = .preset
        case "completion":
            self = .completion
        case "man":
            self = .man
        case "cat", "view":
            self = .cat
        case "tree":
            self = .tree
        case "hash", "checksum":
            self = .hash
        case "delete", "remove", "rm", "del", "d":
            self = .delete
        case "update", "u":
            self = .update
        case "--version":
            self = .version
        case "-v", "-V":
            self = .shortVersion
        case "--help":
            self = .help
        case "-h", "help":
            self = .shortHelp
        default:
            self = .unknown
        }
    }
}

