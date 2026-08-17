import Foundation
import CTTZipBridge

/// Apple Silicon M 系列芯片专属性能与硬件自动调优引擎
public final class AppleSiliconTuner: @unchecked Sendable {
    public static let shared = AppleSiliconTuner()
    
    public struct ChipTopology: Sendable {
        public let chipName: String
        public let totalCores: Int
        public let performanceCores: Int
        public let efficiencyCores: Int
        public let unifiedMemoryBytes: UInt64
        public let pageSizeBytes: Int
        
        public var unifiedMemoryGB: Double {
            return Double(unifiedMemoryBytes) / (1024.0 * 1024.0 * 1024.0)
        }
    }
    
    /// 自动智能匹配的芯片最佳参数推荐配置
    public struct AutoTunedConfig: Sendable {
        public let recommendedDictionarySizeMB: Int
        public let recommendedChunkSizeBytes: Int
        public let recommendedBufferSize: Int
        public let isHighMemoryProfile: Bool
        public let profileSummary: String
    }
    
    public let topology: ChipTopology
    public let autoTunedConfig: AutoTunedConfig
    
    private init() {
        var chipName = "Standard Processor"
        var totalVal = PlatformHardware.capabilities.logicalCores
        var perfVal = totalVal
        var effVal = 0
        var realMem: UInt64 = 8 * 1024 * 1024 * 1024
        var pageVal = PlatformOperatingSystem.current.defaultPageAlignment
        
        #if os(macOS)
        var size = 0
        chipName = "Apple Silicon"
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
            let brandStr = brand.withUnsafeBufferPointer { ptr -> String in
                guard let base = ptr.baseAddress else { return "" }
                return String(cString: base).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !brandStr.isEmpty {
                chipName = brandStr
            }
        }
        
        // 如果 machdep.cpu.brand_string 未返回具体代数，获取 hw.model 备用
        if chipName == "Apple Silicon" || chipName.contains("Apple processor") {
            sysctlbyname("hw.model", nil, &size, nil, 0)
            if size > 0 {
                var model = [CChar](repeating: 0, count: size)
                sysctlbyname("hw.model", &model, &size, nil, 0)
                let modelStr = model.withUnsafeBufferPointer { ptr -> String in
                    guard let base = ptr.baseAddress else { return "" }
                    return String(cString: base).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !modelStr.isEmpty {
                    chipName = "Apple Silicon (\(modelStr))"
                }
            }
        }
        
        // 2. 核心数与架构查询
        var ncpu: Int32 = 0
        var intSize = MemoryLayout<Int32>.size
        sysctlbyname("hw.ncpu", &ncpu, &intSize, nil, 0)
        
        var pCores: Int32 = 0
        sysctlbyname("hw.perflevel0.physicalcpu", &pCores, &intSize, nil, 0)
        
        var eCores: Int32 = 0
        sysctlbyname("hw.perflevel1.physicalcpu", &eCores, &intSize, nil, 0)
        
        var memSize: UInt64 = 0
        var memSizeLen = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)
        
        var pageSize: Int32 = 0
        sysctlbyname("hw.pagesize", &pageSize, &intSize, nil, 0)
        
        totalVal = ncpu > 0 ? Int(ncpu) : PlatformHardware.capabilities.logicalCores
        perfVal = pCores > 0 ? Int(pCores) : (totalVal > 4 ? totalVal - 2 : totalVal)
        effVal = eCores > 0 ? Int(eCores) : Swift.max(1, totalVal - perfVal)
        pageVal = pageSize > 0 ? Int(pageSize) : PlatformOperatingSystem.current.defaultPageAlignment
        realMem = memSize > 0 ? memSize : 8 * 1024 * 1024 * 1024
        #endif


        
        self.topology = ChipTopology(
            chipName: chipName,
            totalCores: totalVal,
            performanceCores: perfVal,
            efficiencyCores: effVal,
            unifiedMemoryBytes: realMem,
            pageSizeBytes: pageVal
        )
        
        // 3. 根据统一内存容量与核心数，智能计算最佳硬件推演配置
        let memGB = Double(realMem) / (1024.0 * 1024.0 * 1024.0)
        
        let dictSize: Int
        let chunkSize: Int
        let bufSize: Int
        let isHighMem: Bool
        let summary: String
        
        if memGB >= 96.0 {
            // M Max / Ultra 128GB 物理极限配置 (128GB Unified Memory)
            dictSize = 4096 // 4GB (4096MB) 物理极限算法字典
            chunkSize = 512 * 1024 * 1024 // 512MB 固实块切分
            bufSize = 64 * 1024 * 1024    // 64MB 页对齐 I/O 缓存
            isHighMem = true
            summary = "👑 物理极限 128GB Unified Memory 模式: 4096MB (4GB) 极限算法字典 + 64MB 页面缓存 (适用 \(chipName))"
        } else if memGB >= 48.0 {
            // M Max 64GB 旗舰配置
            dictSize = 2048 // 2GB (2048MB) 巨型算法字典
            chunkSize = 256 * 1024 * 1024 // 256MB
            bufSize = 32 * 1024 * 1024    // 32MB 物理页对齐缓存
            isHighMem = true
            summary = "🚀 旗舰 64GB 模式: 2048MB (2GB) 算法字典 + 32MB 物理页对齐缓存 (适用 \(chipName))"
        } else if memGB >= 24.0 {
            // M Pro 进阶配置 (32GB / 36GB Unified Memory)
            dictSize = 1024 // 1GB (1024MB)
            chunkSize = 128 * 1024 * 1024 // 128MB
            bufSize = 16 * 1024 * 1024    // 16MB
            isHighMem = true
            summary = "进阶 32GB 模式: 1024MB (1GB) 算法字典 + 16MB 物理页对齐缓存 (适用 \(chipName))"
        } else {
            // M 基础款配置 (8GB / 16GB / 24GB Unified Memory)
            dictSize = 64
            chunkSize = 16 * 1024 * 1024 // 16MB
            bufSize = 4 * 1024 * 1024    // 4MB
            isHighMem = false
            summary = "轻量极速模式: 预置 64MB 算法字典 + 4MB 物理页缓存 (适用 \(chipName))"
        }
        
        self.autoTunedConfig = AutoTunedConfig(
            recommendedDictionarySizeMB: dictSize,
            recommendedChunkSizeBytes: chunkSize,
            recommendedBufferSize: bufSize,
            isHighMemoryProfile: isHighMem,
            profileSummary: summary
        )
    }
    
