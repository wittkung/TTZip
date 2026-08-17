import Foundation

/// 符合 POSIX / GNU 规范的工业级 CLI 命令行解析器 (POSIX CLI Argument Parser)
public enum POSIXCLIArgumentParser {
    
    /// 解析结果包含子命令与强类型选项
    public struct ParseResult: Sendable {
        public let command: CLICommand
        public let options: CLIOptions
    }
    
    /// 解析原生命令行参数数组
    public static func parse(args: [String]) -> ParseResult {
        var options = CLIOptions()
        var positionals: [String] = []
        var detectedCommand: CLICommand = .unknown
        var isFirstPositional = true
        var endOfOptionsReached = false
        
        var i = 0
        while i < args.count {
            let token = args[i]
            
            if endOfOptionsReached {
                positionals.append(token)
                i += 1
                continue
            }
            
            // 1. 处理 POSIX `--` 结束选项截断符
            if token == "--" {
                endOfOptionsReached = true
                i += 1
                continue
            }
            
            // 2. 处理长选项 (--option 或 --option=value)
            if token.starts(with: "--") {
                let stripped = String(token.dropFirst(2))
                let key: String
                let inlineValue: String?
                
                if let eqIndex = stripped.firstIndex(of: "=") {
                    key = String(stripped[..<eqIndex])
                    inlineValue = String(stripped[stripped.index(after: eqIndex)...])
                } else {
                    key = stripped
                    inlineValue = nil
                }
                
                switch key {
                case "help":
                    detectedCommand = .help
                case "version":
                    detectedCommand = .version
                case "dry-run":
                    options.dryRun = true
                case "json":
                    options.jsonOutput = true
                case "no-color":
                    options.noColor = true
                case "yes", "assume-yes":
                    options.assumeYes = true
                case "verbose":
                    options.verbosity = 1
                case "quiet":
                    options.verbosity = -1
                case "all-formats", "all":
                    options.allFormats = true
                    if options.format == nil { options.format = "ALL" }
                case "strict", "stop-on-lag":
                    options.stopOnLag = true
                case "zero-copy", "enable-zero-copy":
                    options.enableZeroCopy = true
                case "silesia", "silesia-corpus":
                    options.silesia = true
                case "in-memory", "mem":
                    options.inMemory = true
                case "turbobench", "compat-turbobench":
                    options.turboBenchCompat = true
                case "keep", "keep-temp":
                    options.keepTempFiles = true
                case "dump-on-failure":
                    options.dumpOnFailure = true
                case "fast":
                    options.fast = true
                case "format":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.format = v
                        if inlineValue == nil { i += 1 }
                    }
                case "level":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.level = v
                        if inlineValue == nil { i += 1 }
                    }
                case "password":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.password = v
                        if inlineValue == nil { i += 1 }
                    }
                case "output":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.outputPath = v
                        if inlineValue == nil { i += 1 }
                    }
                case "input", "file":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.inputPath = v
                        if inlineValue == nil { i += 1 }
                    }
                case "split":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.splitSize = v
                        if inlineValue == nil { i += 1 }
                    }
                case "threads":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil), let num = Int(v) {
                        options.threads = num
                        if inlineValue == nil { i += 1 }
                    }
                case "lang", "language":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.language = v
                        if inlineValue == nil { i += 1 }
                    }
                case "tier":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.tier = v
                        if inlineValue == nil { i += 1 }
                    }
                case "filter":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.filterPattern = v
                        if inlineValue == nil { i += 1 }
                    }
                case "report-junit":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.junitReportPath = v
                        if inlineValue == nil { i += 1 }
                    }
                case "report-json", "json-report":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.jsonReportPath = v
                        if inlineValue == nil { i += 1 }
                    }
                case "markdown-report", "report-md":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.markdownReportPath = v
                        if inlineValue == nil { i += 1 }
                    }
                case "config", "filter-config":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.filterConfigPath = v
                        options.stopOnLag = true
                        if inlineValue == nil { i += 1 }
                    }
                case "tools", "pk-tools", "competitors":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.competitorTools = v
                        if inlineValue == nil { i += 1 }
                    }
                case "size", "huge-size":
                    if let v = inlineValue ?? (i + 1 < args.count ? args[i + 1] : nil) {
                        options.hugeSize = v
                        if inlineValue == nil { i += 1 }
                    }
                default:
                    break
                }
                i += 1
                continue
            }
            
            // 3. 处理短选项与合并标志 (-h, -v, -q, -y, -vq, -f zip, -p pwd, -o dir)
            if token.starts(with: "-") && token.count > 1 {
                let flags = Array(token.dropFirst())
                var flagIdx = 0
                
                while flagIdx < flags.count {
                    let char = flags[flagIdx]
                    
                    switch char {
                    case "h":
                        detectedCommand = .help
                    case "V":
                        detectedCommand = .version
                    case "v":
                        options.verbosity += 1
                    case "q":
                        options.verbosity = -1
                    case "y":
                        options.assumeYes = true
                    case "k":
                        options.keepTempFiles = true
                    case "f":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty {
                            options.format = rest
                            flagIdx = flags.count
                        } else if i + 1 < args.count {
                            options.format = args[i + 1]
                            i += 1
                        }
                    case "o":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty {
                            options.outputPath = rest
                            flagIdx = flags.count
                        } else if i + 1 < args.count {
                            options.outputPath = args[i + 1]
                            i += 1
                        }
                    case "p":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty {
                            options.password = rest
                            flagIdx = flags.count
                        } else if i + 1 < args.count {
                            options.password = args[i + 1]
                            i += 1
                        }
                    case "l":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty {
                            options.level = rest
                            flagIdx = flags.count
                        } else if i + 1 < args.count {
                            options.level = args[i + 1]
                            i += 1
                        }
                    case "s":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty {
                            options.splitSize = rest
                            flagIdx = flags.count
                        } else if i + 1 < args.count {
                            options.splitSize = args[i + 1]
                            i += 1
                        }
                    case "i":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty {
                            options.inputPath = rest
                            flagIdx = flags.count
                        } else if i + 1 < args.count {
                            options.inputPath = args[i + 1]
                            i += 1
                        }
                    case "T":
                        let rest = String(flags[(flagIdx + 1)...])
                        if !rest.isEmpty, let num = Int(rest) {
                            options.threads = num
                            flagIdx = flags.count
                        } else if i + 1 < args.count, let num = Int(args[i + 1]) {
                            options.threads = num
                            i += 1
                        }
                    default:
                        break
                    }
                    flagIdx += 1
                }
                i += 1
                continue
            }
            
            // 4. 处理位置参数
            if isFirstPositional {
                let cmd = CLICommand(commandString: token)
                if cmd != .unknown {
                    detectedCommand = cmd
                } else {
                    positionals.append(token)
                }
                isFirstPositional = false
            } else {
                positionals.append(token)
            }
            i += 1
        }
        
        options.positionals = positionals
        return ParseResult(command: detectedCommand, options: options)
    }
}
