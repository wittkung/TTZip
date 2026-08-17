import Foundation
import CryptoKit
import CTTZipBridge

// MARK: - Manifest Entry Types

/// 文件系统条目类型
public enum EntryType: String, Sendable, Equatable, Codable {
    case regularFile = "regular"
    case directory = "directory"
    case symbolicLink = "symlink"
    case hardLink = "hardlink"
}

/// 文件树清单单个条目记录
public struct ManifestEntry: Sendable, Equatable, Codable {
    public typealias EntryType = TTZipCore.EntryType

    public let relativePath: String                // APFS 规范化相对路径
    public let entryType: EntryType
    public let byteSize: Int64
    public let sha256Checksum: String              // 十六进制小写 SHA-256 哈希（目录和符号链接为空）
    public let posixMode: UInt16                   // 低 9 位 POSIX 权限位 (st_mode & 0o777)
    public let symlinkTarget: String?              // 符号链接目标路径

    public init(
        relativePath: String,
        entryType: EntryType,
        byteSize: Int64,
        sha256Checksum: String,
        posixMode: UInt16,
        symlinkTarget: String? = nil
    ) {
        self.relativePath = relativePath
        self.entryType = entryType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.posixMode = posixMode
        self.symlinkTarget = symlinkTarget
    }
}

// MARK: - File Tree Manifest

/// 解压后文件系统树清单 (用于跨预言机 1:1 双向差分比对)
public struct FileTreeManifest: Sendable, Equatable, Codable {
    public let rootDirectory: String
    public let entries: [String: ManifestEntry]    // 以 APFS 规范化相对路径为键
    public let totalByteSize: Int64
    public let totalFileCount: Int
    public let totalDirectoryCount: Int
    public let totalSymlinkCount: Int

    public init(
        rootDirectory: String,
        entries: [String: ManifestEntry],
        totalByteSize: Int64,
        totalFileCount: Int,
        totalDirectoryCount: Int,
        totalSymlinkCount: Int
    ) {
        self.rootDirectory = rootDirectory
        self.entries = entries
        self.totalByteSize = totalByteSize
        self.totalFileCount = totalFileCount
        self.totalDirectoryCount = totalDirectoryCount
        self.totalSymlinkCount = totalSymlinkCount
    }
}

// MARK: - Differential Test Report

/// 双向差分测试结果报告模型
public struct DifferentialTestReport: Sendable, Equatable, Codable {
    public let format: ArchiveCompressionFormat
    public let targetOracle: String                // 如 "/usr/bin/tar", "bsdtar", "7zz"
    public let isPassed: Bool
    public let ttzipManifest: FileTreeManifest
    public let oracleManifest: FileTreeManifest
    public let divergenceErrors: [String]          // 分歧详细描述
    public let hexDiffOutput: String?              // 二进制分歧时的 HexDiff 窗口输出

    public init(
        format: ArchiveCompressionFormat,
        targetOracle: String,
        isPassed: Bool,
        ttzipManifest: FileTreeManifest,
        oracleManifest: FileTreeManifest,
        divergenceErrors: [String],
        hexDiffOutput: String? = nil
    ) {
        self.format = format
        self.targetOracle = targetOracle
        self.isPassed = isPassed
        self.ttzipManifest = ttzipManifest
        self.oracleManifest = oracleManifest
        self.divergenceErrors = divergenceErrors
        self.hexDiffOutput = hexDiffOutput
    }
}

// MARK: - Differential Manifest Scanner

/// 文件系统树递归扫描与不可变清单生成器
public enum DifferentialManifestScanner: Sendable {
    
