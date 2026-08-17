import Foundation

public struct SecurityScanResult: Sendable {
    public let isSafe: Bool
    public let suspiciousFileNames: [String]
    public let detailMessage: String
}

/// 内存级恶意软件防护与安全扫描引擎 (AMSI 模拟与扩展名过滤，支持 Composite Pattern 树扫描)
public final class SecurityScanner: @unchecked Sendable {
    public static let shared = SecurityScanner()
    
    private let dangerousExtensions: Set<String> = [
        "exe", "bat", "cmd", "vbs", "js", "scr", "pif", "sh", "command"
    ]
    
    private init() {}
    
    /// 校验路径是否包含 Zip Slip 路径穿越（..）、绝对路径、DOS 保留名、ADS 冒号流或非法字符
    public static func isPathSafe(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        if path.contains("\0") { return false }
        let res = PlatformPathSanitizer.sanitize(path: path)
        if res.isAbsolute || res.isUNCPath || res.containsWindowsReservedDeviceName || res.strippedAlternateDataStream != nil {
            return false
        }
        let forward = path.replacingOccurrences(of: "\\", with: "/")
        if forward.hasPrefix("/") || forward.contains("..") {
            return false
        }
        return !res.normalizedPath.isEmpty
    }
    
    /// 对路径进行跨平台规范化清洗（消除冗余斜杠、相对段与 ADS 冒号流）
    public static func sanitizePath(_ path: String) -> String? {
        let res = PlatformPathSanitizer.sanitize(path: path)
        guard !res.normalizedPath.isEmpty else { return nil }
        return res.normalizedPath
    }

    
    /// 扫描归档文件内的条目列表，筛查可疑可执行脚本、Zip Slip 路径穿越或恶意文件名
    public func scanArchiveEntries(_ entries: [ArchiveEntry]) -> SecurityScanResult {
        let visitor = SecurityScannerVisitor(dangerousExtensions: dangerousExtensions)
        var suspicious: [String] = []
        for entry in entries {
            // Zip Slip path traversal check
            if !Self.isPathSafe(entry.path) {
                if !suspicious.contains(entry.path) {
                    suspicious.append(entry.path)
                }
                continue
            }
            
            let leaf = ArchiveLeafFile(name: entry.name, path: entry.path, sizeBytes: entry.uncompressedSize, entry: entry)
            let threats = visitor.visit(leaf: leaf)
            if !threats.isEmpty && !suspicious.contains(entry.path) {
                suspicious.append(entry.path)
            }
        }
        if suspicious.isEmpty {
            return SecurityScanResult(
                isSafe: true,
                suspiciousFileNames: [],
                detailMessage: "✅ 内存扫描安全，未发现恶意扩展名或危险路径"
            )
        } else {
            return SecurityScanResult(
                isSafe: false,
                suspiciousFileNames: suspicious,
                detailMessage: "⚠️ 警告：检测到 \(suspicious.count) 个潜在可疑文件或路径！"
            )
        }
    }

    
    /// 使用 访问者模式 (Visitor Pattern) 递归透明扫描 Component 树
    public func scanComponent(_ component: ArchiveComponentProtocol) -> SecurityScanResult {
        let visitor = SecurityScannerVisitor(dangerousExtensions: dangerousExtensions)
        let threats = component.accept(visitor: visitor)
        
        var suspicious: [String] = []
        for threat in threats {
            if !suspicious.contains(threat.path) {
                suspicious.append(threat.path)
            }
        }
        
        if suspicious.isEmpty {
            return SecurityScanResult(
                isSafe: true,
                suspiciousFileNames: [],
                detailMessage: "✅ 内存扫描安全，未发现恶意扩展名或危险路径"
            )
        } else {
            return SecurityScanResult(
                isSafe: false,
                suspiciousFileNames: suspicious,
                detailMessage: "⚠️ 警告：检测到 \(suspicious.count) 个潜在可疑文件或路径！"
            )
        }
    }
    
    public func scanComponents(_ components: [ArchiveComponentProtocol]) -> SecurityScanResult {
        var suspicious: [String] = []
        for component in components {
            let res = scanComponent(component)
            if !res.isSafe {
                for item in res.suspiciousFileNames {
                    if !suspicious.contains(item) {
                        suspicious.append(item)
                    }
                }
            }
        }
        
        if suspicious.isEmpty {
            return SecurityScanResult(
                isSafe: true,
                suspiciousFileNames: [],
                detailMessage: "✅ 内存扫描安全，未发现恶意扩展名或危险路径"
            )
        } else {
            return SecurityScanResult(
                isSafe: false,
                suspiciousFileNames: suspicious,
                detailMessage: "⚠️ 警告：检测到 \(suspicious.count) 个潜在可疑文件或路径！"
            )
        }
    }
}

