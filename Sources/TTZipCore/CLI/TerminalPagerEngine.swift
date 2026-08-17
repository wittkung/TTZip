// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// 终端智能自动分页引擎 (Terminal Auto-Pager Engine)
public enum TerminalPagerEngine: Sendable {
    
    /// 获取终端窗口可视行数
    public static func getTerminalRows() -> Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0 {
            return Int(ws.ws_row)
        }
        if let linesStr = ProcessInfo.processInfo.environment["LINES"], let lines = Int(linesStr), lines > 0 {
            return lines
        }
        return 24 // 标准终端兜底默认高度
    }
    
    /// 将文本内容自适应输出至终端或分页器
    /// - Parameters:
    ///   - text: 待输出的内容文本
    ///   - noPager: 是否强制禁用分页器 (--no-pager)
    public static func display(text: String, noPager: Bool = false) {
        let isTTY = isatty(STDOUT_FILENO) != 0
        let termType = ProcessInfo.processInfo.environment["TERM"] ?? ""
        
        // 1. 若非 TTY 环境、TERM 为 dumb 或用户显式禁用分页，直接输出
        if !isTTY || noPager || termType == "dumb" {
            print(text)
            return
        }
        
        // 2. 计算文本总行数
        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let terminalRows = getTerminalRows()
        
        // 3. 行数未超出一屏时，直接 print 避免屏幕闪烁
        if lineCount < terminalRows {
            print(text)
            return
        }
        
        // 4. 行数超限，调度外部分页器
        let pagerCmd = ProcessInfo.processInfo.environment["TTZIP_PAGER"] ??
                       ProcessInfo.processInfo.environment["PAGER"] ??
                       "less -RFX"
        
        runWithPager(text: text, pagerCommand: pagerCmd)
    }
    
    private static func runWithPager(text: String, pagerCommand: String) {
        let parts = pagerCommand.split(separator: " ").map { String($0) }
        guard let execName = parts.first else {
            print(text)
            return
        }
        
        let args = Array(parts.dropFirst())
        let process = Process()
        
        // 查找执行文件路径
        if execName.starts(with: "/") {
            process.executableURL = URL(fileURLWithPath: execName)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/\(execName)")
            if !FileManager.default.fileExists(atPath: process.executableURL?.path ?? "") {
                process.executableURL = URL(fileURLWithPath: "/bin/\(execName)")
            }
        }
        
        process.arguments = args
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        // 屏蔽 SIGPIPE，防止分页器提前退出导致主进程崩溃
        #if canImport(Darwin)
        signal(SIGPIPE, SIG_IGN)
        #endif
        
        do {
            try process.run()
            if let data = text.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            try? inputPipe.fileHandleForWriting.close()
            process.waitUntilExit()
        } catch {
            // 分页器唤起失败时安全回退至标准输出
            print(text)
        }
    }
}
