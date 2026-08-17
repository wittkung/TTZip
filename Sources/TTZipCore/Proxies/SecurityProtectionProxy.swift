import Foundation

/// 安全保护代理抛出的异常类型
public enum ProxySecurityError: Error, Equatable, LocalizedError, Sendable {
    case unauthorizedProFeature(LicenseManager.ProFeature)
    case zipSlipDetected(path: String)
    case passwordRequired(archivePath: String)
    case securityScanFailed(suspiciousFiles: [String])
    
    public var errorDescription: String? {
        switch self {
        case .unauthorizedProFeature(let feature):
            return "🚫 商业授权拦截: 功能 \(feature) 需要激活 TTZip Pro 许可证！"
        case .zipSlipDetected(let path):
            return "🚨 ZipSlip 安全拦截: 检测到目录穿透逃逸攻击路径 '\(path)'！"
        case .passwordRequired(let archivePath):
            return "🔒 密码保护拦截: 归档包 '\(archivePath)' 已被加密，需要口令！"
        case .securityScanFailed(let suspicious):
            return "⚠️ 安全合规拦截: 包含 \(suspicious.count) 个潜在可疑可执行文件或危险组件！"
        }
    }
}

/// 【2.7 代理模式 (Proxy Pattern)】保护代理 (Protection Proxy)
/// `SecurityProtectionProxy` 负责在归档读写、解压与高级压缩前进行：
/// 1. Pro 商业授权门控 (Pro License Gatekeeping)
/// 2. ZipSlip 路径逃逸检测 (ZipSlip Path Traversal Defense)
/// 3. 密码保护与安全合规审计 (Security Audit & Vault Inspection)
public final class SecurityProtectionProxy: TTZipEngineFacading, @unchecked Sendable {
    public static let shared = SecurityProtectionProxy()
    
    private let targetEngine: TTZipEngineFacading
    private let licenseManager: LicenseManager
    private let securityFacade: ArchiveSecurityFacading
    private let passwordVault: PasswordVaultManaging
    
    // 线程安全的拦截与审批指标统计
    private let lock = NSLock()
    public private(set) var interceptedProCount: Int = 0
    public private(set) var interceptedZipSlipCount: Int = 0
    public private(set) var approvedCallCount: Int = 0
    
    private convenience init() {
        self.init(
            targetEngine: TTZipEngineFacade.shared,
            licenseManager: LicenseManager.shared,
            securityFacade: ArchiveSecurityFacade.shared,
            passwordVault: PasswordVaultManager.shared
        )
    }
    
    internal init(
        targetEngine: TTZipEngineFacading = TTZipEngineFacade.shared,
        licenseManager: LicenseManager = LicenseManager.shared,
        securityFacade: ArchiveSecurityFacading = ArchiveSecurityFacade.shared,
        passwordVault: PasswordVaultManaging = PasswordVaultManager.shared
    ) {
        self.targetEngine = targetEngine
        self.licenseManager = licenseManager
        self.securityFacade = securityFacade
        self.passwordVault = passwordVault
    }
    
    /// 静态通配路径穿越与全变体逃逸攻击检测 (URL 编码 %2e%2e, POSIX/Win/UNC 绝对路径, 空字符)
    public static func isPathTraversalOrEscape(_ rawPath: String) -> Bool {
        // 1. URL 解码与多重编码防御 (最多 5 轮解包)
        var decoded = rawPath
        for _ in 0..<5 {
            if let next = decoded.removingPercentEncoding, next != decoded {
                decoded = next
            } else {
                break
            }
        }
        
        // 2. 截断/空字节拦截
        if decoded.contains("\0") {
            return true
        }
        
        // 3. 统一斜杠规范化 (\ -> /)
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")
        
        // 4. 组件级别 .. 穿越检测
        let components = normalized.components(separatedBy: "/")
        if components.contains("..") {
            return true
        }
        
        // 5. 绝对路径越权系统敏感目录检测 (POSIX /etc/, /var/log/, /private/etc/, Windows C:\, UNC \\)
        if normalized.hasPrefix("/etc/") || normalized.hasPrefix("/var/log/") || normalized.hasPrefix("/private/etc/") ||
           normalized.hasPrefix("//") || hasWindowsDriveLetterPrefix(normalized) {
            return true
        }
        
        // 6. 残留未解包的逃逸组件检测 (%2e%2e 变体在斜杠边界)
        let rawLower = rawPath.lowercased()
        if rawLower.contains("%2e%2e/") || rawLower.contains("/%2e%2e") || rawLower == "%2e%2e" ||
           rawLower.contains("%2e%2e\\") || rawLower.contains("\\%2e%2e") {
            return true
        }
        
        return false
    }
    
    private static func hasWindowsDriveLetterPrefix(_ path: String) -> Bool {
        guard path.count >= 2 else { return false }
        let utf8 = path.utf8
        let first = utf8[utf8.startIndex]
        let second = utf8[utf8.index(after: utf8.startIndex)]
        let isLetter = (first >= 0x41 && first <= 0x5A) || (first >= 0x61 && first <= 0x7A)
        return isLetter && second == 0x3A
    }
    