    /// 递归扫描指定目录并构建 `FileTreeManifest`
    ///
    /// - Parameter path: 待扫描的根目录路径
    /// - Returns: 不可变的标准化 `FileTreeManifest`
    public static func scanDirectory(atPath path: String) throws -> FileTreeManifest {
        let rootURL = URL(fileURLWithPath: path).standardized
        let rootPath = rootURL.path
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        
        var entries: [String: ManifestEntry] = [:]
        var totalByteSize: Int64 = 0
        var totalFileCount: Int = 0
        var totalDirectoryCount: Int = 0
        var totalSymlinkCount: Int = 0
        
        func traverse(dirPath: String) throws {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            for item in contents.sorted() {
                if item == ".noindex" || item == ".DS_Store" {
                    continue
                }
                let fullPath = (dirPath as NSString).appendingPathComponent(item)
                var st = stat()
                guard lstat(fullPath, &st) == 0 else { continue }
                
                var relPath = fullPath
                if relPath.hasPrefix(rootPath) {
                    relPath = String(relPath.dropFirst(rootPath.count))
                }
                while relPath.hasPrefix("/") {
                    relPath = String(relPath.dropFirst())
                }
                let normalizedRelPath = relPath.precomposedStringWithCanonicalMapping
                
                let mode = UInt16(st.st_mode & 0o777)
                let sMode = mode_t(st.st_mode)
                
                if (sMode & S_IFMT) == S_IFLNK {
                    var linkBuf = [CChar](repeating: 0, count: Int(PATH_MAX))
                    let len = readlink(fullPath, &linkBuf, linkBuf.count - 1)
                    let target: String? = len > 0 ? String(decoding: linkBuf.prefix(Int(len)).map { UInt8(bitPattern: $0) }, as: UTF8.self) : nil
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .symbolicLink,
                        byteSize: Int64(st.st_size),
                        sha256Checksum: "",
                        posixMode: mode,
                        symlinkTarget: target
                    )
                    entries[normalizedRelPath] = entry
                    totalSymlinkCount += 1
                } else if (sMode & S_IFMT) == S_IFDIR {
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .directory,
                        byteSize: 0,
                        sha256Checksum: "",
                        posixMode: mode,
                        symlinkTarget: nil
                    )
                    entries[normalizedRelPath] = entry
                    totalDirectoryCount += 1
                    try traverse(dirPath: fullPath)
                } else {
                    let fileSize = Int64(st.st_size)
                    let checksum = computeFileSHA256(path: fullPath, size: Int(st.st_size))
                    let entry = ManifestEntry(
                        relativePath: normalizedRelPath,
                        entryType: .regularFile,
                        byteSize: fileSize,
                        sha256Checksum: checksum,
                        posixMode: mode,
                        symlinkTarget: nil
                    )
                    entries[normalizedRelPath] = entry
                    totalByteSize += fileSize
                    totalFileCount += 1
                }
            }
        }
        
        try traverse(dirPath: rootPath)
        
        return FileTreeManifest(
            rootDirectory: rootPath,
            entries: entries,
            totalByteSize: totalByteSize,
            totalFileCount: totalFileCount,
            totalDirectoryCount: totalDirectoryCount,
            totalSymlinkCount: totalSymlinkCount
        )
    }
    
    // MARK: - SHA-256 Checksum Helper
    
    private static func computeFileSHA256(path: String, size: Int) -> String {
        guard size > 0 else {
            return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return "" }
        defer { close(fd) }
        
        if size < 32 * 1024 * 1024, let mapped = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED {
            defer { munmap(mapped, size) }
            posix_madvise(mapped, size, POSIX_MADV_WILLNEED)
            var hasher = SHA256()
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: mapped, count: size))
            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }
        
        var hasher = SHA256()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var bytesRead = read(fd, buffer, bufferSize)
        while bytesRead > 0 {
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: bytesRead))
            bytesRead = read(fd, buffer, bufferSize)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Differential Manifest Verifier

/// 5 维度双向清单比对与分歧检测验证器
public enum DifferentialManifestVerifier: Sendable {
    
