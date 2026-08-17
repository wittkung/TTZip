import Foundation

/// 风险级别枚举
public enum SecurityRiskLevel: String, Sendable, Codable, Comparable {
    case safe = "SAFE"
    case warning = "WARNING"
    case critical = "CRITICAL"
    
    private var severity: Int {
        switch self {
        case .safe: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
    
    public static func < (lhs: SecurityRiskLevel, rhs: SecurityRiskLevel) -> Bool {
        return lhs.severity < rhs.severity
    }
}

/// 统一安全审计报告结构体
public struct SecurityReport: Sendable, Equatable {
    public let isSafe: Bool
    public let suspiciousFileNames: [String]
    public let hasZipSlipRisk: Bool
    public let detailMessage: String
    public let riskLevel: SecurityRiskLevel
    
    public init(
        isSafe: Bool,
        suspiciousFileNames: [String],
        hasZipSlipRisk: Bool,
        detailMessage: String,
        riskLevel: SecurityRiskLevel
    ) {
        self.isSafe = isSafe
        self.suspiciousFileNames = suspiciousFileNames
        self.hasZipSlipRisk = hasZipSlipRisk
        self.detailMessage = detailMessage
        self.riskLevel = riskLevel
    }
}

/// 安全与合规校验外观接口
public protocol ArchiveSecurityFacading: Sendable {
    func auditArchive(archivePath: String, password: String?, autoVaultUnlock: Bool) async throws -> SecurityReport
    func validateExtractPath(entryPath: String, destinationDir: String) -> Bool
    func scanEntries(_ entries: [ArchiveEntry]) -> SecurityReport
}

extension ArchiveSecurityFacading {
    public func auditArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> SecurityReport {
        return try await auditArchive(archivePath: archivePath, password: password, autoVaultUnlock: autoVaultUnlock)
    }
}


/// 【2.5 外观模式 (Facade Pattern)】安全与合规门面 (`ArchiveSecurityFacade`)
/// 屏蔽 AMSI 扩展名过滤、ZipSlip 漏洞攻击防御与路径穿透硬化检测细节
public final class ArchiveSecurityFacade: ArchiveSecurityFacading, @unchecked Sendable {
    public static let shared = ArchiveSecurityFacade()
    
    private let securityScanner: SecurityScanner
    private let reader: ArchiveReading
    
    private convenience init() {
        self.init(
            securityScanner: SecurityScanner.shared,
            reader: ArchiveEngineFactory.makeReader()
        )
    }
    
    internal init(
        securityScanner: SecurityScanner = SecurityScanner.shared,
        reader: ArchiveReading = ArchiveEngineFactory.makeReader()
    ) {
        self.securityScanner = securityScanner
        self.reader = reader
    }
    
    // MARK: - 1. 扫描归档文件条目 (Entries Scan API)
    
    public func scanEntries(_ entries: [ArchiveEntry]) -> SecurityReport {
        let rawScan = securityScanner.scanArchiveEntries(entries)
        var hasZipSlip = false
        
        for entry in entries {
            let p = entry.path.lowercased()
            if p.contains("..") || p.hasPrefix("/") || p.contains(":\\") {
                hasZipSlip = true
                break
            }
        }
        
        let riskLevel: SecurityRiskLevel
        if hasZipSlip {
            riskLevel = .critical
        } else if !rawScan.isSafe {
            riskLevel = .warning
        } else {
            riskLevel = .safe
        }
        
        var message = rawScan.detailMessage
        if hasZipSlip {
            message = "🚨 严重高危: 检测到 ZipSlip 路径穿越攻击漏洞代码！"
        }
        
        return SecurityReport(
            isSafe: rawScan.isSafe && !hasZipSlip,
            suspiciousFileNames: rawScan.suspiciousFileNames,
            hasZipSlipRisk: hasZipSlip,
            detailMessage: message,
            riskLevel: riskLevel
        )
    }
    
    // MARK: - 2. 深度归档文件安全审计 (Archive Audit API)
    
    public func auditArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> SecurityReport {
        let explicitPwd = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        
        if let entries = try? await reader.inspect(archivePath: archivePath, password: explicitPwd) {
            return scanEntries(entries)
        }
        
        if autoVaultUnlock && PasswordVaultManager.shared.autoUnlockArchives {
            let vaultEntries = PasswordVaultManager.shared.getEntries()
            for entry in vaultEntries {
                if let entries = try? await reader.inspect(archivePath: archivePath, password: entry.password) {
                    return scanEntries(entries)
                }
            }
        }
        
        throw ArchiveError.passwordRequired
    }
    
    // MARK: - 3. ZipSlip 路径合法性与沙盒防护 API (Path Validation API)
    
    public func validateExtractPath(entryPath: String, destinationDir: String) -> Bool {
        // 1. URL 解码与多重编码防御 (最多 3 轮解包)
        var decodedEntry = entryPath
        for _ in 0..<3 {
            if let next = decodedEntry.removingPercentEncoding, next != decodedEntry {
                decodedEntry = next
            } else {
                break
            }
        }
        
        // 2. 截断/空字节拦截
        if decodedEntry.contains("\0") {
            return false
        }
        
        // 3. 统一规范化斜杠 (Windows 反斜杠 \ -> POSIX 斜杠 /)
        let normalizedEntry = decodedEntry.replacingOccurrences(of: "\\", with: "/")
        
        // 4. 绝对路径与系统级越权路径检测 (POSIX /, Windows C:\, UNC \\)
        if normalizedEntry.hasPrefix("/") ||
           normalizedEntry.range(of: "^[a-zA-Z]:", options: .regularExpression) != nil ||
           normalizedEntry.hasPrefix("//") {
            return false
        }
        
        // 5. 检查 entryPath 组件中是否包含 .. 穿越
        let components = normalizedEntry.components(separatedBy: "/")
        if components.contains("..") {
            return false
        }
        
        // 6. 沙盒基线根目录与目标路径规范化比对
        let destURL = URL(fileURLWithPath: destinationDir).standardized
        let targetURL = destURL.appendingPathComponent(normalizedEntry).standardized
        
        let normalizedDestPath = destURL.path
        let targetPath = targetURL.path
        
        // 核心防线: 目标路径必须位于解压根目录内
        guard targetPath.hasPrefix(normalizedDestPath) else {
            return false
        }
        
        // 7. 软链接越界攻击防护 (Symlink Traversal Check):
        // 校验符号链接/软链接解析后的实际物理路径是否越出解压目录
        let resolvedDest = destURL.resolvingSymlinksInPath().path
        let resolvedTarget = targetURL.resolvingSymlinksInPath().path
        if !resolvedTarget.hasPrefix(resolvedDest) && !resolvedTarget.hasPrefix(normalizedDestPath) {
            return false
        }
        
        return true
    }
}

