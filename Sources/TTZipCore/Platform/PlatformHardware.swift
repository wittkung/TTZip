// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

#if os(macOS)
import Darwin
#endif

/// Cross-platform CPU hardware topology and SIMD instruction set detection subsystem.
public enum PlatformHardware {
    
    /// Cached immutable CPU capability mask.
    public static let capabilities: CPUFeatureSet = detectCapabilities()
    
    private static func detectCapabilities() -> CPUFeatureSet {
        var rawCaps = TTZipCpuCapsRaw()
        let status = ttzip_rust_cpu_get_capabilities(&rawCaps)
        
        #if arch(arm64)
        let archStr = "arm64"
        #elseif arch(x86_64)
        let archStr = "x86_64"
        #else
        let archStr = "unknown"
        #endif
        
        if status == TTZIP_STATUS_OK {
            return CPUFeatureSet(
                architecture: archStr,
                logicalCores: Int(rawCaps.logical_cores),
                physicalPageSize: Int(rawCaps.physical_page_size),
                hasARMNeon: rawCaps.has_arm_neon,
                hasARMCrypto: rawCaps.has_arm_crypto,
                hasAESNI: rawCaps.has_aes_ni,
                hasAVX2: rawCaps.has_avx2,
                hasAVX512: rawCaps.has_avx512,
                hasHardwareCRC32: rawCaps.has_hardware_crc32
            )
        }
        
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let pageSize = PlatformOperatingSystem.current.defaultPageAlignment
        
        #if arch(arm64)
        return CPUFeatureSet(
            architecture: archStr,
            logicalCores: cores,
            physicalPageSize: pageSize,
            hasARMNeon: true,
            hasARMCrypto: true,
            hasAESNI: true,
            hasAVX2: false,
            hasAVX512: false,
            hasHardwareCRC32: true
        )
        #elseif arch(x86_64)
        return CPUFeatureSet(
            architecture: archStr,
            logicalCores: cores,
            physicalPageSize: pageSize,
            hasARMNeon: false,
            hasARMCrypto: false,
            hasAESNI: true,
            hasAVX2: true,
            hasAVX512: false,
            hasHardwareCRC32: true
        )
        #else
        return CPUFeatureSet(
            architecture: archStr,
            logicalCores: cores,
            physicalPageSize: pageSize,
            hasARMNeon: false,
            hasARMCrypto: false,
            hasAESNI: false,
            hasAVX2: false,
            hasAVX512: false,
            hasHardwareCRC32: false
        )
        #endif
    }
    
    /// Queries dynamic P-core, E-core, and total logical core topology.
    public static func cpuTopology() -> (pCores: Int, eCores: Int, totalCores: Int) {
        var p: UInt32 = 0
        var e: UInt32 = 0
        var tot: UInt32 = 0
        let status = ttzip_rust_cpu_get_topology(&p, &e, &tot)
        if status == TTZIP_STATUS_OK {
            return (pCores: Int(p), eCores: Int(e), totalCores: Int(tot))
        }
        let active = ProcessInfo.processInfo.activeProcessorCount
        return (pCores: active, eCores: 0, totalCores: active)
    }
    
    /// Boosts current thread scheduling QoS priority to user interactive on Darwin.
    @inlinable
    public static func boostCurrentThreadPriority() {
        #if os(macOS)
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        #endif
    }
}

// MARK: - Platform Memory

//
//


#if os(macOS)
#elseif os(Linux)
#endif

/// In-process memory telemetry snapshot (Resident Set Size, high-water mark peak RSS, and virtual size).
public struct MemoryCeilingSnapshot: Sendable, Equatable {
    public let currentRSSBytes: UInt64
    public let peakRSSBytes: UInt64
    public let virtualSizeBytes: UInt64
    public let sampledTimestampMs: Double
    
    public init(
        currentRSSBytes: UInt64,
        peakRSSBytes: UInt64,
        virtualSizeBytes: UInt64,
        sampledTimestampMs: Double = Date().timeIntervalSince1970 * 1000.0
    ) {
        self.currentRSSBytes = currentRSSBytes
        self.peakRSSBytes = peakRSSBytes
        self.virtualSizeBytes = virtualSizeBytes
        self.sampledTimestampMs = sampledTimestampMs
    }
}

