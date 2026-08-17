import Foundation

/// 存储容量格式化标准
public enum ByteSizeStandard: Sendable {
    /// 国际十进制 SI 标准 (1 KB = 1000 B, 1 MB = 1000 KB, macOS 默认)
    case metricSI
    /// 国际二进制 IEC 标准 (1 KiB = 1024 B, 1 MiB = 1024 KiB)
    case binaryIEC
}

/// 高性能无堆分配本地化字节容量格式化引擎
public enum ByteSizeFormatter {
    
    private static let metricUnits = ["B", "KB", "MB", "GB", "TB", "PB"]
    private static let binaryUnits = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    
    /// 格式化字节尺寸
    public static func format(bytes: Int64, style: ByteSizeStandard = .metricSI, language: AppLanguage = .en) -> String {
        guard bytes >= 0 else { return "0 B" }
        if bytes < 1000 && style == .metricSI { return "\(bytes) B" }
        if bytes < 1024 && style == .binaryIEC { return "\(bytes) B" }
        
        let base: Double = (style == .metricSI) ? 1000.0 : 1024.0
        let units = (style == .metricSI) ? metricUnits : binaryUnits
        
        var val = Double(bytes)
        var unitIdx = 0
        
        while val >= base && unitIdx < units.count - 1 {
            val /= base
            unitIdx += 1
        }
        
        let formattedVal = String(format: "%.1f", val)
        let localizedVal = formatDecimalString(formattedVal, for: language)
        return "\(localizedVal) \(units[unitIdx])"
    }
    
    private static func formatDecimalString(_ str: String, for language: AppLanguage) -> String {
        switch language {
        case .de, .fr, .es:
            return str.replacingOccurrences(of: ".", with: ",")
        case .en, .zhHans, .zhHant, .ja:
            return str
        }
    }
}
