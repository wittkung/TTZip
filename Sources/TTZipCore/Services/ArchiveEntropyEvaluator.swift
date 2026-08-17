import Foundation
import CTTZipBridge

/// 跨格式通用信息熵评估器 (Shannon Entropy Evaluator)
/// 可以在任意格式 (ZIP, 7z, Zstd, TAR 等) 打包/压缩前以 0.0001s 极速采样评估输入数据熵值，
/// 当数据 Shannon 熵 > 7.90 时判定为不可压缩 Payload，自动跳过字典查找直通 STORE 存储模式。
public enum ArchiveEntropyEvaluator {
    public static let defaultEntropyThreshold: Double = 7.90
    public static let minimumSampleSizeBytes: Int = 1024 * 1024 // 1MB 采样门槛

    /// 用户偏好：是否启用智能高熵数据 Store 直通旁路 (默认 true 开启)
    public static var isSmartStoreBypassEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "TTZip_SmartStoreBypassEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "TTZip_SmartStoreBypassEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TTZip_SmartStoreBypassEnabled")
        }
    }

    /// 计算指定 Buffer 的物理 Shannon 熵 (0.00 ~ 8.00)
    public static func estimateEntropy(buffer: UnsafeRawPointer, count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        return ttzip_estimate_buffer_entropy(buffer, count)
    }

    /// 基于文件大小动态阶梯多点等距跨步采样 (0% ~ 100% 覆盖) 评估 Buffer 的 Shannon 熵
    public static func estimateEntropyDynamic(buffer: UnsafeRawPointer, count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        return ttzip_estimate_buffer_entropy_dynamic(buffer, count)
    }

    /// 基于文件大小动态阶梯多点等距跨步采样评估磁盘文件的真实物理 Shannon 熵
    public static func estimateFileEntropyDynamic(filePath: String) -> Double {
        return filePath.withCString { cPath in
            return ttzip_estimate_file_entropy_dynamic(cPath)
        }
    }

    /// 评估指定内存 Buffer 是否应当直通 STORE 模式 (跳过无意义压缩)
    public static func shouldBypassCompression(buffer: UnsafeRawPointer, count: Int, threshold: Double = defaultEntropyThreshold) -> Bool {
        guard isSmartStoreBypassEnabled else { return false }
        guard count >= minimumSampleSizeBytes else { return false }
        return estimateEntropyDynamic(buffer: buffer, count: count) > threshold
    }

    /// 评估 Data 是否应当直通 STORE 模式
    public static func shouldBypassCompression(data: Data, threshold: Double = defaultEntropyThreshold) -> Bool {
        guard isSmartStoreBypassEnabled else { return false }
        guard data.count >= minimumSampleSizeBytes else { return false }
        return CUnsafeBufferAdapter.withBufferPointer(data) { ptr, count in
            return shouldBypassCompression(buffer: ptr, count: count, threshold: threshold)
        }
    }

    /// 评估指定物理文件是否应当直通 STORE 模式 (多点等距跨步采样，耗时 < 0.5ms)
    public static func shouldBypassCompression(filePath: String, threshold: Double = defaultEntropyThreshold) -> Bool {
        guard isSmartStoreBypassEnabled else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64) ?? 0
        guard size >= Int64(minimumSampleSizeBytes) else { return false }
        return estimateFileEntropyDynamic(filePath: filePath) > threshold
    }
}