/// Cross-platform aligned memory allocation, virtual memory mapping, and dead-store immune memory sanitization subsystem.
public enum PlatformMemory {
    
    /// Queries current process physical resident memory (RSS), peak RSS high-water mark, and virtual memory snapshot.
    @inlinable
    public static func currentMemoryUsage() -> MemoryCeilingSnapshot {
        var curRss: UInt64 = 0
        var peakRss: UInt64 = 0
        var vSize: UInt64 = 0
        let status = ttzip_rust_memory_usage(&curRss, &peakRss, &vSize)
        if status == TTZIP_STATUS_OK && (curRss > 0 || peakRss > 0) {
            return MemoryCeilingSnapshot(
                currentRSSBytes: curRss,
                peakRSSBytes: peakRss,
                virtualSizeBytes: vSize
            )
        }
        
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        guard kerr == KERN_SUCCESS else {
            return MemoryCeilingSnapshot(currentRSSBytes: 0, peakRSSBytes: 0, virtualSizeBytes: 0)
        }
        return MemoryCeilingSnapshot(
            currentRSSBytes: UInt64(info.resident_size),
            peakRSSBytes: UInt64(info.resident_size_max),
            virtualSizeBytes: UInt64(info.virtual_size)
        )
        #elseif os(Linux)
        var usage = rusage()
        _ = getrusage(RUSAGE_SELF, &usage)
        let peakBytes = UInt64(max(0, usage.ru_maxrss)) * 1024
        return MemoryCeilingSnapshot(currentRSSBytes: peakBytes, peakRSSBytes: peakBytes, virtualSizeBytes: 0)
        #else
        return MemoryCeilingSnapshot(currentRSSBytes: 0, peakRSSBytes: 0, virtualSizeBytes: 0)
        #endif
    }
    
    /// Allocates contiguous physical memory buffer with custom byte alignment.
    @inlinable
    public static func allocateAlignedPages(alignment: Int, byteCount: Int) -> UnsafeMutableRawPointer? {
        guard byteCount > 0, alignment > 0 else { return nil }
        return UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
    }
    
    /// Deallocates memory previously allocated by ``allocateAlignedPages``.
    @inlinable
    public static func deallocateAlignedPages(pointer: UnsafeMutableRawPointer?) {
        pointer?.deallocate()
    }
    
    /// Allocates page-aligned heap buffer conforming to default platform page alignment (16KB on Apple Silicon).
    @inlinable
    public static func allocateAlignedPageBuffer(byteCount: Int) -> UnsafeMutableRawPointer? {
        guard byteCount > 0 else { return nil }
        let alignment = PlatformOperatingSystem.current.defaultPageAlignment
        return UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
    }
    
