import Foundation

/// 统一的异步性能基准度量统计指标
public struct BenchmarkMetrics: Sendable {
    public let name: String
    public let payloadBytes: Int64
    public let iterations: Int
    public let minSeconds: Double
    public let maxSeconds: Double
    public let medianSeconds: Double
    public let meanSeconds: Double
    public let stdDevSeconds: Double
    public let throughputMBs: Double
    
    public var payloadMB: Double {
        return Double(payloadBytes) / (1024.0 * 1024.0)
    }
}

/// 专为 Swift Concurrency 编写的异步基准测试执行器
public enum AsyncBenchmarkRunner {
    
    /// 执行异步基准测试并计算统计学数据
    public static func measure(
        name: String,
        payloadBytes: Int64,
        iterations: Int = 3,
        warmupIterations: Int = 1,
        setUp: @escaping (IsolatedTempSandbox) async throws -> Void = { _ in },
        tearDown: @escaping (IsolatedTempSandbox) async throws -> Void = { _ in },
        block: @escaping (IsolatedTempSandbox) async throws -> Void
    ) async throws -> BenchmarkMetrics {
        
        // 1. 预热运行 (Warm-up)
        for i in 0..<warmupIterations {
            let warmupSandbox = try IsolatedTempSandbox(prefix: "warmup_\(i)")
            try await setUp(warmupSandbox)
            try await block(warmupSandbox)
            try await tearDown(warmupSandbox)
            warmupSandbox.cleanup()
        }
        
        // 2. 正式采样运行
        var durations: [Double] = []
        durations.reserveCapacity(iterations)
        var lastCompressedBytes: Int64 = 0
        
        let clock = ContinuousClock()
        
        for i in 0..<iterations {
            let sandbox = try IsolatedTempSandbox(prefix: "iter_\(i)")
            try await setUp(sandbox)
            
            let elapsed = try await clock.measure {
                try await block(sandbox)
            }
            
            let seconds = Double(elapsed.components.seconds) + (Double(elapsed.components.attoseconds) / 1e18)
            durations.append(max(0.0001, seconds))
            
            if let contents = try? FileManager.default.contentsOfDirectory(at: sandbox.url, includingPropertiesForKeys: [URLResourceKey.fileSizeKey]) {
                for file in contents {
                    let ext = file.pathExtension.lowercased()
                    let name = file.lastPathComponent.lowercased()
                    if ["zip", "7z", "zst", "tar", "gz", "bz2", "xz"].contains(ext) || name.contains(".tar.") || name.hasPrefix("measure_") {
                        if let res = try? file.resourceValues(forKeys: [URLResourceKey.fileSizeKey]), let size = res.fileSize {
                            lastCompressedBytes = max(lastCompressedBytes, Int64(size))
                        }
                    }
                }
            }
            
            try await tearDown(sandbox)
            sandbox.cleanup()
        }
        
        // 3. 计算统计指标
        durations.sort()
        let minSeconds = durations.first!
        let maxSeconds = durations.last!
        
        let count = Double(durations.count)
        let meanSeconds = durations.reduce(0.0, +) / count
        
        let medianSeconds: Double
        if durations.count % 2 == 0 {
            let mid = durations.count / 2
            medianSeconds = (durations[mid - 1] + durations[mid]) / 2.0
        } else {
            medianSeconds = durations[durations.count / 2]
        }
        
        let variance = durations.reduce(0.0) { $0 + pow($1 - meanSeconds, 2) } / count
        let stdDevSeconds = sqrt(variance)
        
        let payloadMB = Double(payloadBytes) / (1024.0 * 1024.0)
        let throughputMBs = payloadMB / minSeconds
        let compressedMB = Double(lastCompressedBytes) / (1024.0 * 1024.0)
        
        let metrics = BenchmarkMetrics(
            name: name,
            payloadBytes: payloadBytes,
            iterations: iterations,
            minSeconds: minSeconds,
            maxSeconds: maxSeconds,
            medianSeconds: medianSeconds,
            meanSeconds: meanSeconds,
            stdDevSeconds: stdDevSeconds,
            throughputMBs: throughputMBs
        )
        
        let isDecomp = name.lowercased().contains("decomp")
        TTZipTestLogger.logMetricsRow(
            format: name,
            payloadMB: payloadMB,
            compressedMB: compressedMB,
            compressSpeedMBs: isDecomp ? 0 : throughputMBs,
            decompressSpeedMBs: isDecomp ? throughputMBs : 0,
            elapsedSeconds: medianSeconds
        )
        
        return metrics
    }
}
