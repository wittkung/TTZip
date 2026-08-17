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

/// 动作决议指令
public enum FileCollisionAction: Sendable {
    case overwrite
    case skip
    case backup
    case abort
}

/// 文件覆盖与冲突解析处理器 (File Collision Resolver)
public final class FileCollisionResolver: @unchecked Sendable {
    private var activePolicy: FileCollisionPolicy
    private let lock = NSLock()
    
    public init(policy: FileCollisionPolicy = .prompt) {
        self.activePolicy = policy
    }
    
    /// 评估目标文件冲突并决定处理动作
    /// - Parameters:
    ///   - destinationPath: 拟写入的目标磁盘路径
    ///   - entrySize: 归档条目未压缩尺寸
    ///   - entryMtime: 归档条目修改时间
    /// - Returns: 解析后的行动指令
    public func resolveCollision(
        destinationPath: String,
        entrySize: Int64 = 0,
        entryMtime: Int64 = 0
    ) -> FileCollisionAction {
        lock.lock()
        defer { lock.unlock() }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: destinationPath) else {
            return .overwrite
        }
        
        switch activePolicy {
        case .always:
            return .overwrite
            
        case .never:
            return .skip
            
        case .backup:
            createBackupFile(at: destinationPath)
            return .overwrite
            
        case .newer:
            if let attrs = try? fm.attributesOfItem(atPath: destinationPath),
               let modDate = attrs[.modificationDate] as? Date {
                let existingMtime = Int64(modDate.timeIntervalSince1970)
                let existingSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                if entryMtime > existingMtime || entrySize != existingSize {
                    return .overwrite
                } else {
                    return .skip
                }
            }
            return .overwrite
            
        case .prompt:
            // 若非交互式 TTY，默认安全跳过或覆盖
            if isatty(STDIN_FILENO) == 0 {
                return .overwrite
            }
            return promptUserOnTTY(destinationPath: destinationPath)
        }
    }
    
    private func createBackupFile(at targetPath: String) {
        let fm = FileManager.default
        let bakPath = "\(targetPath).bak"
        if fm.fileExists(atPath: bakPath) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let uniqueBakPath = "\(targetPath).\(timestamp).bak"
            try? fm.moveItem(atPath: targetPath, toPath: uniqueBakPath)
        } else {
            try? fm.moveItem(atPath: targetPath, toPath: bakPath)
        }
    }
    
    private func promptUserOnTTY(destinationPath: String) -> FileCollisionAction {
        let baseName = (destinationPath as NSString).lastPathComponent
        guard let tty = fopen("/dev/tty", "r") else {
            return .overwrite
        }
        defer { fclose(tty) }
        
        FileHandle.standardError.write(
            Data("replace \(baseName)? [y]es, [n]o, [A]ll, [N]one, [b]ackup, [q]uit: ".utf8)
        )
        
        var charBuf = [CChar](repeating: 0, count: 64)
        if fgets(&charBuf, 64, tty) != nil {
            let resp = String(cString: charBuf).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch resp {
            case "y", "yes":
                return .overwrite
            case "n", "no":
                return .skip
            case "a", "all":
                activePolicy = .always
                return .overwrite
            case "none":
                activePolicy = .never
                return .skip
            case "b", "backup":
                createBackupFile(at: destinationPath)
                return .overwrite
            case "q", "quit":
                return .abort
            default:
                return .skip
            }
        }
        return .skip
    }
}
