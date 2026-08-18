// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Centralized registry and factory for archive engine workflow templates (Template Method Pattern).
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

    /// Registers a specialized engine template for the given format.
    public func register(template: BaseArchiveEngineTemplate, for format: ArchiveCompressionFormat) {
        lock.lock()
        defer { lock.unlock() }
        formatTemplates[format] = template
    }

    /// Retrieves the template implementation for a specific format.
    public func template(for format: ArchiveCompressionFormat) -> BaseArchiveEngineTemplate {
        lock.lock()
        defer { lock.unlock() }
        return formatTemplates[format] ?? TarArchiveEngineTemplate()
    }

    /// Dynamically selects the optimal template implementation based on path extension and operation type.
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

    /// Executes the template method workflow synchronously.
    public func executeWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult {
        let tpl = template(forPath: context.archivePath, operation: context.operation)
        return try tpl.performWorkflow(context: context)
    }

    /// Executes the template method workflow asynchronously.
    public func executeWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        let tpl = template(forPath: context.archivePath, operation: context.operation)
        return try await tpl.performWorkflowAsync(context: context)
    }
}
