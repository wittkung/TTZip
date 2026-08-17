import Foundation
import CryptoKit
import CTTZipBridge

// MARK: - 1. Data Models

public struct MicroCorpusProfile: Sendable, Codable {
    public var profileId: String
    public var fileCount: Int
    public var minFileSizeBytes: Int
    public var maxFileSizeBytes: Int
    public var jsonRatio: Double
    public var logRatio: Double
    public var highEntropyRatio: Double
    public var maxDirectoryDepth: Int
    public var directoryFanout: Int
    public var seed: UInt64
    
    public init(
        profileId: String = "ci-fast-gate",
        fileCount: Int = 500,
        minFileSizeBytes: Int = 1024,
        maxFileSizeBytes: Int = 65536,
        jsonRatio: Double = 0.40,
        logRatio: Double = 0.40,
        highEntropyRatio: Double = 0.20,
        maxDirectoryDepth: Int = 4,
        directoryFanout: Int = 10,
        seed: UInt64 = 0x4879706572436F6D
    ) {
        self.profileId = profileId
        self.fileCount = fileCount
        self.minFileSizeBytes = minFileSizeBytes
        self.maxFileSizeBytes = maxFileSizeBytes
        self.jsonRatio = jsonRatio
        self.logRatio = logRatio
        self.highEntropyRatio = highEntropyRatio
        self.maxDirectoryDepth = maxDirectoryDepth
        self.directoryFanout = directoryFanout
        self.seed = seed
    }
    
    public static let standardCiGate = MicroCorpusProfile(
        profileId: "ci-fast-gate",
        fileCount: 500,
        minFileSizeBytes: 1024,
        maxFileSizeBytes: 32768,
        jsonRatio: 0.40,
        logRatio: 0.40,
        highEntropyRatio: 0.20,
        maxDirectoryDepth: 3,
        directoryFanout: 8
    )
    
    public static let stress50k = MicroCorpusProfile(
        profileId: "stress-50k",
        fileCount: 50000,
        minFileSizeBytes: 512,
        maxFileSizeBytes: 65536,
        jsonRatio: 0.40,
        logRatio: 0.40,
        highEntropyRatio: 0.20,
        maxDirectoryDepth: 5,
        directoryFanout: 16
    )
}

public struct SyntheticFileItem: Sendable {
    public let relativePath: String
    public let category: String
    public let byteLength: Int
    public let crc32: UInt32
    public let sha256Hex: String
    public let isHighEntropy: Bool
    public let data: Data
    
    public init(
        relativePath: String,
        category: String,
        data: Data,
        isHighEntropy: Bool
    ) {
        self.relativePath = relativePath
        self.category = category
        self.data = data
        self.byteLength = data.count
        self.isHighEntropy = isHighEntropy
        
        // 计算 CRC32
        var crc: UInt32 = 0
        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                crc = ttzip_compute_buffer_crc32(baseAddress, rawBuffer.count)
            }
        }
        self.crc32 = crc
        
        // 计算 SHA-256
        let digest = SHA256.hash(data: data)
        self.sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct DirectoryScanMetric: Sendable, Codable {
    public let totalNodesScanned: Int
    public let directoryCount: Int
    public let fileCount: Int
    public let scanDurationSeconds: Double
    public let nodesPerSecond: Double
    public let peakOpenFDCount: Int
}

public struct HyperCompressBatchResult: Sendable, Codable {
    public let archiveFormat: String
    public let compressionLevel: String
    public let totalFiles: Int
    public let totalUncompressedBytes: Int
    public let compressedBytes: Int
    public let compressionRatio: Double
    public let compressionDurationSeconds: Double
    public let compressionThroughputMBs: Double
    public let extractionDurationSeconds: Double
    public let extractionThroughputMBs: Double
    public let peakResidentSetSizeMB: Double
    public let byteExactVerified: Bool
    public let passedPerformanceFloor: Bool
}

public struct HyperCompressSuiteReport: Sendable, Codable {
    public let suiteVersion: String
    public let platformOS: String
    public let hardwareArchitecture: String
    public let profile: MicroCorpusProfile
    public let scanMetric: DirectoryScanMetric
    public let batchResults: [HyperCompressBatchResult]
    public let executionTimestamp: String
    public let allGatesPassed: Bool
}

// MARK: - 2. Deterministic High-Throughput PRNG

public struct SplitMix64PRNG {
    private var state: UInt64
    
    public init(seed: UInt64) {
        self.state = seed
    }
    
    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
    
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        let rand = nextUInt64() % span
        return range.lowerBound + Int(rand)
    }
    
    public mutating func nextDouble() -> Double {
        let val = nextUInt64() &>> 11
        return Double(val) / Double(1 << 53)
    }
}

// MARK: - 3. Deterministic Micro-File Corpus Generator

public final class HyperCompressCorpusGenerator: @unchecked Sendable {
    
    private let profile: MicroCorpusProfile
    private var prng: SplitMix64PRNG
    
    // 词汇表与模板
    private static let jsonKeys = [
        "id", "user_id", "trace_id", "span_id", "timestamp", "service_name",
        "endpoint", "http_status", "latency_ms", "region", "cluster", "payload",
        "attributes", "tags", "retry_count", "is_success", "error_code", "client_ip"
    ]
    
    private static let serviceNames = [
        "auth-service", "payment-gateway", "user-profile", "cart-service",
        "order-processor", "inventory-hub", "notification-dispatcher", "api-gateway"
    ]
    
