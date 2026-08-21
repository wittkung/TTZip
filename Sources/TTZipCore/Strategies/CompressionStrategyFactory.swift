// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Strategy Context & Factory

/// Dynamic compression strategy selector and coordinator (Strategy Context).
public final class CompressionStrategyContext: @unchecked Sendable {
    public static let shared = CompressionStrategyContext()
    private let lock = NSLock()
    private var strategies: [CompressionStrategyProtocol] = []
    
    private init() {
        registerDefaultStrategies()
    }
    
    private func registerDefaultStrategies() {
        strategies = [
            StoreStrategy(),
            SevenZipStrategy(),
            ZstdStrategy(),
            POSIXTarStrategy(),
            AppleSiliconLZFSEStrategy(),
            LibdeflateCompressionStrategy()
        ]
    }
    
    /// Registers custom compression strategy.
    public func register(strategy: CompressionStrategyProtocol) {
        lock.lock()
        defer { lock.unlock() }
        strategies.append(strategy)
    }
    
    /// Registered compression strategies.
    public var currentStrategies: [CompressionStrategyProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return strategies
    }
    
    /// Dynamically selects optimal compression strategy based on payload size, extension profile, and chip topology.
    public func selectOptimalStrategy(
        inputPaths: [String],
        targetFormat: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel = .normal
    ) -> CompressionStrategyProtocol {
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Explicit store level
        if level == .store {
            if let storeStrategy = strategies.first(where: { $0 is StoreStrategy }) {
                return storeStrategy
            }
        }
        
        // 2. Sample payload metadata
        var totalBytes: Int64 = 0
        var extensions: [String] = []
        let fm = FileManager.default
        
        for path in inputPaths {
            let ext = (path as NSString).pathExtension.lowercased()
            if !ext.isEmpty {
                extensions.append(".\(ext)")
            }
            if let attrs = try? fm.attributesOfItem(atPath: path) {
                if (attrs[.type] as? FileAttributeType) == .typeDirectory {
                    let tree = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: path)
                    totalBytes += tree.sizeBytes
                    let (totalCount, preCount) = tree.sampleLeafExtensions(maxSamples: 2000, preCompressedSet: StoreStrategy.preCompressedExtensions)
                    if totalCount > 0 && Double(preCount) / Double(totalCount) >= 0.5 {
                        extensions.append(".mp4")
                    }
                } else {
                    totalBytes += (attrs[.size] as? Int64) ?? 0
                }
            }
        }
        
        // 3. Match format-specialized strategies
        if targetFormat == .sevenZip {
            if let s = strategies.first(where: { $0 is SevenZipStrategy }) { return s }
        } else if targetFormat == .zst || targetFormat == .tarZst {
            if let s = strategies.first(where: { $0 is ZstdStrategy }) { return s }
        } else if targetFormat == .tar {
            if let s = strategies.first(where: { $0 is POSIXTarStrategy }) { return s }
        }
        
        // 4. Evaluate candidates
        for strategy in strategies {
            if strategy.canHandle(payloadBytes: totalBytes, inputExtensions: extensions, targetFormat: targetFormat) {
                return strategy
            }
        }
        
        // 5. Default fallback
        return strategies.first(where: { $0.supportedFormat == targetFormat && !($0 is StoreStrategy) })
            ?? strategies.first(where: { $0 is LibdeflateCompressionStrategy })
            ?? StoreStrategy()
    }
    
    /// Executes optimal compression strategy for given inputs.
    public func executeCompress(
        inputPaths: [String],
        outputPath: String,
        targetFormat: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        options: ArchiveFilterOptions,
        password: String?
    ) throws -> Bool {
        let strategy = selectOptimalStrategy(inputPaths: inputPaths, targetFormat: targetFormat, level: level)
        return try strategy.compress(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            options: options,
            password: password
        )
    }
}

/// Compression strategy factory helper providing unified strategy instantiations.
public enum CompressionStrategyFactory {
    /// Creates a strategy instance matching the given strategy ID.
    public static func makeStrategy(for strategyId: String) -> CompressionStrategyProtocol? {
        switch strategyId.lowercased() {
        case "libdeflate":
            return LibdeflateCompressionStrategy()
        case "apple_silicon_lzfse", "lzfse":
            return AppleSiliconLZFSEStrategy()
        case "zstd":
            return ZstdStrategy()
        case "seven_zip", "7z":
            return SevenZipStrategy()
        case "posix_tar", "tar":
            return POSIXTarStrategy()
        case "store_bypass", "store":
            return StoreStrategy()
        default:
            return nil
        }
    }
    
    /// Creates the default strategy for a given archive compression format.
    public static func makeStrategy(for format: ArchiveCompressionFormat) -> CompressionStrategyProtocol {
        switch format {
        case .sevenZip:
            return SevenZipStrategy()
        case .zst, .tarZst:
            return ZstdStrategy()
        case .tar:
            return POSIXTarStrategy()
        default:
            return LibdeflateCompressionStrategy()
        }
    }
}
