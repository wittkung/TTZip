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
