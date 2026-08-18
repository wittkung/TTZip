// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// High-performance 16-byte aligned HexDump binary diff engine with zero heap allocation (aligned with libarchive `hexdump` and `assertion_equal_mem`).
public enum FastHexDiffEngine: Sendable {
    private static let hexDigits: [UInt8] = Array("0123456789ABCDEF".utf8)
    
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
        
        let minLen = min(expected.count, actual.count)
        var mismatchOffset = minLen
        
        if minLen > 0, let pExp = expected.baseAddress, let pAct = actual.baseAddress {
            var offset = 0
            
            // 1. 64-byte block acceleration via libc/NEON optimized memcmp
            while offset + 64 <= minLen {
                if memcmp(pExp.advanced(by: offset), pAct.advanced(by: offset), 64) != 0 {
                    var inner = offset
                    let innerEnd = offset + 64
                    while inner + 8 <= innerEnd {
                        if pExp.loadUnaligned(fromByteOffset: inner, as: UInt64.self) != pAct.loadUnaligned(fromByteOffset: inner, as: UInt64.self) {
                            break
                        }
                        inner += 8
                    }
                    while inner < innerEnd {
                        if pExp.load(fromByteOffset: inner, as: UInt8.self) != pAct.load(fromByteOffset: inner, as: UInt8.self) {
                            mismatchOffset = inner
                            break
                        }
                        inner += 1
                    }
                    break
                }
                offset += 64
            }
            
            // Tail scan
            if mismatchOffset == minLen {
                while offset + 8 <= minLen {
                    if pExp.loadUnaligned(fromByteOffset: offset, as: UInt64.self) != pAct.loadUnaligned(fromByteOffset: offset, as: UInt64.self) {
                        break
                    }
                    offset += 8
                }
                while offset < minLen {
                    if pExp.load(fromByteOffset: offset, as: UInt8.self) != pAct.load(fromByteOffset: offset, as: UInt8.self) {
                        mismatchOffset = offset
                        break
                    }
                    offset += 1
                }
            }
        } else if expected.count == 0 || actual.count == 0 {
            mismatchOffset = 0
        }
        
        // 2. Exact match check
        if mismatchOffset == minLen && expected.count == actual.count {
            return nil
        }
        
        // 3. Sliding 16-byte aligned display window
        let start = max(0, (mismatchOffset - 64) & ~0x0F)
        let totalMaxLen = max(expected.count, actual.count)
        let end = min(totalMaxLen, start + maxWindow)
        
        // 4. Format output view
        var result = ""
        result.reserveCapacity(4096)
        
        result.append(String(format: "⚠️ [Binary Mismatch] First difference at offset 0x%08X (%d bytes):\n", mismatchOffset, mismatchOffset))
        result.append("  Expected length: \(expected.count) bytes | Actual length: \(actual.count) bytes\n\n")
        result.append("  Offset    Expected (Hex)                                    Actual (Hex)                                      | Expected (ASCII) | Actual (ASCII)  |\n")
        result.append("  ---------------------------------------------------------------------------------------------------------------------------------------------\n")
        
        for lineStart in stride(from: start, to: end, by: 16) {
            result.append(String(format: "  %08X  ", lineStart))
            
            // Expected Hex
            for i in lineStart..<lineStart + 16 {
                if i < expected.count {
                    let b = expected[i]
                    let isDiff = (i >= actual.count || b != actual[i])
                    if isDiff {
                        if useAnsi {
                            result.append(" \u{001B}[1;31m")
                            result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                            result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                            result.append("\u{001B}[0m")
                        } else {
                            result.append("_")
                            result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                            result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                            result.append("_")
                        }
                    } else {
                        result.append(" ")
                        result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                        result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                    }
                } else {
                    result.append("   ")
                }
            }
            result.append("  ")
            
            // Actual Hex
            for i in lineStart..<lineStart + 16 {
                if i < actual.count {
                    let b = actual[i]
                    let isDiff = (i >= expected.count || b != expected[i])
                    if isDiff {
                        if useAnsi {
                            result.append(" \u{001B}[1;31m")
                            result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                            result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                            result.append("\u{001B}[0m")
                        } else {
                            result.append("_")
                            result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                            result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                            result.append("_")
                        }
                    } else {
                        result.append(" ")
                        result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                        result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                    }
                } else {
                    result.append("   ")
                }
            }
            result.append("  | ")
            
            // ASCII Preview (Expected)
            for i in lineStart..<lineStart + 16 {
                if i < expected.count {
                    let b = expected[i]
                    let isDiff = (i >= actual.count || b != actual[i])
                    let char = (b >= 32 && b <= 126) ? Character(UnicodeScalar(b)) : "."
                    if isDiff && useAnsi {
                        result.append("\u{001B}[1;31m")
                        result.append(char)
                        result.append("\u{001B}[0m")
                    } else {
                        result.append(char)
                    }
                } else {
                    result.append(" ")
                }
            }
            result.append(" | ")
            
            // ASCII Preview (Actual)
            for i in lineStart..<lineStart + 16 {
                if i < actual.count {
                    let b = actual[i]
                    let isDiff = (i >= expected.count || b != expected[i])
                    let char = (b >= 32 && b <= 126) ? Character(UnicodeScalar(b)) : "."
                    if isDiff && useAnsi {
                        result.append("\u{001B}[1;31m")
                        result.append(char)
                        result.append("\u{001B}[0m")
                    } else {
                        result.append(char)
                    }
                } else {
                    result.append(" ")
                }
            }
            result.append("|\n")
        }
        
        return result
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
