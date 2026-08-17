import Foundation

/// 零堆分配的高性能 16 字节对齐 HexDump 差分格式化引擎 (对标 libarchive `hexdump` 与 `assertion_equal_mem`)
public enum FastHexDiffEngine: Sendable {
    private static let hexDigits: [UInt8] = Array("0123456789ABCDEF".utf8)
    
    /// 快速比对两个缓冲区并在首个分歧处生成 16 字节对齐的差分窗口
    ///
    /// - Parameters:
    ///   - expected: 期望缓冲区切片
    ///   - actual: 实际缓冲区切片
    ///   - maxWindow: 差分展示最大字节数（默认 256 字节，防止刷屏）
    ///   - useAnsi: 是否启用 ANSI 终端高亮颜色 (默认 true)
    /// - Returns: 若完全一致返回 nil；若分歧返回格式化的差分文本
    public static func generateDiff(
        expected: UnsafeRawBufferPointer,
        actual: UnsafeRawBufferPointer,
        maxWindow: Int = 256,
        useAnsi: Bool = true
    ) -> String? {
        // 快速处理零长度特例
        if expected.count == 0 && actual.count == 0 {
            return nil
        }
        
        let minLen = min(expected.count, actual.count)
        var mismatchOffset = minLen
        
        if minLen > 0, let pExp = expected.baseAddress, let pAct = actual.baseAddress {
            var offset = 0
            
            // 1. 64 字节 SIMD 块跳跃寻找首个分歧块 (利用 libc/NEON 高度优化的 memcmp)
            while offset + 64 <= minLen {
                if memcmp(pExp.advanced(by: offset), pAct.advanced(by: offset), 64) != 0 {
                    // 在发生分歧的 64 字节块内，先以 8 字节 (64-bit 字) 快速收敛，再精确到单字节
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
            
            // 若 64 字节块内未发生分歧，检查尾部剩余字节
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
        
        // 2. 若全部公共前缀一致且长度相同，则完全匹配，零堆分配立即返回 nil
        if mismatchOffset == minLen && expected.count == actual.count {
            return nil
        }
        
        // 3. 计算 16 字节对齐的滑动展示窗口 (保留前置 64 字节上下文)
        let start = max(0, (mismatchOffset - 64) & ~0x0F)
        let totalMaxLen = max(expected.count, actual.count)
        let end = min(totalMaxLen, start + maxWindow)
        
        // 4. 预分配字符串缓冲组装格式化差分视图
        var result = ""
        result.reserveCapacity(4096)
        
        result.append(String(format: "⚠️ [Binary Mismatch] First difference at offset 0x%08X (%d bytes):\n", mismatchOffset, mismatchOffset))
        result.append("  Expected length: \(expected.count) bytes | Actual length: \(actual.count) bytes\n\n")
        result.append("  Offset    Expected (Hex)                                    Actual (Hex)                                      | Expected (ASCII) | Actual (ASCII)  |\n")
        result.append("  ---------------------------------------------------------------------------------------------------------------------------------------------\n")
        
        for lineStart in stride(from: start, to: end, by: 16) {
            result.append(String(format: "  %08X  ", lineStart))
            
            // Expected Hex 列 (16 字节，每字节固定 3 字符对齐)
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
            
            // Actual Hex 列 (16 字节，每字节固定 3 字符对齐)
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
    
    /// Data 便捷重载
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
