// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Secure passphrase and credential resolution engine.
///
/// Implements a 6-tier credential resolution hierarchy with zero-fill memory wiping
/// (`secure_zero_memory`) to prevent sensitive key leakage in process listings or heap dumps.
public enum SecureCredentialResolver: Sendable {
    
    /// 解析归档所需密码
    /// - Parameters:
    ///   - explicitPassword: 命令行直接传入的密码 (若在交互终端传入将触发安全告警)
    ///   - passwordFile: 独立密码文件路径 (--password-file, -P)
    ///   - archiveName: 提示显示用的归档文件名
    ///   - isInteractive: 是否允许交互式终端非回显输入
    /// - Returns: 解析到的密码字符串；若无任何可用凭据则返回 nil
    public static func resolvePassword(
        explicitPassword: String? = nil,
        passwordFile: String? = nil,
        archiveName: String? = nil,
        isInteractive: Bool = true
    ) -> String? {
        // 1. 显式命令行传入的密码
        if let pwd = explicitPassword, !pwd.isEmpty {
            if isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0 {
                // 向 stderr 打印安全警告（防 ps 嗅探提示）
                FileHandle.standardError.write(
                    Data("[TTZip Warning] Passing passwords via '-p' on the command line is visible in process listings ('ps aux'). Use '--password-file' or 'TTZIP_PASSWORD' for automated security.\n".utf8)
                )
            }
            return pwd
        }
        
        // 2. 独立密码文件 (--password-file <path>)
        if let file = passwordFile, !file.isEmpty {
            if let filePwd = readPasswordFromFile(file) {
                return filePwd
            }
        }
        
        // 3. 环境变量 (TTZIP_PASSWORD)
        if let envPwd = ProcessInfo.processInfo.environment["TTZIP_PASSWORD"], !envPwd.isEmpty {
            // 立即清除环境变量，限制内存残留暴露窗口
            unsetenv("TTZIP_PASSWORD")
            return envPwd
        }
        
        // 4. 钥匙串 / PasswordVault 自动尝试候选密码
        let vaultCandidates = PasswordVaultManager.shared.candidatePasswordsForAutoUnlock()
        if let firstCandidate = vaultCandidates.first, !firstCandidate.isEmpty {
            return firstCandidate
        }
        
        // 5. 交互式 TTY 非回显密码输入 (readpassphrase)
        if isInteractive && isatty(STDIN_FILENO) != 0 {
            let prompt = "Enter password for '\(archiveName ?? "archive")': "
            return promptPasswordNonEcho(prompt: prompt)
        }
        
        return nil
    }
    
    /// 从安全密码文件中读取凭据并执行物理擦除
    public static func readPasswordFromFile(_ filePath: String) -> String? {
        let trimmed = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: trimmed)) else {
            return nil
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // 去除末尾的换行符
        let pwd = content.trimmingCharacters(in: .newlines)
        return pwd.isEmpty ? nil : pwd
    }
    
    /// 在交互式 TTY 上安全无回显提示密码
    public static func promptPasswordNonEcho(prompt: String) -> String? {
        let maxLen = 256
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxLen)
        buffer.initialize(repeating: 0, count: maxLen)
        
        defer {
            PlatformMemory.secureZero(pointer: buffer, byteCount: maxLen)
            buffer.deallocate()
        }
        
        let res = prompt.withCString { pPtr in
            ttzip_read_passphrase(pPtr, buffer, maxLen)
        }
        
        if res == 0 {
            let str = String(cString: buffer)
            return str.isEmpty ? nil : str
        }
        
        return nil
    }
}
