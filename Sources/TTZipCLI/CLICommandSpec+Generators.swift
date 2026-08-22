// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension CLICommandSpec {
    
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