    /// 比对 TTZip 与参考预言机输出清单
    ///
    /// - Parameters:
    ///   - ttzip: TTZip 生成的文件树清单
    ///   - oracle: 官方参考预言机生成的文件树清单
    ///   - format: 测试归档格式
    ///   - oracleName: 参考预言机名称或路径
    /// - Returns: 包含分歧与 HexDiff 的完整差分测试报告
    public static func compare(
        ttzip: FileTreeManifest,
        oracle: FileTreeManifest,
        format: ArchiveCompressionFormat,
        oracleName: String
    ) -> DifferentialTestReport {
        var divergenceErrors: [String] = []
        var hexDiffOutput: String? = nil
        
        let ttzipKeys = Set(ttzip.entries.keys)
        let oracleKeys = Set(oracle.entries.keys)
        
        // 1. 检测缺失条目 (在预言机中存在但 TTZip 遗漏)
        let missingKeys = oracleKeys.subtracting(ttzipKeys).sorted()
        for key in missingKeys {
            let oracleEntry = oracle.entries[key]!
            divergenceErrors.append("Missing entry in TTZip output: '\(key)' (oracle type: \(oracleEntry.entryType.rawValue), size: \(oracleEntry.byteSize)B)")
        }
        
        // 2. 检测多余条目 (TTZip 意外生成但预言机中不存在)
        let extraKeys = ttzipKeys.subtracting(oracleKeys).sorted()
        for key in extraKeys {
            let ttzipEntry = ttzip.entries[key]!
            divergenceErrors.append("Unexpected extra entry in TTZip output: '\(key)' (ttzip type: \(ttzipEntry.entryType.rawValue), size: \(ttzipEntry.byteSize)B)")
        }
        
        // 3. 5 维度逐条目比对 (公共条目)
        let commonKeys = ttzipKeys.intersection(oracleKeys).sorted()
        for key in commonKeys {
            let ttzipEntry = ttzip.entries[key]!
            let oracleEntry = oracle.entries[key]!
            
            // 维度 1: 条目类型
            if ttzipEntry.entryType != oracleEntry.entryType {
                divergenceErrors.append("Entry '\(key)' type mismatch: TTZip is \(ttzipEntry.entryType.rawValue), Oracle is \(oracleEntry.entryType.rawValue)")
                continue
            }
            
            // 维度 2: 文件大小与 SHA-256 校验和 (针对常规文件)
            if ttzipEntry.entryType == .regularFile {
                if ttzipEntry.byteSize != oracleEntry.byteSize {
                    divergenceErrors.append("Entry '\(key)' byte size mismatch: TTZip=\(ttzipEntry.byteSize)B, Oracle=\(oracleEntry.byteSize)B")
                }
                
                if ttzipEntry.sha256Checksum != oracleEntry.sha256Checksum {
                    divergenceErrors.append("Entry '\(key)' SHA-256 checksum mismatch: TTZip=\(ttzipEntry.sha256Checksum), Oracle=\(oracleEntry.sha256Checksum)")
                    
                    // 提取首个不匹配文件的 16 字节对齐 HexDiff
                    if hexDiffOutput == nil {
                        let ttzipFilePath = (ttzip.rootDirectory as NSString).appendingPathComponent(key)
                        let oracleFilePath = (oracle.rootDirectory as NSString).appendingPathComponent(key)
                        if let ttzipData = try? Data(contentsOf: URL(fileURLWithPath: ttzipFilePath), options: .mappedIfSafe),
                           let oracleData = try? Data(contentsOf: URL(fileURLWithPath: oracleFilePath), options: .mappedIfSafe) {
                            hexDiffOutput = FastHexDiffEngine.generateDiff(expected: oracleData, actual: ttzipData)
                        }
                    }
                }
            }
            
            // 维度 3: 符号链接目标
            if ttzipEntry.entryType == .symbolicLink {
                if ttzipEntry.symlinkTarget != oracleEntry.symlinkTarget {
                    divergenceErrors.append("Entry '\(key)' symlink target mismatch: TTZip target='\(ttzipEntry.symlinkTarget ?? "nil")', Oracle target='\(oracleEntry.symlinkTarget ?? "nil")'")
                }
            }
            
            // 维度 4: POSIX 权限位
            if ttzipEntry.posixMode != oracleEntry.posixMode {
                divergenceErrors.append("Entry '\(key)' POSIX permission mismatch: TTZip=0o\(String(ttzipEntry.posixMode, radix: 8)), Oracle=0o\(String(oracleEntry.posixMode, radix: 8))")
            }
        }
        
        let isPassed = divergenceErrors.isEmpty
        return DifferentialTestReport(
            format: format,
            targetOracle: oracleName,
            isPassed: isPassed,
            ttzipManifest: ttzip,
            oracleManifest: oracle,
            divergenceErrors: divergenceErrors,
            hexDiffOutput: hexDiffOutput
        )
    }
}

