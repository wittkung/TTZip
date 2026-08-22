// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Production-grade POSIX / GNU compliant command-line argument parser.
///
/// Implements standard UNIX option conventions:
/// - Short flags (`-v`, `-x`, `-f`) and combined short flag clusters (`-vyf`).
/// - Short options taking values (`-p123456`, `-p 123456`).
/// - Long options with equals or space separation (`--format=tar.zst`, `--format tar.zst`).
/// - Standard end-of-options delimiter (`--`).
public enum POSIXCLIArgumentParser {
    
    /// Parse result containing detected command and typed options.
    public struct ParseResult: Sendable {
        public let command: CLICommand
        public let options: CLIOptions
    }
    
    /// Parses an array of raw command-line string arguments.
    /// - Parameter args: Command-line arguments without the executable path.
    /// - Returns: `ParseResult` with resolved command and options.
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
                parseLongOption(
                    token: token,
                    args: args,
                    currentIndex: &i,
                    options: &options,
                    detectedCommand: &detectedCommand
                )
                i += 1
                continue
            }
            
            // 3. 处理短选项与合并标志 (-h, -v, -q, -y, -vq, -f, -p pwd, -o dir, -x pat, -i pat, -j, -T file, -0, -P file, -n, -d N)
            if token.starts(with: "-") && token.count > 1 {
                parseShortOptions(
                    token: token,
                    args: args,
                    currentIndex: &i,
                    options: &options,
                    detectedCommand: &detectedCommand
                )
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