    // MARK: - 1. 快捷压缩保护拦截 (Compress Protection)
    
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = .defaultClean,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        // A. 授权门控校验 (覆盖顶层参数与 AdvancedOptions 隐藏死角)
        let isUltraLevel = (level == .ultra) ||
            (advancedOptions?.zstdLevel ?? 0) >= 9 ||
            (advancedOptions?.sevenZipOptions.dictionarySizeMB ?? 0) >= 64
        if isUltraLevel {
            guard licenseManager.canUseFeature(.ultraCompression) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.ultraCompression)
            }
        }
        
        let isEncrypted = (password != nil && !password!.isEmpty) ||
            (advancedOptions?.encryptFileNames == true) ||
            (advancedOptions?.zipOptions.zipEncryptionMethod.contains("AES") == true && password != nil)
        if isEncrypted {
            guard licenseManager.canUseFeature(.aes256Encryption) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.aes256Encryption)
            }
        }
        
        let isSplit = (splitSize != nil && splitSize! > 0)
        if isSplit {
            guard licenseManager.canUseFeature(.volumeSplit) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.volumeSplit)
            }
        }
        
        if inputs.count > 5 {
            guard licenseManager.canUseFeature(.batchProcessing) else {
                recordProInterception()
                throw ProxySecurityError.unauthorizedProFeature(.batchProcessing)
            }
        }
        
        // B. ZipSlip 路径逃逸检测 (全变体变轨拦截)
        for input in inputs {
            if SecurityProtectionProxy.isPathTraversalOrEscape(input) {
                recordZipSlipInterception()
                throw ProxySecurityError.zipSlipDetected(path: input)
            }
        }
        
        if SecurityProtectionProxy.isPathTraversalOrEscape(outputPath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: outputPath)
        }
        
        recordApproval()
        return try await targetEngine.quickCompress(
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: filterOptions,
            advancedOptions: advancedOptions,
            progress: progress
        )
    }
    
    // MARK: - 2. 快捷解压保护拦截 (Extract Protection)
    
    public func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ExtractResult {
        // A. 授权检查
        guard licenseManager.canUseFeature(.basicExtract) else {
            recordProInterception()
            throw ProxySecurityError.unauthorizedProFeature(.basicExtract)
        }
        
        // B. ZipSlip 路径穿透风险检查
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) || SecurityProtectionProxy.isPathTraversalOrEscape(destinationDir) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: destinationDir)
        }
        
        // C. Pre-flight 检查归档内文件是否有路径越权逃逸
        let targetPassword = password ?? ArchivePasswordStore.shared.getPassword(for: archivePath)
        if let inspection = try? await targetEngine.inspectArchive(archivePath: archivePath, password: targetPassword, autoVaultUnlock: autoVaultUnlock) {
            for entry in inspection.entries {
                if !securityFacade.validateExtractPath(entryPath: entry.path, destinationDir: destinationDir) {
                    recordZipSlipInterception()
                    throw ProxySecurityError.zipSlipDetected(path: entry.path)
                }
            }
            if !inspection.securityReport.isSafe && inspection.securityReport.hasZipSlipRisk {
                recordZipSlipInterception()
                throw ProxySecurityError.zipSlipDetected(path: archivePath)
            }
        }
        
        recordApproval()
        return try await targetEngine.quickExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            autoVaultUnlock: autoVaultUnlock,
            progress: progress
        )
    }
    
    // MARK: - 3. 单文件提取保护拦截 (Single Entry Extract Protection)
    
    public func extractSingleEntry(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) || SecurityProtectionProxy.isPathTraversalOrEscape(destinationDir) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: entryPath)
        }
        
        // A. ZipSlip 路径验证
        guard securityFacade.validateExtractPath(entryPath: entryPath, destinationDir: destinationDir) else {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: entryPath)
        }
        
        recordApproval()
        try await targetEngine.extractSingleEntry(
            archivePath: archivePath,
            entryPath: entryPath,
            destinationDir: destinationDir,
            password: password
        )
    }
    
    // MARK: - 4. 元数据探索保护拦截 (Inspect Protection)
    
    public func inspectArchive(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: archivePath)
        }
        
        recordApproval()
        return try await targetEngine.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
    }
    
    // MARK: - 5. 其他引擎方法透传与死角拦截
    
    public func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: archivePath)
        }
        recordApproval()
        return try await targetEngine.verifyIntegrity(archivePath: archivePath)
    }
    
    public func repairArchive(damagedPath: String, outputPath: String) async throws -> Int {
        if SecurityProtectionProxy.isPathTraversalOrEscape(damagedPath) || SecurityProtectionProxy.isPathTraversalOrEscape(outputPath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: damagedPath)
        }
        recordApproval()
        return try await targetEngine.repairArchive(damagedPath: damagedPath, outputPath: outputPath)
    }
    
    public func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        if SecurityProtectionProxy.isPathTraversalOrEscape(archivePath) {
            recordZipSlipInterception()
            throw ProxySecurityError.zipSlipDetected(path: archivePath)
        }
        recordApproval()
        return try await targetEngine.recoverPassword(archivePath: archivePath, dictionary: dictionary)
    }
    
    // MARK: - 统计与重置
    
    private func recordProInterception() {
        lock.withLock {
            interceptedProCount += 1
        }
    }
    
    private func recordZipSlipInterception() {
        lock.withLock {
            interceptedZipSlipCount += 1
        }
    }
    
    private func recordApproval() {
        lock.withLock {
            approvedCallCount += 1
        }
    }
    
    public func resetMetrics() {
        lock.withLock {
            interceptedProCount = 0
            interceptedZipSlipCount = 0
            approvedCallCount = 0
        }
    }
}
