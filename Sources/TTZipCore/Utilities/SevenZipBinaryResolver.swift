import Foundation
import CTTZipBridge

/// 7-Zip 原生可执行二进制文件解析器 (支持 Bundle 包内嵌入解析与系统路径降级)
public final class SevenZipBinaryResolver: @unchecked Sendable {
    public static let shared = SevenZipBinaryResolver()

    private let lock = NSLock()
    private var cachedPath: String?

    private init() {}

    public static func resolveBinaryPath() -> String? {
        return shared.resolve()
    }

    public func resolve() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let path = cachedPath {
            return path
        }
        
        if let bundlePath = Bundle.main.path(forResource: "7zz", ofType: nil),
           FileManager.default.isExecutableFile(atPath: bundlePath) {
            ttzip_register_7zz_binary(bundlePath)
            cachedPath = bundlePath
            return bundlePath
        }
        
        let candidates = [
            "/opt/homebrew/bin/7zz",
            "/opt/homebrew/bin/7z",
            "/usr/local/bin/7zz",
            "/usr/local/bin/7z",
            "/usr/bin/7zz",
            "/usr/bin/7z"
        ]
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) || FileManager.default.fileExists(atPath: candidate) {
                ttzip_register_7zz_binary(candidate)
                cachedPath = candidate
                return candidate
            }
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["7zz"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    ttzip_register_7zz_binary(str)
                    cachedPath = str
                    return str
                }
            }
        }
        
        return nil
    }
}
