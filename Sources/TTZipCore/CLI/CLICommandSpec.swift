import Foundation

/// 声明式命令行选项规范模型
public struct CLIOptionSpec: Sendable {
    public let shortName: String?
    public let longName: String
    public let description: String
    public let takesValue: Bool
    public let valueName: String?
    public let valueChoices: [String]
    public let isFilePath: Bool
    
    public init(
        shortName: String? = nil,
        longName: String,
        description: String,
        takesValue: Bool = false,
        valueName: String? = nil,
        valueChoices: [String] = [],
        isFilePath: Bool = false
    ) {
        self.shortName = shortName
        self.longName = longName
        self.description = description
        self.takesValue = takesValue
        self.valueName = valueName
        self.valueChoices = valueChoices
        self.isFilePath = isFilePath
    }
}

/// 声明式命令行子命令规范模型
public struct CLICommandMetadata: Sendable {
    public let name: String
    public let aliases: [String]
    public let summary: String
    public let usage: String
    public let options: [CLIOptionSpec]
    
    public init(name: String, aliases: [String] = [], summary: String, usage: String, options: [CLIOptionSpec] = []) {
        self.name = name
        self.aliases = aliases
        self.summary = summary
        self.usage = usage
        self.options = options
    }
}

/// 声明式命令元数据与 Shell 自动补全 / Man Page 生成器
public enum CLICommandSpec {
    
    public static let globalOptions: [CLIOptionSpec] = [
        CLIOptionSpec(shortName: "h", longName: "help", description: "Show help information"),
        CLIOptionSpec(shortName: "V", longName: "version", description: "Show version and architecture information"),
        CLIOptionSpec(shortName: "v", longName: "verbose", description: "Increase verbosity level (-v, -vv)"),
        CLIOptionSpec(shortName: "q", longName: "quiet", description: "Quiet mode, suppress progress and non-fatal warnings"),
        CLIOptionSpec(shortName: "y", longName: "yes", description: "Assume yes on all prompts (e.g. overwrite)"),
        CLIOptionSpec(longName: "dry-run", description: "Simulate operations without writing changes to disk"),
        CLIOptionSpec(longName: "no-color", description: "Disable ANSI color output"),
        CLIOptionSpec(longName: "json", description: "Output machine-readable NDJSON stream on stdout"),
        CLIOptionSpec(shortName: "T", longName: "threads", description: "Set maximum concurrency threads (0 for auto)", takesValue: true, valueName: "NUM"),
        CLIOptionSpec(longName: "lang", description: "Set language (en, zh-Hans, zh-Hant, ja, de, fr, es)", takesValue: true, valueName: "LANG"),
        CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read password from file", takesValue: true, valueName: "PATH"),
        CLIOptionSpec(longName: "overwrite", description: "File collision overwrite policy (prompt, always, never, newer, backup)", takesValue: true, valueName: "POLICY"),
        CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
        CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
        CLIOptionSpec(longName: "strip-components", description: "Strip leading path components on extraction", takesValue: true, valueName: "N"),
        CLIOptionSpec(longName: "exclude-vcs", description: "Exclude version control system directories (.git, .svn, .hg)"),
        CLIOptionSpec(longName: "no-mac-metadata", description: "Exclude macOS metadata files (.DS_Store, __MACOSX, ._*)"),
        CLIOptionSpec(shortName: "f", longName: "force", description: "Force binary output to terminal or bypass safety checks")
    ]
    
