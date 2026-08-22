// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Strategy Pattern: Unified interface for format-specific compression and extraction strategies.
public protocol ArchiveFormatEngineStrategy: Sendable {
    /// Format supported by this strategy.
    var format: ArchiveCompressionFormat { get }
    
    /// Associated Bridge Pattern implementor.
    var bridgeImplementor: ArchiveEngineImplementorProtocol { get }
    
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

/// ZIP format engine strategy implementation.
public final class ZipFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .zip
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .zip)
    ) {
        self.bridgeImplementor = bridgeImplementor
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".zip") || lower.hasSuffix(".zipx") || lower.hasSuffix(".aar") || lower.hasSuffix(".epub") || lower.hasSuffix(".docx") || lower.hasSuffix(".xlsx")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: archivePath, destinationDir: destinationDir, options: options, password: password)
        return true
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let writer = ArchiveWriter()
        try writer.createArchiveSync(outputPath: outputPath, format: .zip, level: level, inputPaths: inputPaths, options: options, password: password)
        return true
    }
}

/// 7z format engine strategy implementation.
public final class SevenZipFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .sevenZip
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .sevenZip)
    ) {
        self.bridgeImplementor = bridgeImplementor
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { lower.hasSuffix($0) }) || lower.contains(".7z.")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: archivePath, destinationDir: destinationDir, options: options, password: password)
        return true
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let writer = ArchiveWriter()
        try writer.createArchiveSync(outputPath: outputPath, format: .sevenZip, level: level, inputPaths: inputPaths, options: options, password: password)
        return true
    }
}

/// TAR and derivative formats engine strategy implementation.
public final class TarFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    
    public init(
        format: ArchiveCompressionFormat = .tar,
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .tar)
    ) {
        self.format = format
        self.bridgeImplementor = bridgeImplementor
    }
    
    public func canHandle(path: String) -> Bool {
        let lower = path.lowercased()
        return ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { lower.hasSuffix($0) })
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: archivePath, destinationDir: destinationDir, options: options, password: password)
        return true
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let writer = ArchiveWriter()
        try writer.createArchiveSync(outputPath: outputPath, format: format, level: level, inputPaths: inputPaths, options: options, password: password)
        return true
    }
}

/// Zstandard (zst) format engine strategy implementation.
public final class ZstdFormatEngineStrategy: ArchiveFormatEngineStrategy {
    public let format: ArchiveCompressionFormat = .zst
    public let bridgeImplementor: ArchiveEngineImplementorProtocol
    
    public init(
        bridgeImplementor: ArchiveEngineImplementorProtocol = ArchiveEngineFactory.makeImplementor(for: .zst)
    ) {
        self.bridgeImplementor = bridgeImplementor
    }
    
    public func canHandle(path: String) -> Bool {
        return path.lowercased().hasSuffix(".zst")
    }
    
    public func extract(archivePath: String, destinationDir: String, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let extractor = ArchiveExtractor()
        try extractor.extractSync(archivePath: archivePath, destinationDir: destinationDir, options: options, password: password)
        return true
    }
    
    public func compress(outputPath: String, inputPaths: [String], level: ArchiveCompressionLevel, options: ArchiveFilterOptions, password: String?) throws -> Bool {
        let writer = ArchiveWriter()
        try writer.createArchiveSync(outputPath: outputPath, format: .zst, level: level, inputPaths: inputPaths, options: options, password: password)
        return true
    }
}
