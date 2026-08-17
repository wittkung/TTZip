import XCTest
@testable import TTZipCore

final class PerformanceRegressionGuardTests: XCTestCase {
    
    /// 动态场景性能基准描述符 (格式, 等级, 是否加密)
    struct ScenarioBaselineKey: Hashable {
        let format: ArchiveCompressionFormat
        let level: ArchiveCompressionLevel
        let isEncrypted: Bool
    }
    
    // 覆盖的主要测试场景集合
    static let testScenarios: [ScenarioBaselineKey] = [
        ScenarioBaselineKey(format: .zip, level: .level1, isEncrypted: false),
        ScenarioBaselineKey(format: .sevenZip, level: .level1, isEncrypted: false),
        ScenarioBaselineKey(format: .sevenZip, level: .level1, isEncrypted: true),
        ScenarioBaselineKey(format: .tar, level: .store, isEncrypted: false),
        ScenarioBaselineKey(format: .tarZst, level: .level1, isEncrypted: false),
        ScenarioBaselineKey(format: .tarGz, level: .level1, isEncrypted: false),
        ScenarioBaselineKey(format: .bz2, level: .level1, isEncrypted: false)
    ]
    
    // 本机历史峰值的止跌熔断下限 (Debug 模式 80% 适应无优化开销 / Release 模式严格 90%)
    #if DEBUG
    static let floorRatio: Double = 0.80
    #else
    static let floorRatio: Double = 0.90
    #endif
    
    func testTopFormatsDynamicScenarioPerformanceFloor() async throws {
        let sandbox = try IsolatedTempSandbox(prefix: "perf_guard")
        defer { sandbox.cleanup() }
        
        let sampleFile = sandbox.fileURL(named: "payload_50mb.bin")
        let dataSize = 50 * 1024 * 1024
        var sampleData = Data(count: dataSize)
        sampleData.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<dataSize {
                base[i] = UInt8(i % 251)
            }
        }
        try sampleData.write(to: sampleFile)
        
        let writer = ArchiveWriter()
        let calibrator = HardwareCalibrator.shared
        
        for key in Self.testScenarios {
            let encSuffix = key.isEncrypted ? "_enc" : ""
            let ext: String
            switch key.format {
            case .sevenZip: ext = "7z"
            case .zip: ext = "zip"
            case .tar: ext = "tar"
            case .tarZst, .zst: ext = "tar.zst"
            case .tarGz, .gz: ext = "tar.gz"
            case .bz2, .tarBz2: ext = "tar.bz2"
            default: ext = key.format.rawValue
            }
            
            let outPath = sandbox.fileURL(named: "test_\(ext)_L\(key.level.rawValue)\(encSuffix).\(ext)").path
            let pwd = key.isEncrypted ? "P@ssw0rd2026!" : nil
            
            let clock = ContinuousClock()
            let elapsed = try await clock.measure {
                try await writer.createArchive(
                    outputPath: outPath,
                    format: key.format,
                    level: key.level,
                    inputPaths: [sampleFile.path],
                    password: pwd
                )
            }
            
            let seconds = max(0.001, Double(elapsed.components.seconds) + (Double(elapsed.components.attoseconds) / 1e18))
            let currentMBs = (Double(dataSize) / (1024.0 * 1024.0)) / seconds
            
            if let localPeak = calibrator.localPeakThroughput(format: key.format, level: key.level, isEncrypted: key.isEncrypted) {
                // 已有本机历史极值，比对当前表现是否达到本机历史极值的 80%
                let minAllowedMBs = localPeak * Self.floorRatio
                
                XCTAssertGreaterThanOrEqual(
                    currentMBs,
                    minAllowedMBs,
                    "🚨 [性能倒退警告] 场景 [\(key.format.rawValue.uppercased()) | Level: \(key.level.rawValue) | 加密: \(key.isEncrypted)] 当前吞吐 (\(String(format: "%.1f", currentMBs)) MB/s) 低于本机历史最高纪录 (\(String(format: "%.1f", localPeak)) MB/s) 的 80% 止跌阀值 (\(String(format: "%.1f", minAllowedMBs)) MB/s)！"
                )
            }
            
            // 刷新/记录本机该场景最新的极值
            calibrator.recordLocalPeak(format: key.format, level: key.level, isEncrypted: key.isEncrypted, compressMBs: currentMBs)
        }
    }
}
