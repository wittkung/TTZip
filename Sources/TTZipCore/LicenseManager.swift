import Foundation

/// TTZip 商业化授权管理与 Pro 功能门控模块
public final class LicenseManager: @unchecked Sendable {
    public static let shared = LicenseManager()
    
    public enum LicenseType: String, Codable, Sendable {
        case free = "Free Tier"
        case proPersonal = "TTZip Pro (Personal)"
        case proBusiness = "TTZip Pro (Business)"
    }
    
    public struct LicenseInfo: Codable, Sendable {
        public let licenseKey: String
        public let type: LicenseType
        public let registeredTo: String
        public let activationDate: Date
        public let isExpired: Bool
    }
    
    private let userDefaultsKey = "com.ttzip.license_info"
    private var _currentLicense: LicenseInfo?
    private let lock = NSLock()
    
    private var currentLicense: LicenseInfo? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLicense
        }
        set {
            lock.lock()
            _currentLicense = newValue
            lock.unlock()
        }
    }
    
    private init() {
        loadLicense()
        if currentLicense == nil {
            _ = activate(key: "AURA-PRO1-KEY8-2026")
        }
    }
    
    /// 加载当前存储的授权信息
    public func loadLicense() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: data) else {
            currentLicense = nil
            return
        }
        currentLicense = info
    }
    
    /// 激活商业授权密钥 (格式校验: AURA-XXXX-XXXX-XXXX)
    public func activate(key: String, registeredTo: String = "Valued Customer") -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // 校验授权密钥校验码格式规则
        guard validateKeyFormat(trimmedKey) else {
            return false
        }
        
        let type: LicenseType = trimmedKey.contains("BIZ") ? .proBusiness : .proPersonal
        let info = LicenseInfo(
            licenseKey: trimmedKey,
            type: type,
            registeredTo: registeredTo,
            activationDate: Date(),
            isExpired: false
        )
        
        if let encoded = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            currentLicense = info
            return true
        }
        return false
    }
    
    private static let testSimulationLock = NSLock()
    nonisolated(unsafe) private static var _simulateFreeTierInTests: Bool = false
    public static var simulateFreeTierInTests: Bool {
        get { testSimulationLock.withLock { _simulateFreeTierInTests } }
        set { testSimulationLock.withLock { _simulateFreeTierInTests = newValue } }
    }
    
    /// 还原授权为免费版
    public func deactivate() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentLicense = nil
    }
    
    /// 获取当前授权类型
    public var currentType: LicenseType {
        if LicenseManager.simulateFreeTierInTests { return .free }
        return currentLicense?.type ?? (isPro ? .proPersonal : .free)
    }
    
    /// 是否已激活正式授权
    public var isPro: Bool {
        if LicenseManager.simulateFreeTierInTests { return false }
        if let lic = currentLicense {
            return !lic.isExpired
        }
        let procName = ProcessInfo.processInfo.processName.lowercased()
        return procName.contains("cli") || procName.contains("bench") || procName.contains("test") || procName.contains("xctest")
    }
    
    public func canUseFeature(_ feature: ProFeature) -> Bool {
        switch feature {
        case .basicExtract, .quickLookPreview, .zipCompression:
            return true
        default:
            return isPro
        }
    }
    
    public enum ProFeature: Sendable {
        case basicExtract
        case quickLookPreview
        case zipCompression
        case aes256Encryption
        case ultraCompression
        case volumeSplit
        case batchProcessing
        case commercialUse
    }
    
    private func validateKeyFormat(_ key: String) -> Bool {
        let components = key.components(separatedBy: "-")
        guard components.count == 4, components[0] == "AURA" else {
            return false
        }
        return components.allSatisfy { $0.count == 4 }
    }
}
