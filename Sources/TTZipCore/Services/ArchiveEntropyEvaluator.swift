// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance Shannon entropy evaluator for archive pipelines.
///
/// Evaluates input entropy before compression. When Shannon entropy exceeds 7.90, the payload
/// is identified as uncompressible and automatically bypassed to STORE mode.
public enum ArchiveEntropyEvaluator {
    public static let defaultEntropyThreshold: Double = 7.90
    public static let minimumSampleSizeBytes: Int = 1024 * 1024 // 1MB threshold

    /// Whether smart store bypass for high-entropy payloads is enabled.
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

    /// Computes Shannon entropy (0.00 ~ 8.00) for a memory buffer using hardware SIMD.
    public static func estimateEntropy(buffer: UnsafeRawPointer, count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
        return ttzip_rust_estimate_entropy(ptr, count)
    }

    /// Dynamically samples buffer across equidistant strides to evaluate Shannon entropy.
    public static func estimateEntropyDynamic(buffer: UnsafeRawPointer, count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
        return ttzip_rust_estimate_entropy_strided(ptr, count, 65536)
    }

    /// Dynamically samples physical file across equidistant strides to evaluate Shannon entropy.
    public static func estimateFileEntropyDynamic(filePath: String) -> Double {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return 0.0 }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 65536)
        return data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return 0.0 }
            return estimateEntropy(buffer: base, count: raw.count)
        }
    }

    /// Checks if a memory buffer should bypass compression directly to STORE mode.
    public static func shouldBypassCompression(buffer: UnsafeRawPointer, count: Int, threshold: Double = defaultEntropyThreshold) -> Bool {
        guard isSmartStoreBypassEnabled else { return false }
        guard count >= minimumSampleSizeBytes else { return false }
        let ptr = buffer.assumingMemoryBound(to: UInt8.self)
        return ttzip_rust_should_bypass_compression(ptr, count, threshold, minimumSampleSizeBytes)
    }

    /// Checks if Data payload should bypass compression directly to STORE mode.
    public static func shouldBypassCompression(data: Data, threshold: Double = defaultEntropyThreshold) -> Bool {
        guard isSmartStoreBypassEnabled else { return false }
        guard data.count >= minimumSampleSizeBytes else { return false }
        return CUnsafeBufferAdapter.withBufferPointer(data) { ptr, count in
            return shouldBypassCompression(buffer: ptr, count: count, threshold: threshold)
        }
    }

    /// Checks if physical file should bypass compression directly to STORE mode.
    public static func shouldBypassCompression(filePath: String, threshold: Double = defaultEntropyThreshold) -> Bool {
        guard isSmartStoreBypassEnabled else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64) ?? 0
        guard size >= Int64(minimumSampleSizeBytes) else { return false }
        return estimateFileEntropyDynamic(filePath: filePath) > threshold
    }
}
