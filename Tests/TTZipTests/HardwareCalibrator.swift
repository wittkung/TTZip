import Foundation
@testable import TTZipCore

/// 专门负责记录与管理“本机物理环境”历史极值与性能基准的管理器
public final class HardwareCalibrator: @unchecked Sendable {
    public static let shared = HardwareCalibrator()
    
    private let queue = DispatchQueue(label: "com.ttzip.hardware.calibrator", attributes: .concurrent)
    private var localPeaks: [String: Double] = [:]
    
    private var cacheFileURL: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths.first?.appendingPathComponent("TTZip", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ttzip_local_machine_peaks.json")
    }
    
    private init() {
        loadFromDisk()
    }
    
    private func makeKey(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel, isEncrypted: Bool) -> String {
        return "\(format.rawValue)_\(level.rawValue)_\(isEncrypted)"
    }
    
    /// 获取本机在该格式、压缩级别、加密状态下的历史最高压缩吞吐 (MB/s)
    public func localPeakThroughput(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel, isEncrypted: Bool) -> Double? {
        return queue.sync {
            let key = makeKey(format: format, level: level, isEncrypted: isEncrypted)
            return localPeaks[key]
        }
    }
    
    /// 记录并更新本机物理峰值
    public func recordLocalPeak(format: ArchiveCompressionFormat, level: ArchiveCompressionLevel, isEncrypted: Bool, compressMBs: Double) {
        guard compressMBs > 0 && !compressMBs.isNaN && !compressMBs.isInfinite else { return }
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let key = self.makeKey(format: format, level: level, isEncrypted: isEncrypted)
            let currentPeak = self.localPeaks[key] ?? 0.0
            if compressMBs > currentPeak {
                self.localPeaks[key] = compressMBs
                self.saveToDisk()
            }
        }
        
        // 同步更新 BenchmarkSpeedCache
        BenchmarkSpeedCache.shared.record(format: format, level: level, compressMBs: compressMBs)
    }
    
    // MARK: - Disk Persistence
    
    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              var dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        // 过滤/校准历史测试残留的异常值 (如 bz2 > 80 MB/s, 7z LZMA2 L1/L6 > 2000 MB/s, tar.zst > 6000 MB/s, zip L1 > 2500 MB/s, tar > 6000 MB/s)
        for (k, v) in dict {
            let lower = k.lowercased()
            if (lower.contains("bz2") || lower.contains("tarbz2")) && v > 80.0 {
                dict.removeValue(forKey: k)
            }
            if lower.contains("7z") && !lower.contains("_0_") && v > 2000.0 {
                dict.removeValue(forKey: k)
            }
            if (lower.contains("tar.zst") || lower.contains("tarzst") || lower.contains("zst")) && v > 6000.0 {
                dict.removeValue(forKey: k)
            }
            if lower.contains("zip") && !lower.contains("_0_") && v > 2500.0 {
                dict.removeValue(forKey: k)
            }
            if lower.contains("tar") && !lower.contains("zst") && !lower.contains("gz") && !lower.contains("bz2") && !lower.contains("xz") && v > 6000.0 {
                dict.removeValue(forKey: k)
            }
        }
        self.localPeaks = dict
    }
    
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(localPeaks) else { return }
        try? data.write(to: cacheFileURL)
    }
}
