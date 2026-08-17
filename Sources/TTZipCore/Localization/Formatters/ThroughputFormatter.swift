import Foundation

/// 高性能无锁本地化吞吐速率格式化引擎
public enum ThroughputFormatter {
    
    /// 格式化吞吐速率 (MB/s)
    public static func format(mbPerSec: Double, language: AppLanguage = .en) -> String {
        guard mbPerSec >= 0 else { return "0.0 MB/s" }
        
        let formattedVal: String
        if mbPerSec >= 10000.0 {
            formattedVal = String(format: "%.0f", mbPerSec)
        } else if mbPerSec >= 100.0 {
            formattedVal = String(format: "%.1f", mbPerSec)
        } else {
            formattedVal = String(format: "%.2f", mbPerSec)
        }
        
        let localizedVal: String
        switch language {
        case .de, .fr, .es:
            localizedVal = formattedVal.replacingOccurrences(of: ".", with: ",")
        case .en, .zhHans, .zhHant, .ja:
            localizedVal = formattedVal
        }
        
        return "\(localizedVal) MB/s"
    }
}
