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
    
    /// Boosts current thread scheduling QoS priority to user interactive on Darwin.
    @inlinable
    public static func boostCurrentThreadPriority() {
        #if os(macOS)
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        #endif
    }
}
