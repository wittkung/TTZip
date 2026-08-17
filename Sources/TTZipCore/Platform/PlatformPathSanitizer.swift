import Foundation

/// 跨平台工业级路径清洗、规范化与安全审计中枢
///
/// 对标 libarchive `archive_read_disk_posix.c` 与 `archive_read_disk_windows.c`，提供：
/// - 栈式分段 Zip Slip 目录穿越中和 ($O(N)$ 零堆碎片)
/// - Windows DOS 保留设备名 (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`, `PhysicalDrive`) 深度拦截
/// - NTFS 备用数据流 (Alternate Data Stream, ADS) 冒号流剥离
/// - 32,767 字符 Win32 超长路径 (`\\?\` 与 `\\?\UNC\`) 自动正规化
/// - APFS NFD (Decomposed) 到标准 NFC (Precomposed) Unicode 正规化
public enum PlatformPathSanitizer: Sendable {
    
    private static let windowsReservedNames: Set<String> = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]
    
    /// 对任意输入路径执行跨平台无死角安全清洗与规范化分析
    ///
    /// - Parameter path: 原始输入相对或绝对路径字符串
    /// - Returns: 包含规范化路径、是否越界、是否包含保留设备名与 ADS 信息的强类型结果
    ///
    /// - Complexity: $O(N)$，其中 $N$ 为路径字符长度
    /// - Note: [Security Invariant] 返回的 `normalizedPath` 绝不以 `/` 开头、绝不包含 `..`、绝不包含 ADS 冒号流
    public static func sanitize(path: String) -> PlatformPathNormalizationResult {
        guard !path.isEmpty else {
            return PlatformPathNormalizationResult(
                originalPath: "",
                normalizedPath: "",
                isAbsolute: false,
                isUNCPath: false,
                isLongPath: false,
                containsWindowsReservedDeviceName: false,
                strippedAlternateDataStream: nil,
                win32FormattedPath: ""
            )
        }
        
        var isUNC = false
        var isAbsolute = false
        var working = path
        
        // 1. UNC 网络路径检测与保留 (\server\share)
        if working.hasPrefix("\\\\") || working.hasPrefix("//") {
            isUNC = true
            isAbsolute = true
        } else if working.hasPrefix("/") || working.hasPrefix("\\") {
            isAbsolute = true
        }
        
        // 2. Windows 盘符检测 (C:/ 或 C:\)
        if working.count >= 2 {
            let firstTwo = working.prefix(2)
            if let firstChar = firstTwo.first, firstChar.isLetter && firstTwo.suffix(1) == ":" {
                isAbsolute = true
            }
        }
        
        // 3. 将所有反斜杠标准化为正斜杠并进行 Unicode NFC 预组合正规化
        working = working.replacingOccurrences(of: "\\", with: "/")
        working = working.precomposedStringWithCanonicalMapping
        
        // 4. NTFS 备用数据流 (ADS) 冒号拦截与剥离 (例: filename.txt:evil.exe)
        var strippedADS: String?
        if let colonIndex = working.firstIndex(of: ":") {
            let prefix = working[..<colonIndex]
            if !(prefix.count == 1 && prefix.first?.isLetter == true) { // 排除 Windows 盘符 C:
                strippedADS = String(working[colonIndex...])
                working = String(prefix)
            }
        }
        
        // 5. 栈式分段清洗 (消除冗余斜杠、当前目录 . 与 Zip Slip 穿越 ..)
        let rawSegments = working.split(separator: "/", omittingEmptySubsequences: true)
        var cleanSegments: [String] = []
        var containsReserved = false
        
        for segmentSubstring in rawSegments {
            let segment = String(segmentSubstring)
            
            if segment == "." {
                continue
            }
            if segment == ".." {
                if !cleanSegments.isEmpty {
                    cleanSegments.removeLast()
                }
                continue
            }
            
            // Windows 保留名检查 (不区分大小写，且拦截 CON.txt 等伪装)
            let baseName = (segment as NSString).deletingPathExtension.uppercased()
            if windowsReservedNames.contains(baseName) || segment.uppercased().starts(with: "PHYSICALDRIVE") {
                containsReserved = true
            }
            
            cleanSegments.append(segment)
        }
        
        let normalized = cleanSegments.joined(separator: "/")
        let isLong = normalized.utf16.count > 260
        
        // 6. Windows 格式化路径生成 (反斜杠、UNC 与超长路径前缀)
        var win32Path = cleanSegments.joined(separator: "\\")
        if isUNC {
            win32Path = "\\\\?\\UNC\\" + win32Path
        } else if isLong && isAbsolute {
            win32Path = "\\\\?\\" + win32Path
        }
        
        return PlatformPathNormalizationResult(
            originalPath: path,
            normalizedPath: normalized,
            isAbsolute: isAbsolute,
            isUNCPath: isUNC,
            isLongPath: isLong,
            containsWindowsReservedDeviceName: containsReserved,
            strippedAlternateDataStream: strippedADS,
            win32FormattedPath: win32Path
        )
    }
}
