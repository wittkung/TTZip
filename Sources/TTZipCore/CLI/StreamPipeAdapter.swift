// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 流水线执行拓扑模式
public enum StreamExecutionMode: String, Sendable, Equatable, CaseIterable {
    /// 读写物理磁盘文件
    case directFile = "directFile"
    /// 从 stdin 读取归档数据，解压至目标目录
    case standardInputPipe = "standardInputPipe"
    /// 从磁盘读取输入，流式写入 stdout 归档
    case standardOutputPipe = "standardOutputPipe"
    /// 从 stdin 读取并向 stdout 发射
    case duplexPipe = "duplexPipe"
    /// 归档内单条目瞬时提取至 stdout（无磁盘中间文件）
    case singleEntryStdout = "singleEntryStdout"
}

/// 进度与日志输出路由策略
public enum StreamProgressRouting: String, Sendable, Equatable, CaseIterable {
    /// 完全静默进度
    case suppressed = "suppressed"
    /// 路由至 stderr（保证 stdout 纯净二进制流）
    case standardError = "standardError"
    /// 直接输出至 stdout（仅限 stdout 为交互式 TTY 且非二进制流）
    case inlineTty = "inlineTty"
}

/// 目标 Shell 补全方言
public enum ShellTarget: String, Sendable, Equatable, CaseIterable {
    case zsh = "zsh"
    case bash = "bash"
    case fish = "fish"
    case nushell = "nushell"
}

/// 流水线强类型配置模型
public struct StreamPipelineConfig: Sendable, Equatable {
    public let mode: StreamExecutionMode
    public let inputPath: String?
    public let outputPath: String?
    public let singleEntryName: String?
    public let forceBinary: Bool
    public let progressRouting: StreamProgressRouting
    public let streamBlockSize: Int
    
    public init(
        mode: StreamExecutionMode,
        inputPath: String? = nil,
        outputPath: String? = nil,
        singleEntryName: String? = nil,
        forceBinary: Bool = false,
        progressRouting: StreamProgressRouting = .standardError,
        streamBlockSize: Int = 65536
    ) {
        self.mode = mode
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.singleEntryName = singleEntryName
        self.forceBinary = forceBinary
        self.progressRouting = progressRouting
        self.streamBlockSize = streamBlockSize
    }
}

/// 标准输入/输出管道流式适配器 (Stream Pipe Adapter)
public enum StreamPipeAdapter {
    
    /// 检查路径是否代表标准流管道 ("-")
    @inline(__always)
    public static func isStandardStream(_ path: String?) -> Bool {
        guard let p = path?.trimmingCharacters(in: .whitespaces) else { return false }
        return p == "-"
    }
    
    /// 检查 stdout 是否连接至交互式终端 TTY
    @inline(__always)
    public static func isStdoutTTY() -> Bool {
        return Darwin.isatty(STDOUT_FILENO) != 0
    }
    
    /// 检查 stderr 是否连接至交互式终端 TTY
    @inline(__always)
    public static func isStderrTTY() -> Bool {
        return Darwin.isatty(STDERR_FILENO) != 0
    }
    
    /// 检查 stdin 是否连接至交互式终端 TTY
    @inline(__always)
    public static func isStdinTTY() -> Bool {
        return Darwin.isatty(STDIN_FILENO) != 0
    }
    
    /// 确定当前执行的流式模式
    public static func determineMode(
        inputPath: String?,
        outputPath: String?,
        isCat: Bool = false,
        entryName: String? = nil
    ) -> StreamExecutionMode {
        if isCat || entryName != nil {
            return .singleEntryStdout
        }
        let inStd = isStandardStream(inputPath)
        let outStd = isStandardStream(outputPath)
        
        if inStd && outStd {
            return .duplexPipe
        } else if inStd {
            return .standardInputPipe
        } else if outStd {
            return .standardOutputPipe
        } else {
            return .directFile
        }
    }
    
    /// 确定进度输出路由策略
    public static func determineProgressRouting(
        mode: StreamExecutionMode,
        isQuiet: Bool = false
    ) -> StreamProgressRouting {
        if isQuiet {
            return .suppressed
        }
        switch mode {
        case .standardOutputPipe, .duplexPipe, .singleEntryStdout:
            return isStderrTTY() ? .standardError : .suppressed
        case .standardInputPipe, .directFile:
            return isStdoutTTY() ? .inlineTty : (isStderrTTY() ? .standardError : .suppressed)
        }
    }
    
    /// 从标准输入流读取数据，自适应选择内存缓存或临时匿名文件
    public static func readStdinToTemporaryFileIfNeeded(suffix: String = ".tmp") throws -> (path: String, isTemporary: Bool) {
        let chunkSize = 64 * 1024 // 64 KB
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("ttzip_stdin_\(UUID().uuidString)\(suffix)")
        
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: tempFile) else {
            throw NSError(
                domain: "TTZipStreamPipe",
                code: 73,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary stdin spool file"]
            )
        }
        
        defer { try? handle.close() }
        
        var totalRead: Int64 = 0
        while true {
            let bytesRead = Darwin.read(STDIN_FILENO, buffer, chunkSize)
            if bytesRead <= 0 { break }
            
            let data = Data(bytesNoCopy: buffer, count: bytesRead, deallocator: .none)
            handle.write(data)
            totalRead += Int64(bytesRead)
        }
        
        return (tempFile.path, true)
    }
    
    /// 清理临时流式缓存文件
    public static func cleanupTemporaryFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