    public static let subcommands: [CLICommandMetadata] = [
        CLICommandMetadata(
            name: "archive",
            aliases: ["a", "create", "c"],
            summary: "Create an archive from source files or directories",
            usage: "ttzip-cli archive <output_archive> <inputs...> [options]",
            options: [
                CLIOptionSpec(shortName: "f", longName: "format", description: "Archive format (zip, 7z, tar.zst, tar.gz, tar.xz, lz4, etc.)", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(shortName: "l", longName: "level", description: "Compression level (0-9, store, fast, ultra)", takesValue: true, valueName: "LEVEL"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Encrypt archive with password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read encryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "s", longName: "split", description: "Split archive into multi-part volumes (e.g. 100M, 1G)", takesValue: true, valueName: "SIZE"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(longName: "exclude-vcs", description: "Exclude version control system directories (.git, .svn, .hg)"),
                CLIOptionSpec(longName: "no-mac-metadata", description: "Exclude macOS metadata files (.DS_Store, __MACOSX, ._*)"),
                CLIOptionSpec(longName: "files-from", description: "Read input file list from manifest file or '-' for stdin", takesValue: true, valueName: "PATH")
            ]
        ),
        CLICommandMetadata(
            name: "extract",
            aliases: ["x", "e"],
            summary: "Extract files from an archive",
            usage: "ttzip-cli extract <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "o", longName: "output", description: "Destination directory (or '-' for stdout)", takesValue: true, valueName: "DIR"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "k", longName: "keep", description: "Keep damaged or partially extracted files"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(longName: "strip-components", description: "Strip leading path components on extraction", takesValue: true, valueName: "N"),
                CLIOptionSpec(longName: "overwrite", description: "File collision overwrite policy (prompt, always, never, newer, backup)", takesValue: true, valueName: "POLICY"),
                CLIOptionSpec(shortName: "f", longName: "force", description: "Force overwrite or bypass terminal binary output checks")
            ]
        ),
        CLICommandMetadata(
            name: "list",
            aliases: ["l", "ls"],
            summary: "List contents of an archive",
            usage: "ttzip-cli list <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB")
            ]
        ),
        CLICommandMetadata(
            name: "cat",
            aliases: ["view"],
            summary: "Print decompressed contents of archive entry directly to stdout",
            usage: "ttzip-cli cat <archive> <entry> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "f", longName: "force", description: "Force binary data output to interactive terminal")
            ]
        ),
        CLICommandMetadata(
            name: "tree",
            aliases: [],
            summary: "Display archive contents as a visual tree hierarchy",
            usage: "ttzip-cli tree <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "d", longName: "depth", description: "Maximum recursion depth for tree rendering", takesValue: true, valueName: "N"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB")
            ]
        ),
        CLICommandMetadata(
            name: "hash",
            aliases: ["checksum"],
            summary: "Compute and display CRC32 and SHA-256 checksums of archive entries",
            usage: "ttzip-cli hash <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(longName: "sha256", description: "Calculate full SHA-256 digest in addition to CRC32"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB")
            ]
        ),
        CLICommandMetadata(
            name: "delete",
            aliases: ["d"],
            summary: "Delete specified files or patterns from an archive",
            usage: "ttzip-cli delete <archive> <patterns...> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption/encryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read password from file", takesValue: true, valueName: "PATH")
            ]
        ),
        CLICommandMetadata(
            name: "update",
            aliases: ["u"],
            summary: "Update newer files or add new files into an existing archive",
            usage: "ttzip-cli update <archive> <inputs...> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption/encryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "l", longName: "level", description: "Compression level (0-9, store, fast, ultra)", takesValue: true, valueName: "LEVEL"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(longName: "exclude-vcs", description: "Exclude version control system directories"),
                CLIOptionSpec(longName: "no-mac-metadata", description: "Exclude macOS metadata files")
            ]
        ),
        CLICommandMetadata(
            name: "test",
            aliases: ["t", "verify"],
            summary: "Test archive integrity or run automated test suites",
            usage: "ttzip-cli test [archive] [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(longName: "standard", description: "Run standards compliance validation (e.g. zip, tar, zst, all)", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(longName: "differential", description: "Run differential oracle test against external tool (e.g. bsdtar, 7zz)", takesValue: true, valueName: "ORACLE"),
                CLIOptionSpec(longName: "fuzz", description: "Run deterministic in-process mutation fuzzing test suite"),
                CLIOptionSpec(longName: "tier", description: "Filter test tiers (e.g. 0,1,2)", takesValue: true, valueName: "TIERS"),
                CLIOptionSpec(longName: "report-junit", description: "Export JUnit XML test report", takesValue: true, valueName: "FILE"),
                CLIOptionSpec(longName: "report-json", description: "Export JSON test report", takesValue: true, valueName: "FILE")
            ]
        ),
        CLICommandMetadata(
            name: "bench",
            aliases: ["b", "benchmark"],
            summary: "Run high-precision CPU/memory codec throughput benchmarks",
            usage: "ttzip-cli bench [options]",
            options: [
                CLIOptionSpec(shortName: "f", longName: "format", description: "Benchmark target format", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(longName: "all-formats", description: "Run all 16 formats benchmark matrix")
            ]
        ),
        CLICommandMetadata(
            name: "completion",
            aliases: [],
            summary: "Generate shell auto-completion scripts (zsh, bash, fish, nushell)",
            usage: "ttzip-cli completion <zsh|bash|fish|nushell>"
        ),
        CLICommandMetadata(
            name: "man",
            aliases: [],
            summary: "Output UNIX groff mdoc man page",
            usage: "ttzip-cli man"
        )
    ]
    
    // MARK: - Shell Auto-Completion Generators
    
    public static func generateZshCompletion() -> String {
        var out = "#compdef ttzip-cli\n\n"
        out += "_ttzip_cli() {\n"
        out += "    local context state line\n"
        out += "    typeset -A opt_args\n\n"
        out += "    _arguments -C \\\n"
        for opt in globalOptions {
            let spec: String
            if let short = opt.shortName {
                if opt.takesValue {
                    let v = opt.valueName ?? "VALUE"
                    spec = "'(-\(short) --\(opt.longName))'{-\(short),--\(opt.longName)}'[\(opt.description)]:\(v): '"
                } else {
                    spec = "'(-\(short) --\(opt.longName))'{-\(short),--\(opt.longName)}'[\(opt.description)]'"
                }
            } else {
                if opt.takesValue {
                    let v = opt.valueName ?? "VALUE"
                    spec = "'--\(opt.longName)[\(opt.description)]:\(v): '"
                } else {
                    spec = "'--\(opt.longName)[\(opt.description)]'"
                }
            }
            out += "        \(spec) \\\n"
        }
        out += "        '1: :->command' \\\n"
        out += "        '*:: :->args'\n\n"
        out += "    case $state in\n"
        out += "        command)\n"
        out += "            local -a subcommands\n"
        out += "            subcommands=(\n"
        for sub in subcommands {
            out += "                '\(sub.name):\(sub.summary)'\n"
            for alias in sub.aliases {
                out += "                '\(alias):Alias for \(sub.name)'\n"
            }
        }
        out += "            )\n"
        out += "            _describe -t subcommands 'ttzip-cli command' subcommands\n"
        out += "            ;;\n"
        out += "        args)\n"
        out += "            case $line[1] in\n"
        for sub in subcommands {
            let names = ([sub.name] + sub.aliases).joined(separator: "|")
            out += "                \(names))\n"
            if sub.options.isEmpty {
                out += "                    _files\n"
            } else {
                out += "                    _arguments \\\n"
                for opt in sub.options {
                    let spec: String
                    if let short = opt.shortName {
                        if opt.takesValue {
                            let v = opt.valueName ?? "VALUE"
                            spec = "'(-\(short) --\(opt.longName))'{-\(short),--\(opt.longName)}'[\(opt.description)]:\(v): '"
                        } else {
                            spec = "'(-\(short) --\(opt.longName))'{-\(short),--\(opt.longName)}'[\(opt.description)]'"
                        }
                    } else {
                        if opt.takesValue {
                            let v = opt.valueName ?? "VALUE"
                            spec = "'--\(opt.longName)[\(opt.description)]:\(v): '"
                        } else {
                            spec = "'--\(opt.longName)[\(opt.description)]'"
                        }
                    }
                    out += "                        \(spec) \\\n"
                }
                out += "                        '*: :_files'\n"
            }
            out += "                    ;;\n"
        }
        out += "                *)\n"
        out += "                    _files\n"
        out += "                    ;;\n"
        out += "            esac\n"
        out += "            ;;\n"
        out += "    esac\n"
        out += "}\n\n"
        out += "_ttzip_cli \"$@\"\n"
        return out
    }
    
    public static func generateBashCompletion() -> String {
        var out = "#!/usr/bin/env bash\n\n"
        out += "_ttzip_cli_completions() {\n"
        out += "    local cur prev words cword\n"
        out += "    if type -t _init_completion >/dev/null 2>&1; then\n"
        out += "        _init_completion || return\n"
        out += "    else\n"
        out += "        cur=\"${COMP_WORDS[COMP_CWORD]}\"\n"
        out += "        prev=\"${COMP_WORDS[COMP_CWORD-1]}\"\n"
        out += "        cword=$COMP_CWORD\n"
        out += "    fi\n\n"
        
        var allCmds: [String] = []
        for sub in subcommands {
            allCmds.append(sub.name)
            allCmds.append(contentsOf: sub.aliases)
        }
        let cmdsStr = allCmds.joined(separator: " ")
        var globalFlags: [String] = []
        for opt in globalOptions {
            if let s = opt.shortName { globalFlags.append("-\(s)") }
            globalFlags.append("--\(opt.longName)")
        }
        let globalFlagsStr = globalFlags.joined(separator: " ")
        
        out += "    local commands=\"\(cmdsStr)\"\n"
        out += "    local global_options=\"\(globalFlagsStr)\"\n\n"
        out += "    if [ \"$cword\" -eq 1 ]; then\n"
        out += "        COMPREPLY=( $(compgen -W \"$commands $global_options\" -- \"$cur\") )\n"
        out += "        return 0\n"
        out += "    fi\n\n"
        out += "    local cmd=\"${COMP_WORDS[1]}\"\n"
        out += "    case \"$cmd\" in\n"
        for sub in subcommands {
            let names = ([sub.name] + sub.aliases).joined(separator: "|")
            var subFlags: [String] = []
            for opt in sub.options {
                if let s = opt.shortName { subFlags.append("-\(s)") }
                subFlags.append("--\(opt.longName)")
            }
            let subFlagsStr = subFlags.joined(separator: " ")
            out += "        \(names))\n"
            if sub.name == "completion" {
                out += "            if [ \"$cword\" -eq 2 ]; then\n"
                out += "                COMPREPLY=( $(compgen -W \"zsh bash fish nushell\" -- \"$cur\") )\n"
                out += "                return 0\n"
                out += "            fi\n"
            } else if !subFlags.isEmpty {
                out += "            if [[ \"$cur\" == -* ]]; then\n"
                out += "                COMPREPLY=( $(compgen -W \"\(subFlagsStr) $global_options\" -- \"$cur\") )\n"
                out += "                return 0\n"
                out += "            fi\n"
            }
            out += "            ;;\n"
        }
        out += "        *)\n"
        out += "            ;;\n"
        out += "    esac\n\n"
        out += "    COMPREPLY=( $(compgen -f -- \"$cur\") )\n"
        out += "}\n\n"
        out += "complete -F _ttzip_cli_completions ttzip-cli\n"
        return out
    }
    
    public static func generateFishCompletion() -> String {
        var out = "# Fish completion for ttzip-cli\n"
        out += "# Auto-generated by TTZip CLICommandSpec\n\n"
        out += "# Disable file completion by default for commands\n"
        out += "complete -c ttzip-cli -f\n\n"
        out += "# Global options\n"
        for opt in globalOptions {
            var line = "complete -c ttzip-cli"
            if let short = opt.shortName {
                line += " -s \(short)"
            }
            line += " -l \(opt.longName)"
            if opt.takesValue {
                line += " -r"
            }
            line += " -d \"\(opt.description)\""
            out += "\(line)\n"
        }
        out += "\n# Subcommands\n"
        for sub in subcommands {
            out += "complete -c ttzip-cli -n \"__fish_use_subcommand\" -a \"\(sub.name)\" -d \"\(sub.summary)\"\n"
            for alias in sub.aliases {
                out += "complete -c ttzip-cli -n \"__fish_use_subcommand\" -a \"\(alias)\" -d \"Alias for \(sub.name)\"\n"
            }
        }
        out += "\n# Subcommand-specific options\n"
        for sub in subcommands {
            guard !sub.options.isEmpty else { continue }
            let allNames = ([sub.name] + sub.aliases).joined(separator: " ")
            let condition = "__fish_seen_subcommand_from \(allNames)"
            for opt in sub.options {
                var line = "complete -c ttzip-cli -n \"\(condition)\""
                if let short = opt.shortName {
                    line += " -s \(short)"
                }
                line += " -l \(opt.longName)"
                if opt.takesValue {
                    line += " -r"
                }
                line += " -d \"\(opt.description)\""
                out += "\(line)\n"
            }
        }
        out += "\n# Enable file completions for archive arguments\n"
        let fileCmds = subcommands.filter { $0.name != "completion" && $0.name != "man" }
        var allFileCmdNames: [String] = []
        for c in fileCmds {
            allFileCmdNames.append(c.name)
            allFileCmdNames.append(contentsOf: c.aliases)
        }
        out += "complete -c ttzip-cli -n \"__fish_seen_subcommand_from \(allFileCmdNames.joined(separator: " "))\" -F\n"
        out += "complete -c ttzip-cli -n \"__fish_seen_subcommand_from completion\" -a \"zsh bash fish nushell\" -d \"Target shell\"\n"
        return out
    }
    
    public static func generateNushellCompletion() -> String {
        var out = "# Nushell completion for ttzip-cli\n"
        out += "# Auto-generated by TTZip CLICommandSpec\n\n"
        
        // Root command extern
        out += "export extern \"ttzip-cli\" [\n"
        for opt in globalOptions {
            let shortPart = opt.shortName.map { "(-\($0))" } ?? ""
            let typePart: String
            if opt.takesValue {
                let v = opt.valueName ?? ""
                if v == "NUM" || v == "N" {
                    typePart = ": int"
                } else if v == "PATH" || v == "FILE" || v == "DIR" {
                    typePart = ": path"
                } else {
                    typePart = ": string"
                }
            } else {
                typePart = ""
            }
            out += "    --\(opt.longName)\(shortPart)\(typePart)  # \(opt.description)\n"
        }
        out += "]\n\n"
        
        // Subcommands externs
        for sub in subcommands {
            let allNames = [sub.name] + sub.aliases
            for name in allNames {
                out += "export extern \"ttzip-cli \(name)\" [\n"
                for opt in sub.options {
                    let shortPart = opt.shortName.map { "(-\($0))" } ?? ""
                    let typePart: String
                    if opt.takesValue {
                        let v = opt.valueName ?? ""
                        if v == "NUM" || v == "N" {
                            typePart = ": int"
                        } else if v == "PATH" || v == "FILE" || v == "DIR" {
                            typePart = ": path"
                        } else {
                            typePart = ": string"
                        }
                    } else {
                        typePart = ""
                    }
                    out += "    --\(opt.longName)\(shortPart)\(typePart)  # \(opt.description)\n"
                }
                for opt in globalOptions {
                    let shortPart = opt.shortName.map { "(-\($0))" } ?? ""
                    let typePart: String
                    if opt.takesValue {
                        let v = opt.valueName ?? ""
                        if v == "NUM" || v == "N" {
                            typePart = ": int"
                        } else if v == "PATH" || v == "FILE" || v == "DIR" {
                            typePart = ": path"
                        } else {
                            typePart = ": string"
                        }
                    } else {
                        typePart = ""
                    }
                    out += "    --\(opt.longName)\(shortPart)\(typePart)  # \(opt.description)\n"
                }
                out += "    ...args: path  # Positional arguments\n"
                out += "]\n\n"
            }
        }
        return out
    }
    
    public static func generateManPage() -> String {
        var out = ".Dd August 17, 2026\n"
        out += ".Dt TTZIP-CLI 1\n"
        out += ".Os macOS\n"
        out += ".Sh NAME\n"
        out += ".Nm ttzip-cli\n"
        out += ".Nd High-performance native archive and compression CLI utility\n"
        out += ".Sh SYNOPSIS\n"
        out += ".Nm\n"
        out += ".Ar command\n"
        out += ".Op Fl -options\n"
        out += ".Op Ar arguments ...\n"
        out += ".Sh DESCRIPTION\n"
        out += "TTZip is an enterprise-grade, high-throughput in-process compression and extraction tool for macOS Sonoma and Apple Silicon.\n"
        out += ".Sh GLOBAL OPTIONS\n"
        for opt in globalOptions {
            out += ".Bl -tag -width indent\n"
            var optStr = ""
            if let short = opt.shortName {
                optStr += "-\(short), "
            }
            optStr += "--\(opt.longName)"
            if let v = opt.valueName {
                optStr += " <\(v)>"
            }
            out += ".It Cm \(optStr)\n"
            out += "\(opt.description).\n"
            out += ".El\n"
        }
        out += ".Sh SUBCOMMANDS\n"
        for sub in subcommands {
            out += ".Bl -tag -width indent\n"
            out += ".It Cm \(sub.name)\n"
            out += "\(sub.summary).\n"
            out += "Usage: Ar \(sub.usage)\n"
            if !sub.options.isEmpty {
                out += "Options:\n"
                for opt in sub.options {
                    var optStr = ""
                    if let short = opt.shortName {
                        optStr += "-\(short), "
                    }
                    optStr += "--\(opt.longName)"
                    if let v = opt.valueName {
                        optStr += " <\(v)>"
                    }
                    out += ".It Cm \\ \\ \(optStr)\n"
                    out += "\(opt.description).\n"
                }
            }
            out += ".El\n"
        }
        out += ".Sh EXIT STATUS\n"
        out += "The ttzip-cli utility exits 0 on success, and >0 if an error occurs conforming to BSD sysexits(3).\n"
        return out
    }
}

