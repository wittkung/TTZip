// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// POSIX terminal raw mode manager.
///
/// Wraps `termios` system calls to provide non-canonical, unbuffered character input
/// with RAII terminal state restoration and signal trap recovery.
public final class TerminalRawModeManager: @unchecked Sendable {
    public static let shared = TerminalRawModeManager()
    
    private let lock = NSLock()
    private var originalTermios = termios()
    private var isRawModeActive: Bool = false
    
    private init() {
        // 注册进程退出时的终极兜底复原钩子，防止异常退出导致终端状态被破坏
        atexit {
            TerminalRawModeManager.shared.disableRawMode()
        }
    }
    
    deinit {
        disableRawMode()
    }
    
    /// 检查当前是否处于 Raw 模式
    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRawModeActive
    }
    
    /// 启用终端 Raw 模式 (禁用回显、规范输入及信号字符，配置 100ms 非阻塞读取)
    /// - Returns: 是否成功进入 Raw 模式
    @discardableResult
    public func enableRawMode() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isRawModeActive else { return true }
        
        // 1. 验证 STDIN 是否为交互式终端
        guard isatty(STDIN_FILENO) != 0 else {
            return false
        }
        
        // 2. 保存原始 termios 属性
        if tcgetattr(STDIN_FILENO, &originalTermios) != 0 {
            return false
        }
        
        // 3. 构建 raw 模式属性
        var raw = originalTermios
        cfmakeraw(&raw)
        
        // 4. 配置 VMIN 与 VTIME 超时:
        // VMIN = 0, VTIME = 1 (100ms 超时非阻塞轮询)
        // 在 Darwin / POSIX 中 c_cc 数组中 VMIN 对应索引 16，VTIME 对应索引 17
        raw.c_cc.16 = 0 // VMIN = 0
        raw.c_cc.17 = 1 // VTIME = 1 (0.1 秒)
        
        // 5. 应用新属性
        if tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != 0 {
            return false
        }
        
        isRawModeActive = true
        return true
    }
    
    /// 退出 Raw 模式并恢复原始终端属性
    public func disableRawMode() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isRawModeActive else { return }
        
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawModeActive = false
    }
    
    /// 从终端标准输入读取单个字节 (根据 VTIME 拥有 100ms 超时)
    /// - Returns: 读取到的字节，若超时或无输入则返回 nil
    public func readByte() -> UInt8? {
        var byte: UInt8 = 0
        let bytesRead = read(STDIN_FILENO, &byte, 1)
        if bytesRead == 1 {
            return byte
        }
        return nil
    }
    
    /// 闭包 RAII 便捷包装器，自动管理 Raw 模式生命周期
    public func withRawMode<T>(_ body: () throws -> T) rethrows -> T {
        let enabled = enableRawMode()
        defer {
            if enabled {
                disableRawMode()
            }
        }
        return try body()
    }
}