// MARK: - Oracle Binary Resolver

/// 预言机二进制可执行文件动态发现与路径解析器
public struct OracleBinaryResolver: Sendable {
    
    /// 标准预言机候选搜索目录清单
    public static let standardSearchDirectories: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]
    
    /// 解析二进制可执行文件绝对路径
    ///
    /// - Parameter binaryName: 二进制名称（如 "tar", "7zz", "unzip"）或绝对路径
    /// - Returns: 可执行文件的有效绝对路径；若未发现则返回 nil
    public static func resolve(binaryName: String) -> String? {
        let fm = FileManager.default
        
        // 1. 如果本身是绝对路径且可执行
        if binaryName.hasPrefix("/") {
            if fm.isExecutableFile(atPath: binaryName) {
                return binaryName
            }
            if fm.fileExists(atPath: binaryName) {
                return binaryName
            }
        }
        
        // 2. 遍历标准安装目录
        for dir in standardSearchDirectories {
            let candidate = (dir as NSString).appendingPathComponent(binaryName)
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        
        // 3. 通过系统 /usr/bin/which 探测
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [binaryName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !str.isEmpty,
                   fm.isExecutableFile(atPath: str) {
                    return str
                }
            }
        }
        
        return nil
    }
    
    /// 获取已解析二进制工具的版本字符串 (如可用)
    public static func resolveVersion(for binaryPath: String) async -> String? {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return nil }
        let binaryName = (binaryPath as NSString).lastPathComponent.lowercased()
        let versionArg: String
        if binaryName.contains("unzip") {
            versionArg = "-v"
        } else if binaryName.contains("7z") {
            versionArg = "--help"
        } else {
            versionArg = "--version"
        }
        
        if let result = try? await SubprocessExecutor.shared.executeAsync(
            executablePath: binaryPath,
            arguments: [versionArg]
        ), result.exitCode == 0 {
            let firstLine = result.output.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            return firstLine?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

// MARK: - Differential Oracle Registry

/// 跨平台与本地系统参考预言机注册表
public struct DifferentialOracleRegistry: @unchecked Sendable {
    public static let shared = DifferentialOracleRegistry()
    
    /// 核心强制要求的原生系统预言机 (必须在 macOS 上就绪)
    public static let mandatoryOracleNames: [String] = ["tar", "unzip"]
    
    /// 全量已知参考预言机名称集合
    public static let knownOracleNames: [String] = [
        "tar",
        "bsdtar",
        "unzip",
        "zip",
        "7zz",
        "7z",
        "zstd",
        "gzip",
        "xz"
    ]
    
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var oracleMap: [String: String] = [:]
    }
    
    private let storage: Storage
    
    public init() {
        self.storage = Storage()
        self.storage.oracleMap = discoverOracles()
    }
    
    /// 动态发现并扫描系统中全部可用的预言机二进制路径
    public func discoverOracles() -> [String: String] {
        var discovered: [String: String] = [:]
        for name in Self.knownOracleNames {
            if let path = OracleBinaryResolver.resolve(binaryName: name) {
                discovered[name] = path
            }
        }
        
        // 核心默认兜底硬编码路径保证
        if discovered["tar"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/tar") {
            discovered["tar"] = "/usr/bin/tar"
        }
        if discovered["unzip"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip") {
            discovered["unzip"] = "/usr/bin/unzip"
        }
        if discovered["zip"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/zip") {
            discovered["zip"] = "/usr/bin/zip"
        }
        if discovered["bsdtar"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/bsdtar") {
            discovered["bsdtar"] = "/usr/bin/bsdtar"
        }
        if discovered["gzip"] == nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/gzip") {
            discovered["gzip"] = "/usr/bin/gzip"
        }
        
        return discovered
    }
    
    /// 查询指定预言机名称或路径的实际可执行路径
    public func oraclePath(for name: String) -> String? {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        
        if let direct = storage.oracleMap[name] {
            return direct
        }
        if name.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: name) {
            return name
        }
        let baseName = (name as NSString).lastPathComponent
        if let mapped = storage.oracleMap[baseName] {
            return mapped
        }
        if let resolved = OracleBinaryResolver.resolve(binaryName: name) {
            storage.oracleMap[name] = resolved
            return resolved
        }
        return nil
    }
    
    /// 获取当前系统中所有可用预言机的名称列表
    public func availableOracles() -> [String] {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return Array(storage.oracleMap.keys).sorted()
    }
    
    /// 判定指定预言机在当前运行环境中是否可用
    public func isAvailable(oracle: String) -> Bool {
        return oraclePath(for: oracle) != nil
    }
    
    /// 判定全部核心强制预言机（/usr/bin/tar, /usr/bin/unzip）是否就绪
    public func mandatoryOraclesAvailable() -> Bool {
        for name in Self.mandatoryOracleNames {
            if oraclePath(for: name) == nil {
                return false
            }
        }
        return true
    }
    
    /// 针对特定归档压缩格式返回推荐的首选预言机路径
    public func defaultOracle(for format: ArchiveCompressionFormat) -> String? {
        switch format {
        case .tar:
            return oraclePath(for: "tar") ?? oraclePath(for: "bsdtar")
        case .zip:
            return oraclePath(for: "unzip")
        case .sevenZip:
            return oraclePath(for: "7zz") ?? oraclePath(for: "7z")
        case .zst, .tarZst:
            return oraclePath(for: "zstd") ?? oraclePath(for: "tar")
        case .gz, .tarGz:
            return oraclePath(for: "gzip") ?? oraclePath(for: "tar")
        case .bz2, .tarBz2:
            return oraclePath(for: "tar")
        case .xz, .tarXz:
            return oraclePath(for: "xz") ?? oraclePath(for: "tar")
        default:
            return oraclePath(for: "tar") ?? oraclePath(for: "7zz")
        }
    }
}

