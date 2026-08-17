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
    ///   - useAnsi: 是否启用 ANSI 终端高亮颜色
    /// - Returns: 若完全一致返回 nil；若分歧返回格式化的差分文本
    public static func generateDiff(
        expected: UnsafeRawBufferPointer,
        actual: UnsafeRawBufferPointer,
        maxWindow: Int = 256,
        useAnsi: Bool = true
    ) -> String? {
        let minLen = min(expected.count, actual.count)
        guard let pExp = expected.baseAddress, let pAct = actual.baseAddress else {
            if expected.count == actual.count { return nil }
            return "Buffer null pointer comparison failure (expected: \(expected.count)B, actual: \(actual.count)B)"
        }
        
        // 1. 快速 64 字节块跳跃寻找首个分歧点
        var mismatchOffset = minLen
        var offset = 0
        while offset + 64 <= minLen {
            if memcmp(pExp.advanced(by: offset), pAct.advanced(by: offset), 64) != 0 {
                break
            }
            offset += 64
        }
        while offset < minLen {
            if pExp.load(fromByteOffset: offset, as: UInt8.self) != pAct.load(fromByteOffset: offset, as: UInt8.self) {
                mismatchOffset = offset
                break
            }
            offset += 1
        }
        
        // 若全部公共前缀一致且长度相同，则无分歧
        if mismatchOffset == minLen && expected.count == actual.count {
            return nil
        }
        
        // 2. 计算 16 字节对齐的滑动展示窗口
        let start = max(0, (mismatchOffset - 64) & ~0x0F)
        let totalMaxLen = max(expected.count, actual.count)
        let end = min(totalMaxLen, start + maxWindow)
        
        // 3. 查表法单次缓冲组装
        var result = ""
        result.reserveCapacity(4096)
        
        let diffIndicator = useAnsi ? "\u{001B}[1;31m" : "_"
        let resetIndicator = useAnsi ? "\u{001B}[0m" : "_"
        
        result.append(String(format: "⚠️ [Binary Mismatch] First difference at offset 0x%08X (%d bytes):\n", mismatchOffset, mismatchOffset))
        result.append("  Expected length: \(expected.count) bytes | Actual length: \(actual.count) bytes\n\n")
        result.append("  Offset    Expected (Hex)                    Actual (Hex)                      ASCII (Exp|Act)\n")
        result.append("  ---------------------------------------------------------------------------------------------\n")
        
        for lineStart in stride(from: start, to: end, by: 16) {
            let lineEnd = min(lineStart + 16, end)
            result.append(String(format: "  %08X  ", lineStart))
            
            // Expected Hex 列 (16 字节)
            for i in lineStart..<lineStart + 16 {
                if i < expected.count {
                    let b = expected[i]
                    let isDiff = (i >= actual.count || b != actual[i])
                    if isDiff { result.append(diffIndicator) } else { result.append(" ") }
                    result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                    result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                    if isDiff { result.append(resetIndicator) }
                } else {
                    result.append("   ")
                }
            }
            result.append("  ")
            
            // Actual Hex 列 (16 字节)
            for i in lineStart..<lineStart + 16 {
                if i < actual.count {
                    let b = actual[i]
                    let isDiff = (i >= expected.count || b != expected[i])
                    if isDiff { result.append(diffIndicator) } else { result.append(" ") }
                    result.append(Character(UnicodeScalar(hexDigits[Int(b >> 4)])))
                    result.append(Character(UnicodeScalar(hexDigits[Int(b & 0x0F)])))
                    if isDiff { result.append(resetIndicator) }
                } else {
                    result.append("   ")
                }
            }
            result.append("  |")
            
            // ASCII Preview (Expected)
            for i in lineStart..<lineEnd {
                if i < expected.count {
                    let b = expected[i]
                    result.append((b >= 32 && b <= 126) ? Character(UnicodeScalar(b)) : ".")
                } else {
                    result.append(" ")
                }
            }
            result.append("|")
            
            // ASCII Preview (Actual)
            for i in lineStart..<lineEnd {
                if i < actual.count {
                    let b = actual[i]
                    result.append((b >= 32 && b <= 126) ? Character(UnicodeScalar(b)) : ".")
                } else {
                    result.append(" ")
                }
            }
            result.append("|\n")
        }
        
        return result
    }
    
    /// Data 便捷重载
    public static func generateDiff(expected: Data, actual: Data, maxWindow: Int = 256, useAnsi: Bool = true) -> String? {
        expected.withUnsafeBytes { pExp in
            actual.withUnsafeBytes { pAct in
                generateDiff(expected: pExp, actual: pAct, maxWindow: maxWindow, useAnsi: useAnsi)
            }
        }
    }
}