    private static let logPrefixes = [
        "[INFO] 2026-08-17T04:38:00.123Z [main] c.t.z.engine.WorkerPool: Dispatched task id=",
        "[WARN] 2026-08-17T04:38:00.234Z [worker-1] c.t.z.vfs.DirectoryScanner: High fanout detected at depth=",
        "[DEBUG] 2026-08-17T04:38:00.345Z [io-thread-4] c.t.z.crypto.AesBridge: Hardware SIMD NEON vector initialized block=",
        "[ERROR] 2026-08-17T04:38:00.456Z [reactor-2] c.t.z.stream.MicroBuffer: Retry exhausted for connection peer="
    ]
    
    public init(profile: MicroCorpusProfile = .standardCiGate) {
        self.profile = profile
        self.prng = SplitMix64PRNG(seed: profile.seed)
    }
    
    /// 生成全量内存测试语料 (>= 1500 MB/s)
    public func generateInMemoryCorpus() -> [SyntheticFileItem] {
        var items = [SyntheticFileItem]()
        items.reserveCapacity(profile.fileCount)
        
        let jsonCount = Int(Double(profile.fileCount) * profile.jsonRatio)
        let logCount = Int(Double(profile.fileCount) * profile.logRatio)
        let binaryCount = profile.fileCount - jsonCount - logCount
        
        var fileIdx = 0
        
        // 1. JSON 碎片
        for _ in 0..<jsonCount {
            let path = makeHierarchicalPath(index: fileIdx, ext: "json")
            let targetSize = prng.nextInt(in: profile.minFileSizeBytes...min(profile.maxFileSizeBytes, 8192))
            let data = generateMicroJson(targetSize: targetSize, index: fileIdx)
            items.append(SyntheticFileItem(relativePath: path, category: "json", data: data, isHighEntropy: false))
            fileIdx += 1
        }
        
        // 2. 日志片段
        for _ in 0..<logCount {
            let path = makeHierarchicalPath(index: fileIdx, ext: "log")
            let targetSize = prng.nextInt(in: max(profile.minFileSizeBytes, 4096)...min(profile.maxFileSizeBytes, 32768))
            let data = generateLogSnippet(targetSize: targetSize, index: fileIdx)
            items.append(SyntheticFileItem(relativePath: path, category: "log", data: data, isHighEntropy: false))
            fileIdx += 1
        }
        
        // 3. 高熵伪随机块
        for _ in 0..<binaryCount {
            let path = makeHierarchicalPath(index: fileIdx, ext: "bin")
            let targetSize = prng.nextInt(in: max(profile.minFileSizeBytes, 8192)...profile.maxFileSizeBytes)
            let data = generateHighEntropyBinary(targetSize: targetSize)
            items.append(SyntheticFileItem(relativePath: path, category: "binary", data: data, isHighEntropy: true))
            fileIdx += 1
        }
        
        return items
    }
    
    /// 将生成语料写入临时沙盒目录 (用于真实 VFS / APFS / NTFS 目录扫描压测)
    public func writeToTemporaryDirectory() throws -> (rootURL: URL, items: [SyntheticFileItem], cleanup: () -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HyperCompressBench_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let items = generateInMemoryCorpus()
        
        for item in items {
            let fileURL = tempDir.appendingPathComponent(item.relativePath)
            let parentDir = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            try item.data.write(to: fileURL)
        }
        
        let cleanup: @Sendable () -> Void = {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        return (tempDir, items, cleanup)
    }
    
    // MARK: - Internal Generators
    
    private func makeHierarchicalPath(index: Int, ext: String) -> String {
        let fanout = max(2, profile.directoryFanout)
        let depth = max(1, profile.maxDirectoryDepth)
        
        let current = index
        var components = [String]()
        for d in 0..<depth {
            let bucket = (current / Int(pow(Double(fanout), Double(d)))) % fanout
            components.append(String(format: "dir_%02d_%02d", d, bucket))
        }
        let dirPath = components.joined(separator: "/")
        return "\(dirPath)/micro_\(String(format: "%06d", index)).\(ext)"
    }
    
    private func generateMicroJson(targetSize: Int, index: Int) -> Data {
        var buffer = [UInt8]()
        buffer.reserveCapacity(targetSize + 64)
        
        let header = "{\n  \"schema\": \"hypercompress.v1\",\n  \"item_index\": \(index),\n  \"service\": \"\(Self.serviceNames[index % Self.serviceNames.count])\",\n  \"records\": [\n"
        buffer.append(contentsOf: header.utf8)
        
        var recordIdx = 0
        while buffer.count < targetSize - 32 {
            let record = """
                {"id": \(recordIdx), "uid": "\(index)_\(recordIdx)", "status": 200, "lat": 1.42, "tag": "prod_datacenter_us_east"},
            """
            buffer.append(contentsOf: record.utf8)
            recordIdx += 1
        }
        
        let footer = "\n  ],\n  \"eof\": true\n}\n"
        buffer.append(contentsOf: footer.utf8)
        return Data(buffer)
    }
    
    private func generateLogSnippet(targetSize: Int, index: Int) -> Data {
        var buffer = [UInt8]()
        buffer.reserveCapacity(targetSize + 128)
        
        var line = 0
        while buffer.count < targetSize {
            let prefix = Self.logPrefixes[line % Self.logPrefixes.count]
            let logLine = "\(prefix)\(index)_\(line) latency=\(Double(line) * 0.12)ms thread=\(line % 16)\n"
            buffer.append(contentsOf: logLine.utf8)
            line += 1
        }
        
        return Data(buffer)
    }
    
    private func generateHighEntropyBinary(targetSize: Int) -> Data {
        var prngCopy = prng
        var buffer = [UInt8](repeating: 0, count: targetSize)
        buffer.withUnsafeMutableBytes { rawBuf in
            let ptr = rawBuf.bindMemory(to: UInt64.self)
            let u64Count = targetSize / 8
            for i in 0..<u64Count {
                ptr[i] = prngCopy.nextUInt64()
            }
        }
        return Data(buffer)
    }
}
