import Foundation

/// 跨模块共享的强类型本地化中心管理器
public final class TTZipLocalizationManager: @unchecked Sendable {
    public static let shared = TTZipLocalizationManager()
    
    private let lock = NSLock()
    private var _currentLanguage: AppLanguage
    
    /// 当前生效的应用界面与 CLI 交互语言
    public var currentLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLanguage
        }
        set {
            lock.lock()
            _currentLanguage = newValue
            lock.unlock()
        }
    }
    
    private init() {
        // 1. 优先读取 POSIX 环境变量 (LC_ALL / LANG)
        let env = ProcessInfo.processInfo.environment
        if let lcAll = env["LC_ALL"], let parsed = AppLanguage.from(identifier: lcAll) {
            self._currentLanguage = parsed
            return
        }
        if let lang = env["LANG"], let parsed = AppLanguage.from(identifier: lang) {
            self._currentLanguage = parsed
            return
        }
        
        // 2. 其次读取系统当前首选语言
        if let preferred = Locale.preferredLanguages.first, let parsed = AppLanguage.from(identifier: preferred) {
            self._currentLanguage = parsed
            return
        }
        
        // 3. 兜底回退为英文 (en)
        self._currentLanguage = .en
    }
    
    /// 根据当前语言或指定语言解析键值字符串
    public func string(for key: LocaleKeyProtocol, language: AppLanguage? = nil) -> String {
        let targetLanguage = language ?? currentLanguage
        let rawKey = key.rawKey
        
        // 1. 从目标语言包字典查找
        if let val = catalog(for: targetLanguage)[rawKey] {
            return val
        }
        
        // 2. 级联回退至英文 (en)
        if targetLanguage != .en, let fallbackVal = LocaleCatalogEn.strings[rawKey] {
            return fallbackVal
        }
        
        // 3. 兜底返回 Raw Key
        return rawKey
    }
    
    /// 根据语言返回对应的字典映射
    private func catalog(for language: AppLanguage) -> [String: String] {
        switch language {
        case .en: return LocaleCatalogEn.strings
        case .zhHans: return LocaleCatalogZhHans.strings
        case .zhHant: return LocaleCatalogZhHant.strings
        case .ja: return LocaleCatalogJa.strings
        case .de: return LocaleCatalogDe.strings
        case .fr: return LocaleCatalogFr.strings
        case .es: return LocaleCatalogEs.strings
        }
    }
}
