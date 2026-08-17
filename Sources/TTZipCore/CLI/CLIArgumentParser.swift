import Foundation

/// 兼容旧调用约定的 CLI 命令行参数解析入口
public enum CLIArgumentParser {
    
    /// 将原生参数数组解析为强类型 `CLIOptions`
    public static func parse(args: [String]) -> CLIOptions {
        let result = POSIXCLIArgumentParser.parse(args: args)
        return result.options
    }
    
    /// 完整解析命令与选项
    public static func parseCommandAndOptions(args: [String]) -> (command: CLICommand, options: CLIOptions) {
        let result = POSIXCLIArgumentParser.parse(args: args)
        return (result.command, result.options)
    }
    
    /// 解析格式过滤器参数
    public static func parseFormats(_ filter: String?) -> [ArchiveCompressionFormat]? {
        guard let filter = filter, !filter.isEmpty, filter.uppercased() != "ALL" else {
            return nil
        }
        let items = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var result: [ArchiveCompressionFormat] = []
        for item in items {
            switch item {
            case "zip": result.append(.zip)
            case "7z", "sevenzip": result.append(.sevenZip)
            case "tar": result.append(.tar)
            case "tar.zst", "zst", "zstd", "tzst": result.append(.zst)
            case "tar.gz", "gz", "gzip", "tgz": result.append(.gz)
            case "tar.xz", "xz", "txz": result.append(.xz)
            case "tar.bz2", "bz2", "bzip2", "tbz2": result.append(.bz2)
            case "lz4": result.append(.lz4)
            case "brotli": result.append(.brotli)
            case "snappy": result.append(.snappy)
            case "lzip": result.append(.lzip)
            case "lrzip": result.append(.lrzip)
            case "aar": result.append(.aar)
            case "wim": result.append(.wim)
            case "dmg": result.append(.dmg)
            case "iso": result.append(.iso)
            default: break
            }
        }
        return result.isEmpty ? nil : result
    }
    
    /// 解析压缩级别参数
    public static func parseLevels(_ filter: String?) -> [ArchiveCompressionLevel]? {
        guard let filter = filter, !filter.isEmpty else { return nil }
        let items = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var result: [ArchiveCompressionLevel] = []
        for item in items {
            if let num = Int(item) {
                result.append(ArchiveCompressionLevel(levelInt: num))
            } else {
                switch item {
                case "store", "none", "0": result.append(.store)
                case "fastest", "1": result.append(.fastest)
                case "fast", "3": result.append(.fast)
                case "medium", "5": result.append(.medium)
                case "normal", "6": result.append(.normal)
                case "maximum", "max", "7": result.append(.maximum)
                case "ultra", "9": result.append(.ultra)
                default: break
                }
            }
        }
        return result.isEmpty ? nil : result
    }
}
