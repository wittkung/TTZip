import Foundation

/// 声明式命令行选项规范模型
public struct CLIOptionSpec: Sendable {
    public let shortName: String?
    public let longName: String
    public let description: String
    public let takesValue: Bool
    public let valueName: String?
    
    public init(shortName: String? = nil, longName: String, description: String, takesValue: Bool = false, valueName: String? = nil) {
        self.shortName = shortName
        self.longName = longName
        self.description = description
        self.takesValue = takesValue
        self.valueName = valueName
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
        CLIOptionSpec(longName: "lang", description: "Set language (en, zh-Hans, zh-Hant, ja, de, fr, es)", takesValue: true, valueName: "LANG")
    ]
    
    public static let subcommands: [CLICommandMetadata] = [
        CLICommandMetadata(
            name: "archive",
            aliases: ["a", "create", "c"],
            summary: "Create an archive from source files or directories",
            usage: "ttzip-cli archive <output_archive> <inputs...> [options]",
            options: [
                CLIOptionSpec(shortName: "f", longName: "format", description: "Archive format (zip, 7z, tar.zst, etc.)", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(shortName: "l", longName: "level", description: "Compression level (0-9, store, fast, ultra)", takesValue: true, valueName: "LEVEL"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Encrypt archive with AES-256 password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "s", longName: "split", description: "Split archive into multi-part volumes (e.g. 100M, 1G)", takesValue: true, valueName: "SIZE")
            ]
        ),
        CLICommandMetadata(
            name: "extract",
            aliases: ["x", "e"],
            summary: "Extract files from an archive",
            usage: "ttzip-cli extract <archive> -o <dest_dir> [options]",
            options: [
                CLIOptionSpec(shortName: "o", longName: "output", description: "Destination directory (or '-' for stdout)", takesValue: true, valueName: "DIR"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "k", longName: "keep", description: "Keep damaged or partially extracted files")
            ]
        ),
        CLICommandMetadata(
            name: "list",
            aliases: ["l", "ls"],
            summary: "List contents of an archive",
            usage: "ttzip-cli list <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD")
            ]
        ),
        CLICommandMetadata(
            name: "test",
            aliases: ["t", "verify"],
            summary: "Test archive integrity or run automated test suites",
            usage: "ttzip-cli test [archive] [options]",
            options: [
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
            summary: "Generate shell auto-completion scripts (zsh, bash, fish)",
            usage: "ttzip-cli completion <zsh|bash|fish>"
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
        out += "        '(-h --help)'{-h,--help}'[Show help information]' \\\n"
        out += "        '(-V --version)'{-V,--version}'[Show version]' \\\n"
        out += "        '--json[Output NDJSON stream]' \\\n"
        out += "        '--no-color[Disable colors]' \\\n"
        out += "        '1: :->command' \\\n"
        out += "        '*:: :->args'\n\n"
        out += "    case $state in\n"
        out += "        command)\n"
        out += "            local -a subcommands\n"
        out += "            subcommands=(\n"
        for sub in subcommands {
            out += "                '\(sub.name):\(sub.summary)'\n"
        }
        out += "            )\n"
        out += "            _describe -t subcommands 'ttzip-cli command' subcommands\n"
        out += "            ;;\n"
        out += "        args)\n"
        out += "            _files\n"
        out += "            ;;\n"
        out += "    esac\n"
        out += "}\n\n"
        out += "_ttzip_cli \"$@\"\n"
        return out
    }
    
    public static func generateBashCompletion() -> String {
        var out = "#!/usr/bin/env bash\n\n"
        out += "_ttzip_cli_completions() {\n"
        out += "    local cur prev subcommands\n"
        out += "    cur=\"${COMP_WORDS[COMP_CWORD]}\"\n"
        out += "    prev=\"${COMP_WORDS[COMP_CWORD-1]}\"\n"
        let cmds = subcommands.map(\.name).joined(separator: " ")
        out += "    subcommands=\"\(cmds)\"\n\n"
        out += "    if [ $COMP_CWORD -eq 1 ]; then\n"
        out += "        COMPREPLY=( $(compgen -W \"$subcommands --help --version\" -- \"$cur\") )\n"
        out += "        return 0\n"
        out += "    fi\n"
        out += "    COMPREPLY=( $(compgen -f -- \"$cur\") )\n"
        out += "}\n\n"
        out += "complete -F _ttzip_cli_completions ttzip-cli\n"
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
        out += ".Sh SUBCOMMANDS\n"
        for sub in subcommands {
            out += ".Bl -tag -width indent\n"
            out += ".It Cm \(sub.name)\n"
            out += "\(sub.summary).\n"
            out += "Usage: Ar \(sub.usage)\n"
            out += ".El\n"
        }
        out += ".Sh EXIT STATUS\n"
        out += "The ttzip-cli utility exits 0 on success, and >0 if an error occurs conforming to BSD sysexits(3).\n"
        return out
    }
}
