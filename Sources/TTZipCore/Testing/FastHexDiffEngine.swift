// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance 16-byte aligned HexDump binary diff engine with zero heap allocation (aligned with libarchive `hexdump` and `assertion_equal_mem`).
public enum FastHexDiffEngine: Sendable {
    
    /// Quickly compares two buffers and generates a 16-byte aligned diff window at the first divergence offset.
    ///
    /// - Parameters:
    ///   - expected: Expected buffer pointer.
    ///   - actual: Actual buffer pointer.
    ///   - maxWindow: Maximum window size in bytes (defaults to 256 to prevent terminal flood).
    ///   - useAnsi: Whether to enable ANSI color formatting (defaults to true).
    /// - Returns: nil if buffers match exactly; formatted diff text otherwise.
    public static func generateDiff(
        expected: UnsafeRawBufferPointer,
        actual: UnsafeRawBufferPointer,
        maxWindow: Int = 256,
        useAnsi: Bool = true
    ) -> String? {
        if expected.count == 0 && actual.count == 0 {
            return nil
        }
        
        let pExp = expected.baseAddress?.assumingMemoryBound(to: UInt8.self)
        let pAct = actual.baseAddress?.assumingMemoryBound(to: UInt8.self)
        var outPtr: UnsafeMutablePointer<CChar>? = nil
        
        let status = ttzip_rust_hex_diff(
            pExp,
            expected.count,
            pAct,
            actual.count,
            maxWindow,
            useAnsi,
            &outPtr
        )
        
        guard status == 1, let validPtr = outPtr else {
            return nil
        }
        
        defer { ttzip_rust_free_hex_diff(validPtr) }
        return String(cString: validPtr)
    }
    
    /// Data overload
    public static func generateDiff(
        expected: Data,
        actual: Data,
        maxWindow: Int = 256,
        useAnsi: Bool = true
    ) -> String? {
        expected.withUnsafeBytes { pExp in
            actual.withUnsafeBytes { pAct in
                generateDiff(expected: pExp, actual: pAct, maxWindow: maxWindow, useAnsi: useAnsi)
            }
        }
    }
}
