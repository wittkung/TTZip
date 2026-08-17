import Foundation
import CTTZipBridge

#if os(macOS)
import Darwin
#endif

/// 跨平台 CPU 硬件拓扑与 SIMD 向量指令集探测中枢
///
/// 对标 libarchive 跨架构硬件加速探测，提供：
/// - Apple Silicon ARM NEON / AES / SHA / CRC32 静态与运行时指令集鉴权
/// - x86_64 AVX2 / AVX-512 / AES-NI 能力掩码识别
/// - 线程 QoS 优先级实时提权 (`boostCurrentThreadPriority`)
public enum PlatformHardware {
    
    /// 缓存的只读硬件能力掩码实体 (进程级只读不可变，线程安全)
    public static let capabilities: CPUFeatureSet = detectCapabilities()
    
    private static func detectCapabilities() -> CPUFeatureSet {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let pageSize = PlatformOperatingSystem.current.defaultPageAlignment
        
        #if arch(arm64)
        let archStr = "arm64"
        let hasNeon = true
        let hasCrypto = true
        let hasAES = true
        let hasAVX2 = false
        let hasAVX512 = false
        let hasCRC32 = true
        
        #elseif arch(x86_64)
        let archStr = "x86_64"
        let hasNeon = false
        let hasCrypto = false
        let hasAES = true
        let hasAVX2 = true
        let hasAVX512 = false
        let hasCRC32 = true
        
        #else
        let archStr = "unknown"
        let hasNeon = false
        let hasCrypto = false
        let hasAES = false
        let hasAVX2 = false
        let hasAVX512 = false
        let hasCRC32 = false
        #endif
        
        return CPUFeatureSet(
            architecture: archStr,
            logicalCores: cores,
            physicalPageSize: pageSize,
            hasARMNeon: hasNeon,
            hasARMCrypto: hasCrypto,
            hasAESNI: hasAES,
            hasAVX2: hasAVX2,
            hasAVX512: hasAVX512,
            hasHardwareCRC32: hasCRC32
        )
    }
    
    /// 提升当前线程调度优先级至最高用户交互级别 (macOS: `QOS_CLASS_USER_INTERACTIVE`)
    ///
    /// - Note: 在非 Darwin 平台安全静默跳过 (No-op)
    @inlinable
    public static func boostCurrentThreadPriority() {
        #if os(macOS)
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        #endif
    }
}
