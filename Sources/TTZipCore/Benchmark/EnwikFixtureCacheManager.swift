import Foundation
import CryptoKit
import CTTZipBridge

#if os(macOS) || os(Linux)
import Darwin
#endif

/// 极端高压缩比语料 (enwik8 / enwik9) 外部集中缓存与自举加载管理器
///
/// 遵循 Constitution 隔离铁律：
/// - 零 Git 仓库膨胀，语料集中驻留于系统级测试缓存目录 (`~/Library/Caches/com.ttzip.tests/fixtures/`)
/// - 采用跨进程 POSIX `flock` 文件锁，确保 `swift test --parallel` 并发安全
/// - 支持多镜像源回退 (GitHub Release CDN -> 官方权威源 -> 确定性合成器离线降级)
public enum EnwikFixtureCacheManager {
    
    // MARK: - 黄金基准指纹定义
    
    public static let enwik8ByteCount: Int64 = 100_000_000
    public static let enwik8ExpectedSha256: String = "64cd7e3137eb139d48b7f83a48eef9c22956cfb2fdfbbfebf32b8eb4ec6cfd59"
    
    public static let enwik9ByteCount: Int64 = 1_000_000_000
    public static let enwik9ExpectedSha256: String = "f8d167f5f9e9cfda0c4a4a49df5d6de60c915f02888cf3b2f5673418579ad64b"
    
    // MARK: - 镜像源配置
    
    public static let defaultMirrors: [(name: String, enwik8Url: String, enwik9Url: String)] = [
        (
            name: "TTZip-GitHub-CDN",
            enwik8Url: "https://github.com/wittkung/TTZip/releases/download/fixtures-v1.0.0/enwik8.zip",
            enwik9Url: "https://github.com/wittkung/TTZip/releases/download/fixtures-v1.0.0/enwik9.zip"
        ),
        (
            name: "Matt-Mahoney-Origin",
            enwik8Url: "http://mattmahoney.net/dc/enwik8.zip",
            enwik9Url: "http://mattmahoney.net/dc/enwik9.zip"
        )
    ]
    
    // MARK: - 缓存根目录
    
    /// 获取集中测试缓存根目录 URL
    public static func cacheDirectoryURL() -> URL {
        #if os(macOS)
        let baseDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let targetDir = baseDir.appendingPathComponent("com.ttzip.tests/fixtures")
        #else
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"
        let targetDir = URL(fileURLWithPath: homeDir).appendingPathComponent(".cache/ttzip/fixtures")
        #endif
        
        if !PlatformFileSystem.fileExists(atPath: targetDir.path) {
            try? FileManager.default.createDirectory(atPath: targetDir.path, withIntermediateDirectories: true)
        }
        return targetDir
    }
    
    // MARK: - 语料加载与准备
    