    /// Deallocates page-aligned heap buffer previously allocated by ``allocateAlignedPageBuffer(byteCount:)``.
    @inlinable
    public static func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer?) {
        pointer?.deallocate()
    }
    
    /// Erases sensitive memory (passwords, keys, decryption state) with dead-store elimination immunity.
    @inlinable
    public static func secureZero(pointer: UnsafeMutableRawPointer, byteCount: Int) {
        guard byteCount > 0 else { return }
        ttzip_rust_secure_zeroize(pointer.assumingMemoryBound(to: UInt8.self), byteCount)
    }
    
    /// Maps physical file into virtual address space in read-only mode and returns mapping descriptor.
    public static func mapFileReadOnly(filePath: String) throws -> PlatformMmapResult {
        let fd = open(filePath, O_RDONLY)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
        }
        
        var statBuf = stat()
        guard fstat(fd, &statBuf) == 0 else {
            close(fd)
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        
        let fileSize = Int(statBuf.st_size)
        if fileSize == 0 {
            return PlatformMmapResult(pointer: UnsafeRawPointer(bitPattern: 1)!, size: 0, rawDescriptor: fd)
        }
        
        guard let mappedPtr = mmap(nil, fileSize, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0),
              mappedPtr != MAP_FAILED else {
            close(fd)
            throw POSIXError(.init(rawValue: errno) ?? .ENOMEM)
        }
        
        return PlatformMmapResult(pointer: UnsafeRawPointer(mappedPtr), size: fileSize, rawDescriptor: fd)
    }
    
    /// Maps physical file into virtual address space in read-only mode within RAII closure scope.
    public static func mapFileReadOnly<R: Sendable>(
        atPath path: String,
        _ body: @Sendable (UnsafeRawBufferPointer) throws -> R
    ) throws -> R {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
        }
        defer { close(fd) }
        
        var statBuf = stat()
        guard fstat(fd, &statBuf) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        
        let fileSize = Int(statBuf.st_size)
        if fileSize == 0 {
            return try body(UnsafeRawBufferPointer(start: nil, count: 0))
        }
        
        guard let mappedPtr = mmap(nil, fileSize, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0),
              mappedPtr != MAP_FAILED else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOMEM)
        }
        
        let ptrValue = UInt(bitPattern: mappedPtr)
        defer {
            if let rawPtr = UnsafeMutableRawPointer(bitPattern: ptrValue) {
                munmap(rawPtr, fileSize)
            }
        }
        
        let buffer = UnsafeRawBufferPointer(start: mappedPtr, count: fileSize)
        return try body(buffer)
    }
}

// MARK: - Thermal Coordinator

//
//


/// Platform hardware thermal state coordinator and DVFS debounce scheduler (Swift 6 Isolated Actor).
public actor HardwareThermalCoordinator {
    public static let shared = HardwareThermalCoordinator()
    private init() {}

    private var isMonitoring: Bool = false
    private var monitorTask: Task<Void, Never>?

    public var currentThermalState: ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }

    /// Starts background thermal state observer (non-blocking AsyncSequence stream).
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task.detached(priority: .utility) { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification,
                object: nil
            )
            for await _ in notifications {
                let state = ProcessInfo.processInfo.thermalState
                await self?.handleThermalStateChange(state)
            }
        }
    }

    /// Stops thermal state monitoring.
    public func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) {
        // Internal state synchronization hook
    }

    /// Performs adaptive hardware cooldown wait if thermal throttling pressure is high.
    /// - Parameter maxWaitSeconds: Maximum cooldown timeout limit in seconds.
    /// - Returns: Boolean indicating whether cooldown pause was triggered.
    @discardableResult
    public func performAdaptiveCooldownIfNeeded(maxWaitSeconds: Double = 30.0) async -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        guard state == .serious || state == .critical else {
            return false
        }

        let startNanos = PlatformMonotonicTimer.nowNanoseconds()
        let maxWaitNanos = UInt64(maxWaitSeconds * 1_000_000_000)

        // Poll until thermal state recovers to .nominal or timeout expires
        while ProcessInfo.processInfo.thermalState != .nominal {
            let elapsed = PlatformMonotonicTimer.nowNanoseconds() - startNanos
            if elapsed >= maxWaitNanos {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // Poll every 500ms
        }

        // Additional 1.5s post-nominal stabilization delay for DVFS frequency settling
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return true
    }
}

// MARK: - Hardware Protocols

//
//


// MARK: - Algorithm Engine Protocol Abstractions

/// Hardware topology tuning interface for thread pool sizing, buffer alignment, and QoS boosting.
public protocol HardwareTunerProtocol: Sendable {
    /// Total logical/physical core count available for concurrency.
    var totalCores: Int { get }
    /// Optimal Zstandard long distance matching window log base 2.
    var optimalZstdLongWindowLog: Int { get }
    /// Optimal page-aligned memory buffer size in bytes.
    var optimalAlignedBufferSize: Int { get }
    /// Elevates current thread QoS priority to userInteractive/userInitiated.
    func boostCurrentThreadPriority()
}

// Extension conformances for standard engine implementations
extension AppleSiliconTuner: HardwareTunerProtocol {
    public var totalCores: Int {
        return self.topology.totalCores
    }
}

// MARK: - Apple Silicon Tuner

//
//


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
