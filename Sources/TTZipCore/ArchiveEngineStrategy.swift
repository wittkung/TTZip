// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Strategy Pattern & Bridge Pattern: Unified interface for format-specific compression and extraction strategies.
public protocol ArchiveFormatEngineStrategy: Sendable {
    /// Format supported by this strategy.
    var format: ArchiveCompressionFormat { get }
    
    /// Associated Bridge Pattern implementor.
    var bridgeImplementor: ArchiveEngineImplementorProtocol { get }

    /// Associated Template Method Pattern workflow engine.
    var engineTemplate: BaseArchiveEngineTemplate { get }
    
    /// Checks whether this strategy can process the given filesystem path.
    func canHandle(path: String) -> Bool
    
    /// Executes extraction workflow.
    func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool
    
    /// Executes compression workflow.
    func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool
}

/// Central registry for format engine strategies.
public final class ArchiveEngineRegistry: @unchecked Sendable {
    public static let shared = ArchiveEngineRegistry()
    private let lock = NSLock()
    private var strategies: [ArchiveFormatEngineStrategy] = []
    
    private init() {
        registerDefaultStrategies()
    }
    
    private func registerDefaultStrategies() {
        strategies = [
            ZipFormatEngineStrategy(),
            SevenZipFormatEngineStrategy(),
            TarFormatEngineStrategy(),
            ZstdFormatEngineStrategy()
        ]
    }
    
    /// Registers a new format strategy.
    public func register(strategy: ArchiveFormatEngineStrategy) {
        lock.lock()
        defer { lock.unlock() }
        strategies.append(strategy)
    }
    
    /// Finds a registered extraction strategy capable of handling the target path.
    public func findExtractor(for path: String) -> ArchiveFormatEngineStrategy? {
        lock.lock()
        defer { lock.unlock() }
        return strategies.first(where: { $0.canHandle(path: path) })
    }
    
    /// Recommends the optimal compression strategy based on workload characteristics and hardware topology.
    public func selectOptimalCompressionStrategy(
        inputPaths: [String],
        targetFormat: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel = .normal
    ) -> CompressionStrategyProtocol {
        return CompressionStrategyContext.shared.selectOptimalStrategy(
            inputPaths: inputPaths,
            targetFormat: targetFormat,
            level: level
        )
    }
}

// MARK: - Concrete Format Engine Strategies

private final class StrategySyncBox<T>: @unchecked Sendable {
    var value: T?
    var error: Error?
}

private func executeStrategyBridgeSync<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
    let box = StrategySyncBox<T>()
    let sema = DispatchSemaphore(value: 0)
    Task.detached {
        do {
            box.value = try await block()
        } catch {
            box.error = error
        }
        sema.signal()
    }
    sema.wait()
    if let val = box.value { return val }
    if let err = box.error { throw err }
    throw ArchiveError.readFailed(code: -999)
}

/// ZIP format engine strategy implementation.
public final class ZipFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .zip
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .zip),
        engineTemplate: BaseArchiveEngineTemplate = ZipArchiveEngineTemplate()
    ) {
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".zip") || lower.hasSuffix(".jar") || lower.hasSuffix(".apk") || lower.hasSuffix(".epub") || lower.hasSuffix(".docx") || lower.hasSuffix(".xlsx")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: ArchiveCompressionFormat.zip,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: ArchiveCompressionFormat.zip,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}

/// 7z format engine strategy implementation.
public final class SevenZipFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .sevenZip
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .sevenZip),
        engineTemplate: BaseArchiveEngineTemplate = SevenZipArchiveEngineTemplate()
    ) {
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { lower.hasSuffix($0) }) || lower.contains(".7z.")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: ArchiveCompressionFormat.sevenZip,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: ArchiveCompressionFormat.sevenZip,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}

/// TAR and derivative formats engine strategy implementation.
public final class TarFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        format: ArchiveCompressionFormat = .tar,
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .tar),
        engineTemplate: BaseArchiveEngineTemplate = TarArchiveEngineTemplate()
    ) {
        self.format = format
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { lower.hasSuffix($0) })
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: format,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: format,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}

/// Zstandard (zst) format engine strategy implementation.
public final class ZstdFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .zst
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    public let engineTemplate: BaseArchiveEngineTemplate
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .zst),
        engineTemplate: BaseArchiveEngineTemplate = TarArchiveEngineTemplate()
    ) {
        self.bridgeImplementor = bridgeImplementor
        self.engineTemplate = engineTemplate
    }
    
    public func canHandle(path: String) -> Bool {
        return path.lowercased().hasSuffix(".zst")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.extract,
            archivePath: archivePath,
            destinationDir: destinationDir,
            format: ArchiveCompressionFormat.zst,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let context = ArchiveTemplateContext(
            operation: ArchiveOperationType.compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: ArchiveCompressionFormat.zst,
            level: level,
            password: password,
            options: options
        )
        let res = try engineTemplate.performWorkflow(context: context)
        return res.isSuccess
    }
}