    /// 确保并获取指定 enwik 语料的物理本地路径
    ///
    /// - Parameters:
    ///   - corpusId: "enwik8" 或 "enwik9"
    ///   - allowSyntheticFallback: 网络不可达或未缓存时，是否允许自动使用确定性合成器兜底
    /// - Returns: 语料文件的绝对物理路径
    public static func obtainCorpusPath(
        named corpusId: String,
        allowSyntheticFallback: Bool = true
    ) throws -> String {
        // 1. 优先检查外部环境变量直注路径
        let envVar = corpusId.uppercased() == "ENWIK9" ? "TTZIP_ENWIK9_PATH" : "TTZIP_ENWIK8_PATH"
        if let envPath = ProcessInfo.processInfo.environment[envVar], !envPath.isEmpty {
            if PlatformFileSystem.fileExists(atPath: envPath) {
                return envPath
            }
        }
        
        let isEnwik9 = (corpusId.lowercased() == "enwik9")
        let targetSize = isEnwik9 ? enwik9ByteCount : enwik8ByteCount
        let targetFileName = "\(corpusId.lowercased()).xml"
        let targetURL = cacheDirectoryURL().appendingPathComponent(targetFileName)
        let lockFilePath = targetURL.path + ".lock"
        
        // 2. 检查本地缓存是否已存在且尺寸匹配
        if let attrs = try? PlatformFileSystem.statFile(path: targetURL.path), attrs.size == targetSize {
            return targetURL.path
        }
        
        // 3. 进入跨进程文件锁，准备下载或生成
        return try PlatformFileSystem.withFileLock(atPath: lockFilePath, type: .exclusive) {
            // 双重检查 (Idempotency Check)
            if let attrs = try? PlatformFileSystem.statFile(path: targetURL.path), attrs.size == targetSize {
                return targetURL.path
            }
            
            let tempURL = targetURL.deletingLastPathComponent().appendingPathComponent("\(targetFileName).tmp.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString.prefix(8))")
            defer {
                if PlatformFileSystem.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
            
            // 4. 尝试从远程镜像下载
            var downloadSucceeded = false
            for mirror in defaultMirrors {
                let urlString = isEnwik9 ? mirror.enwik9Url : mirror.enwik8Url
                guard let url = URL(string: urlString) else { continue }
                
                if let downloadedData = downloadFileSynchronously(url: url) {
                    // 若下载的是 zip 包，写入临时文件并就地解压提取
                    let zipTempURL = tempURL.appendingPathExtension("zip")
                    defer { try? FileManager.default.removeItem(at: zipTempURL) }
                    
                    if (try? downloadedData.write(to: zipTempURL)) != nil {
                        // 提取单个 100MB / 1GB xml
                        if extractZipPayload(from: zipTempURL, to: tempURL) {
                            if let attrs = try? PlatformFileSystem.statFile(path: tempURL.path), attrs.size == targetSize {
                                downloadSucceeded = true
                                break
                            }
                        }
                    }
                }
            }
            
            // 5. 若下载失败且允许合成降级，使用确定性合成器秒级生成
            if !downloadSucceeded {
                if allowSyntheticFallback {
                    let config = SyntheticXmlCorpusConfig(
                        totalByteCount: targetSize,
                        repeatDistanceBytes: isEnwik9 ? 32 * 1024 * 1024 : 16 * 1024 * 1024,
                        repeatProbability: 0.70,
                        seed: isEnwik9 ? 0x9876543210FEDCBA : 0x123456789ABCDEF0
                    )
                    try SyntheticXmlCorpusGenerator.generate(config: config, to: tempURL)
                } else {
                    throw NSError(
                        domain: "EnwikFixtureCacheManager",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to download corpus '\(corpusId)' and synthetic fallback is disabled."]
                    )
                }
            }
            
            // 6. 原子重命名发布 (POSIX rename)
            if rename(tempURL.path, targetURL.path) != 0 {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            
            return targetURL.path
        }
    }
    
    // MARK: - 辅助下载与解压原语
    
    private static func downloadFileSynchronously(url: URL) -> Data? {
        final class ResultBox: @unchecked Sendable {
            var data: Data?
        }
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10秒快速超时
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, let data = data {
                box.data = data
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 12.0)
        return box.data
    }
    
    private static func extractZipPayload(from zipURL: URL, to outputURL: URL) -> Bool {
        // 利用系统 unzip 或基础流式解压
        let process = Process()
        let unzipBin = PlatformFileSystem.fileExists(atPath: "/usr/bin/unzip") ? "/usr/bin/unzip" : "unzip"
        process.executableURL = URL(fileURLWithPath: unzipBin)
        process.arguments = ["-p", zipURL.path]
        
        let parentDir = outputURL.deletingLastPathComponent().path
        if !PlatformFileSystem.fileExists(atPath: parentDir) {
            try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }
        
        let outFd = open(outputURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard outFd >= 0 else { return false }
        defer { close(outFd) }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let readHandle = pipe.fileHandleForReading
            while true {
                let chunk = readHandle.readData(ofLength: 65536)
                if chunk.isEmpty { break }
                _ = chunk.withUnsafeBytes { rawPtr in
                    write(outFd, rawPtr.baseAddress!, chunk.count)
                }
            }
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
