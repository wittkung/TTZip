import Foundation
import QuartzCore
@_exported import CTTZipBridge

/// TTZip 统一高优先级底线 CLI 与进程调度器 (彻底保证 C 字符串生命周期安全)
public enum TTZipProcessExecutor {
    
    @inline(__always)
    @discardableResult
    public static func runCLI(_ executable: String, _ arguments: [String], currentDirectory: String? = nil) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cd = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cd)
        }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @inline(__always)
    public static func runCLIAsync(_ executable: String, _ arguments: [String], currentDirectory: String? = nil) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let cd = currentDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: cd)
            }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
