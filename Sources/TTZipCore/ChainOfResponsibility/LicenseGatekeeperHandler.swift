import Foundation

/// 5. License 许可控制与 Pro 特权功能门控校验处理者 (LicenseGatekeeperHandler)
public final class LicenseGatekeeperHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    private let licenseManager: LicenseManager
    
    public init(licenseManager: LicenseManager = .shared, nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self.licenseManager = licenseManager
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        // 1. 分卷切片特权门控校验
        if context.options.isSplit || (context.options.splitVolumeSizeBytes != nil && context.options.splitVolumeSizeBytes! > 0) {
            if !licenseManager.canUseFeature(.volumeSplit) {
                return .failure(.licenseRequired(feature: "分卷切片压缩 (Volume Splitting)"))
            }
        }
        
        // 2. AES-256 口令加密门控校验
        if context.options.isEncrypted || (context.password != nil && !context.password!.isEmpty) {
            if !licenseManager.canUseFeature(.aes256Encryption) {
                return .failure(.licenseRequired(feature: "AES-256 高强度安全加密 (AES-256 Encryption)"))
            }
        }
        
        // 3. Ultra 极限压缩级别门控校验
        if context.options.compressionLevel == .ultra {
            if !licenseManager.canUseFeature(.ultraCompression) {
                return .failure(.licenseRequired(feature: "Ultra 极限压缩算法 (Ultra Compression Level)"))
            }
        }
        
        return .success
    }
}