    /// 针对轻量算法 / 低发热持续吞吐的最佳 P-Core / Super-Core 核心数 (避免异构核调度墙)
    public var optimalEfficiencyThreads: Int {
        return topology.performanceCores > 0 ? topology.performanceCores : min(8, topology.totalCores)
    }
    
    /// 针对计算密集型 (xz -9 / zstd -19) 打满全核的最大线程数
    public var optimalBurstThreads: Int {
        return topology.totalCores
    }
    
    /// 针对并行压缩任务默认最佳线程数（100% 打满全部 CPU 核心）
    public var optimalCompressionThreads: Int {
        return topology.totalCores
    }
    
    /// 128GB 内存场景下的 Zstd 长距离匹配 (Long Distance Matching) windowLog 参数 (最高 31)
    public var optimalZstdLongWindowLog: Int {
        return topology.unifiedMemoryGB >= 48.0 ? 31 : (topology.unifiedMemoryGB >= 24.0 ? 27 : 0)
    }
    
    /// 16KB 物理页面对齐的最佳 I/O 缓冲区尺寸
    public var optimalAlignedBufferSize: Int {
        return autoTunedConfig.recommendedBufferSize
    }
    
    /// 硬件架构与智能调优摘要描述
    public var hardwareSummary: String {
        return "\(topology.chipName) (\(topology.totalCores) Cores: \(topology.performanceCores) P-Cores + \(topology.efficiencyCores) E-Cores), \(String(format: "%.1f", topology.unifiedMemoryGB)) GB Unified Memory, \(topology.pageSizeBytes / 1024)KB Page Aligned"
    }
    
    /// APFS 零拷贝硬件级超高速克隆文件 (clonefile)
    @discardableResult
    public func apfsZeroCopyClone(from srcPath: String, to destPath: String) -> Bool {
        try? FileManager.default.removeItem(atPath: destPath)
        return clonefile(srcPath, destPath, 0) == 0
    }
    
    /// 将当前底层 Task/Thread 的调度 QoS 提升至最高物理优先级 (QOS_CLASS_USER_INTERACTIVE)
    public func boostCurrentThreadPriority() {
        let dict = Thread.current.threadDictionary
        if dict["_tt_boosted"] == nil {
            dict["_tt_boosted"] = true
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        }
    }
}
