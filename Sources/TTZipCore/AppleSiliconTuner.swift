// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Hardware profiling and dynamic tuning engine for Apple Silicon SoC architectures.
public final class AppleSiliconTuner: @unchecked Sendable {
    public static let shared = AppleSiliconTuner()
    
    /// Physical chip topology metadata.
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
    
    /// Auto-tuned recommended operational configuration profile.
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
        
        // Fallback to hw.model if machdep.cpu.brand_string is generic
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
        
        // Query cores and architecture via sysctl
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
        
        // Auto-calculate optimal configuration based on unified memory capacity
        let memGB = Double(realMem) / (1024.0 * 1024.0 * 1024.0)
        
        let dictSize: Int
        let chunkSize: Int
        let bufSize: Int
        let isHighMem: Bool
        let summary: String
        
        if memGB >= 96.0 {
            // M Max / Ultra 128GB profile
            dictSize = 4096 // 4GB dictionary
            chunkSize = 512 * 1024 * 1024 // 512MB solid chunk
            bufSize = 64 * 1024 * 1024    // 64MB page-aligned I/O buffer
            isHighMem = true
            summary = "128GB Unified Memory: 4096MB dictionary + 64MB page buffer (\(chipName))"
        } else if memGB >= 48.0 {
            // M Max 64GB profile
            dictSize = 2048 // 2GB dictionary
            chunkSize = 256 * 1024 * 1024 // 256MB solid chunk
            bufSize = 32 * 1024 * 1024    // 32MB page-aligned buffer
            isHighMem = true
            summary = "64GB Unified Memory: 2048MB dictionary + 32MB page buffer (\(chipName))"
        } else if memGB >= 24.0 {
            // M Pro 32GB/36GB profile
            dictSize = 1024 // 1GB dictionary
            chunkSize = 128 * 1024 * 1024 // 128MB solid chunk
            bufSize = 16 * 1024 * 1024    // 16MB page buffer
            isHighMem = true
            summary = "32GB Unified Memory: 1024MB dictionary + 16MB page buffer (\(chipName))"
        } else {
            // Base profile (8GB / 16GB)
            dictSize = 64
            chunkSize = 16 * 1024 * 1024 // 16MB chunk
            bufSize = 4 * 1024 * 1024    // 4MB buffer
            isHighMem = false
            summary = "Standard Memory: 64MB dictionary + 4MB page buffer (\(chipName))"
        }
        
        self.autoTunedConfig = AutoTunedConfig(
            recommendedDictionarySizeMB: dictSize,
            recommendedChunkSizeBytes: chunkSize,
            recommendedBufferSize: bufSize,
            isHighMemoryProfile: isHighMem,
            profileSummary: summary
        )
    }
    
    /// Optimal thread count for performance cores.
    public var optimalEfficiencyThreads: Int {
        return topology.performanceCores > 0 ? topology.performanceCores : min(8, topology.totalCores)
    }
    
    /// Maximum thread count for burst compute tasks.
    public var optimalBurstThreads: Int {
        return topology.totalCores
    }
    
    /// Default optimal thread count for parallel compression pipelines.
    public var optimalCompressionThreads: Int {
        return topology.totalCores
    }
    
    /// Optimal Zstandard Long Distance Matching windowLog parameter (up to 31).
    public var optimalZstdLongWindowLog: Int {
        return topology.unifiedMemoryGB >= 48.0 ? 31 : (topology.unifiedMemoryGB >= 24.0 ? 27 : 0)
    }
    
    /// Optimal page-aligned I/O buffer size.
    public var optimalAlignedBufferSize: Int {
        return autoTunedConfig.recommendedBufferSize
    }
    
    /// Formatted hardware and topology summary.
    public var hardwareSummary: String {
        return "\(topology.chipName) (\(topology.totalCores) Cores: \(topology.performanceCores) P-Cores + \(topology.efficiencyCores) E-Cores), \(String(format: "%.1f", topology.unifiedMemoryGB)) GB Unified Memory, \(topology.pageSizeBytes / 1024)KB Page Aligned"
    }
    
    /// APFS zero-copy kernel clone file.
    @discardableResult
    public func apfsZeroCopyClone(from srcPath: String, to destPath: String) -> Bool {
        try? FileManager.default.removeItem(atPath: destPath)
        return clonefile(srcPath, destPath, 0) == 0
    }
    
    /// Elevates current thread QoS priority to `QOS_CLASS_USER_INTERACTIVE`.
    public func boostCurrentThreadPriority() {
        let dict = Thread.current.threadDictionary
        if dict["_tt_boosted"] == nil {
            dict["_tt_boosted"] = true
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        }
    }
}
