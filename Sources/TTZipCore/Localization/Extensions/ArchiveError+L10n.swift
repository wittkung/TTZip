import Foundation

extension ArchiveError {
    
    /// 获取当前语言或指定语言下的本地化错误描述
    public func localizedDescription(for language: AppLanguage? = nil) -> String {
        let manager = TTZipLocalizationManager.shared
        switch self {
        case .fileNotFound:
            return manager.string(for: L10n.Errors.fileNotFound, language: language)
        case .readFailed(let code):
            let template = manager.string(for: L10n.Errors.corruptedHeader, language: language)
            return "\(template) (Code: \(code))"
        case .invalidFormat:
            return manager.string(for: L10n.Archive.unsupportedFormat, language: language)
        case .passwordRequired, .passwordRequiredDetailed:
            return manager.string(for: L10n.Archive.passwordRequired, language: language)
        case .wrongPassword:
            return manager.string(for: L10n.Archive.incorrectPassword, language: language)
        case .unsupportedEncryptionMethod(_, let method):
            let template = manager.string(for: L10n.Archive.unsupportedFormat, language: language)
            return "\(template) [\(method)]"
        case .corruptedData(_, let entryPath):
            let template = manager.string(for: L10n.Archive.corruptData, language: language)
            return "\(template): \(entryPath)"
        case .cancelled:
            return manager.string(for: L10n.Errors.operationCancelled, language: language)
        case .invalidState:
            return manager.string(for: L10n.Common.error, language: language)
        }
    }
}
