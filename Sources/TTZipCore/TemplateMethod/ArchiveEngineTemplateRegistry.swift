import Foundation

/// 【3.6 模板方法模式 (Template Method Pattern)】模板引擎集中注册表与工厂
public final class ArchiveEngineTemplateRegistry: @unchecked Sendable {
    public static let shared = ArchiveEngineTemplateRegistry()

    private let lock = NSLock()
    private var formatTemplates: [ArchiveCompressionFormat: BaseArchiveEngineTemplate] = [:]
    private var passwordRecoveryTemplate: BaseArchiveEngineTemplate

    private init() {
        self.passwordRecoveryTemplate = PasswordRecoveryEngineTemplate()
        registerDefaults()
    }

    private func registerDefaults() {
        let tarTpl = TarArchiveEngineTemplate()
        formatTemplates[.zip] = ZipArchiveEngineTemplate()
        formatTemplates[.sevenZip] = SevenZipArchiveEngineTemplate()
        formatTemplates[.tar] = tarTpl
        formatTemplates[.tarGz] = tarTpl
        formatTemplates[.gz] = tarTpl
        formatTemplates[.tarBz2] = tarTpl
        formatTemplates[.bz2] = tarTpl
        formatTemplates[.tarZst] = tarTpl
        formatTemplates[.zst] = tarTpl
        formatTemplates[.tarXz] = tarTpl
        formatTemplates[.xz] = tarTpl
        formatTemplates[.lzip] = tarTpl
        formatTemplates[.lz4] = tarTpl
        formatTemplates[.brotli] = tarTpl
        formatTemplates[.lrzip] = tarTpl
        formatTemplates[.snappy] = tarTpl
        formatTemplates[.wim] = tarTpl
        formatTemplates[.dmg] = tarTpl
        formatTemplates[.iso] = tarTpl
        formatTemplates[.aar] = tarTpl
    }

    /// 注册特定格式的模板实现
    public func register(template: BaseArchiveEngineTemplate, for format: ArchiveCompressionFormat) {
        lock.lock()
        defer { lock.unlock() }
        formatTemplates[format] = template
    }

    /// 获取特定格式的模板实现
    public func template(for format: ArchiveCompressionFormat) -> BaseArchiveEngineTemplate {
        lock.lock()
        defer { lock.unlock() }
        return formatTemplates[format] ?? TarArchiveEngineTemplate()
    }

    /// 根据路径与操作类型动态匹配最优模板实现
    public func template(forPath path: String, operation: ArchiveOperationType) -> BaseArchiveEngineTemplate {
        if operation == .recover {
            return passwordRecoveryTemplate
        }
        let lower = path.lowercased()
        let isTarFamily = lower.contains(".tar") || lower.contains(".tgz") || lower.contains(".txz") || lower.contains(".tbz2") || lower.contains(".tzst")
        if isTarFamily {
            return template(for: .tar)
        }
        if lower.contains(".7z") || lower.contains(".cb7") || lower.hasSuffix(".001") || lower.contains("sevenzip") || lower.hasSuffix(".dmg") || lower.hasSuffix(".iso") {
            return template(for: .sevenZip)
        } else if lower.hasSuffix(".zip") || lower.contains(".zip.") || lower.hasSuffix(".zipx") {
            return template(for: .zip)
        } else {
            return template(for: .tar)
        }
    }

    /// 便捷执行模板方法工作流
    public func executeWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult {
        let tpl = template(forPath: context.archivePath, operation: context.operation)
        return try tpl.performWorkflow(context: context)
    }

    /// 便捷异步执行模板方法工作流
    public func executeWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        let tpl = template(forPath: context.archivePath, operation: context.operation)
        return try await tpl.performWorkflowAsync(context: context)
    }
}
