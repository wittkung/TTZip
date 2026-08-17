// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 标准 BSD mdoc(7) Troff 手册页生成器 (BSD Man Page Generator)
///
/// 从 `CLICommandSpec` 单一真理源动态派生规范的 12-Section BSD mdoc 格式手册页，
/// 兼容 `man(1)`、`mandoc(1)` 与 `groff(1)`，遵循 BSD mdoc 规范章节顺序与宏语法。
public enum ManPageGenerator {
    
    /// 生成 `ttzip-cli(1)` 标准 mdoc 手册页
    public static func generateManPage(
        title: String = "TTZIP-CLI",
        section: Int = 1,
        date: String = "August 17, 2026"
    ) -> String {
        var out = ".Dd \(date)\n"
        out += ".Dt \(title) \(section)\n"
        out += ".Os macOS Sonoma+\n"
        
        // 1. NAME
        out += ".Sh NAME\n"
        out += ".Nm ttzip-cli\n"
        out += ".Nd High-performance native archive and compression CLI utility for macOS\n"
        
        // 2. SYNOPSIS
        out += ".Sh SYNOPSIS\n"
        out += ".Nm\n"
        out += ".Ar command\n"
        out += ".Op Fl -options\n"
        out += ".Op Ar arguments ...\n"
        
        // 3. DESCRIPTION
        out += ".Sh DESCRIPTION\n"
        out += "TTZip is an enterprise-grade, high-throughput in-process compression, extraction, and format inspection utility designed for macOS Sonoma and Apple Silicon. "
        out += "It achieves multi-gigabyte-per-second throughput via direct C static library bindings (libdeflate, zstd, fast-lzma2, libarchive) and zero-copy streaming I/O.\n"
        
        // 4. COMMANDS
        out += ".Sh COMMANDS\n"
        out += ".Bl -tag -width indent\n"
        for sub in CLICommandSpec.subcommands {
            let aliasesStr = sub.aliases.isEmpty ? "" : " (aliases: " + sub.aliases.joined(separator: ", ") + ")"
            out += ".It Cm \(sub.name)\(aliasesStr)\n"
            out += "\(sub.summary).\n"
            out += ".Pp\n"
            out += "Usage: Ar \(sub.usage)\n"
            if !sub.options.isEmpty {
                out += ".Pp\n"
                out += "Command options:\n"
                out += ".Bl -tag -width indent\n"
                for opt in sub.options {
                    out += formatOptionItem(opt)
                    out += "\(opt.description).\n"
                }
                out += ".El\n"
            }
        }
        out += ".El\n"
        
        // 5. OPTIONS (Global)
        out += ".Sh OPTIONS\n"
        out += ".Bl -tag -width indent\n"
        for opt in CLICommandSpec.globalOptions {
            out += formatOptionItem(opt)
            out += "\(opt.description).\n"
        }
        out += ".El\n"
        
        // 6. ENVIRONMENT
        out += ".Sh ENVIRONMENT\n"
        out += ".Bl -tag -width indent\n"
        out += ".It Ev NO_COLOR\n"
        out += "When set, disables all ANSI color formatting in terminal output.\n"
        out += ".It Ev COLORTERM\n"
        out += "When set to truecolor or 24bit, enables 24-bit TrueColor rendering.\n"
        out += ".It Ev COLUMNS\n"
        out += "Overrides detected terminal column width.\n"
        out += ".El\n"
        
        // 7. EXIT STATUS
        out += ".Sh EXIT STATUS\n"
        out += "The\n"
        out += ".Nm\n"
        out += "utility exits 0 on success, and >0 if an error occurs:\n"
        out += ".Bl -tag -width indent\n"
        out += ".It Sy 0\n"
        out += "Success.\n"
        out += ".It Sy 1\n"
        out += "General unexpected error.\n"
        out += ".It Sy 64\n"
        out += "Command line usage error or invalid arguments.\n"
        out += ".It Sy 65\n"
        out += "Data format error or CRC/integrity verification failure.\n"
        out += ".It Sy 66\n"
        out += "Input file or archive not found.\n"
        out += ".It Sy 73\n"
        out += "Cannot create output file or directory.\n"
        out += ".It Sy 74\n"
        out += "Input/output stream or disk I/O error.\n"
        out += ".It Sy 77\n"
        out += "Permission denied or missing cryptographic credentials.\n"
        out += ".It Sy 141\n"
        out += "Process terminated due to broken UNIX pipe (SIGPIPE).\n"
        out += ".El\n"
        
        // 8. EXAMPLES
        out += ".Sh EXAMPLES\n"
        out += "Create a high-speed TAR.ZST archive:\n"
        out += ".Pp\n"
        out += ".Dl $ ttzip-cli create archive.tar.zst src/ -f tar.zst -l 3\n"
        out += ".Pp\n"
        out += "Stream archive creation to stdout over UNIX pipeline:\n"
        out += ".Pp\n"
        out += ".Dl $ ttzip-cli create -f tar.zst -o - /var/log | ssh user@remote \"ttzip-cli extract -i - -d /backup/\"\n"
        out += ".Pp\n"
        out += "Extract a single file directly to stdout:\n"
        out += ".Pp\n"
        out += ".Dl $ ttzip-cli cat bundle.zip README.md | grep \"Installation\"\n"
        out += ".Pp\n"
        out += "Execute hardware-calibrated benchmark suite:\n"
        out += ".Pp\n"
        out += ".Dl $ ttzip-cli bench -f zip\n"
        
        // 9. SUPPORTED FORMATS
        out += ".Sh SUPPORTED FORMATS\n"
        out += "TTZip natively supports 16 compression and archive container formats:\n"
        out += ".Bl -column \"Format\" \"Compression\" \"Extraction\" -offset indent\n"
        out += ".It Sy Format Ta Sy Creation Ta Sy Extraction\n"
        out += ".It ZIP Ta Yes (AES-256 / Zip64) Ta Yes\n"
        out += ".It 7Z Ta Yes (LZMA2 / AES-256) Ta Yes\n"
        out += ".It TAR Ta Yes (POSIX.1-2001 Pax) Ta Yes\n"
        out += ".It TAR.ZST Ta Yes (Multi-threaded Zstd) Ta Yes\n"
        out += ".It TAR.GZ Ta Yes (Libdeflate / Gzip) Ta Yes\n"
        out += ".It TAR.BZ2 Ta Yes (Bzip2) Ta Yes\n"
        out += ".It TAR.XZ Ta Yes (LZMA2) Ta Yes\n"
        out += ".It LZ4 Ta Yes (High-speed frame) Ta Yes\n"
        out += ".It BROTLI Ta Yes (RFC 7932) Ta Yes\n"
        out += ".It SNAPPY Ta Yes (Framed stream) Ta Yes\n"
        out += ".It LZIP / LRZIP Ta Yes Ta Yes\n"
        out += ".It WIM / DMG / ISO Ta Yes Ta Yes\n"
        out += ".It RAR / CAB Ta No (Decompress only) Ta Yes\n"
        out += ".El\n"
        
        // 10. STANDARDS
        out += ".Sh STANDARDS\n"
        out += "TTZip complies with PKWARE APPNOTE.TXT v6.3.10 (ZIP), POSIX.1-2001 (Pax TAR), RFC 1952 (GZIP), RFC 8878 (Zstandard), and RFC 7932 (Brotli).\n"
        
        // 11. AUTHORS
        out += ".Sh AUTHORS\n"
        out += ".An Weitao Kung Aq Mt kevintungs@163.com\n"
        
        return out
    }
    
    private static func formatOptionItem(_ opt: CLIOptionSpec) -> String {
        var str = ".It "
        if let short = opt.shortName {
            str += "Cm -\(short) , --\(opt.longName)"
        } else {
            str += "Cm --\(opt.longName)"
        }
        if let v = opt.valueName {
            str += " <\(v)>"
        }
        str += "\n"
        return str
    }
}
