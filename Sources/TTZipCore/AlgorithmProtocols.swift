// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
