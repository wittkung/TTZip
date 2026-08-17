import Foundation

/// 纯内存 libarchive ASCII .uu 黄金语料库高速解码器
public enum LibarchiveUUDecoder {
    
    /// 从 .uu 纯文本内容中直接还原二进制归档数据 (100% 内存直通，零磁盘 I/O)
    public static func decode(uuString: String) -> Data? {
        var result = Data()
        var started = false
        
        let lines = uuString.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !started {
                if trimmed.hasPrefix("begin ") {
                    started = true
                }
                continue
            }
            if trimmed == "end" || trimmed.isEmpty {
                break
            }
            
            // UUDecode 核心解码逻辑 (首字符标定本行实际有效字节数)
            guard let firstChar = trimmed.first,
                  let lineLength = decodeChar(firstChar),
                  lineLength > 0 else {
                continue
            }
            
            var byteCount = Int(lineLength)
            let chars = Array(trimmed.dropFirst())
            var idx = 0
            
            while byteCount > 0 && idx + 1 < chars.count {
                let c0 = decodeChar(chars[idx]) ?? 0
                let c1 = decodeChar(chars[idx + 1]) ?? 0
                let c2 = (idx + 2 < chars.count) ? (decodeChar(chars[idx + 2]) ?? 0) : 0
                let c3 = (idx + 3 < chars.count) ? (decodeChar(chars[idx + 3]) ?? 0) : 0
                
                let b0 = UInt8((c0 << 2) | (c1 >> 4))
                result.append(b0)
                byteCount -= 1
                
                if byteCount > 0 {
                    let b1 = UInt8(((c1 & 0x0F) << 4) | (c2 >> 2))
                    result.append(b1)
                    byteCount -= 1
                }
                if byteCount > 0 {
                    let b2 = UInt8(((c2 & 0x03) << 6) | c3)
                    result.append(b2)
                    byteCount -= 1
                }
                idx += 4
            }
        }
        return result.isEmpty ? nil : result
    }
    
    /// 从 .uu 文件路径直接读取并解码为内存 Data
    public static func decode(fileURL: URL) -> Data? {
        guard let content = try? String(contentsOf: fileURL, encoding: .ascii) else {
            return nil
        }
        return decode(uuString: content)
    }
    
    /// 从文件相对路径或绝对路径解码
    public static func decode(filePath: String) -> Data? {
        return decode(fileURL: URL(fileURLWithPath: filePath))
    }
    
    @inline(__always)
    private static func decodeChar(_ c: Character) -> UInt8? {
        guard let ascii = c.asciiValue, ascii >= 32 && ascii <= 96 else { return nil }
        return (ascii - 32) & 0x3F
    }
}