// MARK: - Differential Oracle Test Harness

/// 双向 3 维度预言机比对测试执行引擎 (TTZip 压缩 ➔ 预言机解压；预言机压缩 ➔ TTZip 解压)
public enum DifferentialOracleTestHarness: Sendable {
    
    /// 执行 3 维度双向差分往返验证
    ///
    /// - Parameters:
    ///   - format: 待验证归档格式
    ///   - sourceDir: 测试原始源文件目录
    ///   - oracle: 目标预言机名称或路径 (如 "/usr/bin/tar", "bsdtar", "/usr/bin/unzip", "7zz")
    ///   - tempSandbox: 隔离测试临时沙盒目录路径
    /// - Returns: 包含 5 维度对比结果与 HexDiff 的完整差分报告
    public static func executeRoundtrip(
        format: ArchiveCompressionFormat,
        sourceDir: String,
        oracle: String,
        tempSandbox: String
    ) async throws -> DifferentialTestReport {
        let registry = DifferentialOracleRegistry.shared
        guard let resolvedOraclePath = registry.oraclePath(for: oracle) else {
            throw ArchiveError.fileNotFound
        }
        
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourceDir).standardized
        let sandboxURL = URL(fileURLWithPath: tempSandbox).standardized
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ArchiveError.fileNotFound
        }
        try fm.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        
        // 1. 基线扫描
        let baselineManifest = try DifferentialManifestScanner.scanDirectory(atPath: sourceURL.path)
        let childItems = try fm.contentsOfDirectory(atPath: sourceURL.path).sorted()
        guard !childItems.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        let fullInputPaths = childItems.map { sourceURL.appendingPathComponent($0).path }
        
        var divergenceErrors: [String] = []
        var capturedHexDiff: String? = nil
        
        // 2. Pass 1: TTZip 压缩 ➔ 预言机解压
        let ttzipArchiveURL = sandboxURL.appendingPathComponent("ttzip_out_\(UUID().uuidString)\(format.fileExtension)")
        let oracleExtractURL = sandboxURL.appendingPathComponent("oracle_extracted_\(UUID().uuidString)")
        try fm.createDirectory(at: oracleExtractURL, withIntermediateDirectories: true)
        
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: ttzipArchiveURL.path,
            format: format,
            level: .normal,
            inputPaths: fullInputPaths
        )
        guard fm.fileExists(atPath: ttzipArchiveURL.path) else {
            throw ArchiveError.readFailed(code: -1)
        }
        
        try await extractWithOracle(
            oraclePath: resolvedOraclePath,
            format: format,
            archivePath: ttzipArchiveURL.path,
            destinationDir: oracleExtractURL.path
        )
        
        let oracleExtractedManifest = try DifferentialManifestScanner.scanDirectory(atPath: oracleExtractURL.path)
        let pass1Report = DifferentialManifestVerifier.compare(
            ttzip: oracleExtractedManifest,
            oracle: baselineManifest,
            format: format,
            oracleName: "\(oracle) (TTZip->Oracle)"
        )
        divergenceErrors.append(contentsOf: pass1Report.divergenceErrors)
        if capturedHexDiff == nil {
            capturedHexDiff = pass1Report.hexDiffOutput
        }
        
        // 3. Pass 2: 预言机压缩 ➔ TTZip 解压 (如果预言机具备对应格式压缩能力)
        var ttzipExtractedManifest: FileTreeManifest? = nil
        if canOracleCompress(oracle: resolvedOraclePath, format: format) {
            let oracleArchiveURL = sandboxURL.appendingPathComponent("oracle_out_\(UUID().uuidString)\(format.fileExtension)")
            let ttzipExtractURL = sandboxURL.appendingPathComponent("ttzip_extracted_\(UUID().uuidString)")
            try fm.createDirectory(at: ttzipExtractURL, withIntermediateDirectories: true)
            
            try await compressWithOracle(
                oraclePath: resolvedOraclePath,
                format: format,
                sourceDir: sourceURL.path,
                inputItems: childItems,
                outputPath: oracleArchiveURL.path
            )
            
            if fm.fileExists(atPath: oracleArchiveURL.path) {
                let extractor = ArchiveExtractor()
                try await extractor.extract(
                    archivePath: oracleArchiveURL.path,
                    destinationDir: ttzipExtractURL.path,
                    options: ArchiveFilterOptions(skipMacJunk: false)
                )
                
                let ttzipManifest = try DifferentialManifestScanner.scanDirectory(atPath: ttzipExtractURL.path)
                ttzipExtractedManifest = ttzipManifest
                
                let pass2Report = DifferentialManifestVerifier.compare(
                    ttzip: ttzipManifest,
                    oracle: baselineManifest,
                    format: format,
                    oracleName: "\(oracle) (Oracle->TTZip)"
                )
                divergenceErrors.append(contentsOf: pass2Report.divergenceErrors)
                if capturedHexDiff == nil {
                    capturedHexDiff = pass2Report.hexDiffOutput
                }
                
                // 3-way 交叉比对: TTZip 解压产物 vs 预言机解压产物
                let crossReport = DifferentialManifestVerifier.compare(
                    ttzip: ttzipManifest,
                    oracle: oracleExtractedManifest,
                    format: format,
                    oracleName: oracle
                )
                divergenceErrors.append(contentsOf: crossReport.divergenceErrors)
                if capturedHexDiff == nil {
                    capturedHexDiff = crossReport.hexDiffOutput
                }
            }
        }
        
        // 去重错误分歧记录
        var seenErrors = Set<String>()
        var uniqueErrors: [String] = []
        for err in divergenceErrors {
            if !seenErrors.contains(err) {
                seenErrors.insert(err)
                uniqueErrors.append(err)
            }
        }
        
        let isPassed = uniqueErrors.isEmpty
        return DifferentialTestReport(
            format: format,
            targetOracle: oracle,
            isPassed: isPassed,
            ttzipManifest: ttzipExtractedManifest ?? oracleExtractedManifest,
            oracleManifest: oracleExtractedManifest,
            divergenceErrors: uniqueErrors,
            hexDiffOutput: capturedHexDiff
        )
    }
    
    // MARK: - Oracle Subprocess Execution Helpers
    
    /// 判定目标预言机工具是否支持指定格式的压缩打包
    public static func canOracleCompress(oracle: String, format: ArchiveCompressionFormat) -> Bool {
        let name = (oracle as NSString).lastPathComponent.lowercased()
        if name.contains("tar") {
            return format == .tar || format == .gz || format == .tarGz || format == .bz2 || format == .tarBz2 || format == .xz || format == .tarXz || format == .zst || format == .tarZst
        }
        if name.contains("unzip") {
            return DifferentialOracleRegistry.shared.oraclePath(for: "zip") != nil && format == .zip
        }
        if name.contains("zip") {
            return format == .zip
        }
        if name.contains("7z") {
            return format == .sevenZip || format == .zip || format == .tar
        }
        if name == "zstd" {
            return format == .zst || format == .tarZst
        }
        if name == "gzip" {
            return format == .gz || format == .tarGz
        }
        if name == "xz" {
            return format == .xz || format == .tarXz
        }
        return false
    }
    
    /// 使用预言机解压归档文件
    public static func extractWithOracle(
        oraclePath: String,
        format: ArchiveCompressionFormat,
        archivePath: String,
        destinationDir: String
    ) async throws {
        let name = (oraclePath as NSString).lastPathComponent.lowercased()
        let args: [String]
        
        if name.contains("unzip") {
            args = ["-q", "-o", archivePath, "-d", destinationDir]
        } else if name.contains("tar") {
            args = ["-xf", archivePath, "-C", destinationDir]
        } else if name.contains("7z") {
            args = ["x", "-y", "-o\(destinationDir)", archivePath]
        } else {
            args = ["-xf", archivePath, "-C", destinationDir]
        }
        
        let result = try await SubprocessExecutor.shared.executeAsync(
            executablePath: oraclePath,
            arguments: args,
            currentDirectory: destinationDir
        )
        guard result.exitCode == 0 else {
            throw ArchiveError.readFailed(code: result.exitCode)
        }
    }
    
    /// 使用预言机压缩打包测试目录
    public static func compressWithOracle(
        oraclePath: String,
        format: ArchiveCompressionFormat,
        sourceDir: String,
        inputItems: [String],
        outputPath: String
    ) async throws {
        let name = (oraclePath as NSString).lastPathComponent.lowercased()
        var execPath = oraclePath
        let args: [String]
        
        if name.contains("tar") {
            var flag = "-cf"
            switch format {
            case .gz, .tarGz: flag = "-czf"
            case .bz2, .tarBz2: flag = "-cjf"
            case .xz, .tarXz: flag = "-cJf"
            default: flag = "-cf"
            }
            args = [flag, outputPath, "-C", sourceDir] + inputItems
        } else if name.contains("unzip") {
            guard let zipPath = DifferentialOracleRegistry.shared.oraclePath(for: "zip") else {
                throw ArchiveError.invalidFormat
            }
            execPath = zipPath
            args = ["-q", "-r", "-y", outputPath] + inputItems
        } else if name.contains("zip") {
            args = ["-q", "-r", "-y", outputPath] + inputItems
        } else if name.contains("7z") {
            args = ["a", "-y", outputPath] + inputItems
        } else {
            throw ArchiveError.invalidFormat
        }
        
        let result = try await SubprocessExecutor.shared.executeAsync(
            executablePath: execPath,
            arguments: args,
            currentDirectory: sourceDir
        )
        guard result.exitCode == 0 else {
            throw ArchiveError.readFailed(code: result.exitCode)
        }
    }
}

