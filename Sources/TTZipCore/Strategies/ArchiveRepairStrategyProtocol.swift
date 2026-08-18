// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Corrupted archive salvage and structural repair strategy interface (Strategy Pattern).
public protocol ArchiveRepairStrategyProtocol: Sendable {
    /// Strategy name.
    var repairStrategyName: String { get }
    
    /// Inspects damaged file characteristics to determine repair applicability.
    func canRepair(damagedArchivePath: String) async -> Bool
    
    /// Executes stream salvage and structural rebuild, returning count of recovered items.
    func repair(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int
}

// MARK: - Concrete Archive Repair Strategies

/// 1. ZIP central directory reconstruction and local header scanner strategy (`ZipCentralDirectoryReconstructionStrategy`).
public final class ZipCentralDirectoryReconstructionStrategy: ArchiveRepairStrategyProtocol {
    public let repairStrategyName: String = "ZIP Central Directory Reconstruction Strategy"
    
    public init() {}
    
    public func canRepair(damagedArchivePath: String) async -> Bool {
        let pathLower = damagedArchivePath.lowercased()
        if pathLower.hasSuffix(".zip") || pathLower.hasSuffix(".jar") || pathLower.hasSuffix(".docx") {
            return true
        }
        guard let fileHandle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: damagedArchivePath)) else { return false }
        defer { try? fileHandle.close() }
        let headerData = (try? fileHandle.read(upToCount: 4)) ?? Data()
        return headerData.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }
    
    public func repair(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: damagedArchivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("repair_zip_\(UUID().uuidString)").path
            try? fileManager.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(atPath: tempDir) }
            
            let extractor = ArchiveEngineFactory.makeExtractor()
            _ = try? extractor.extractSync(archivePath: damagedArchivePath, destinationDir: tempDir, options: .defaultClean, password: nil)
            
            var recoveredItems = (try? fileManager.contentsOfDirectory(atPath: tempDir)) ?? []
            
            if recoveredItems.isEmpty, let fileData = try? Data(contentsOf: URL(fileURLWithPath: damagedArchivePath)) {
                Self.salvageZipLocalHeaders(fileData: fileData, outputDir: tempDir)
                recoveredItems = (try? fileManager.contentsOfDirectory(atPath: tempDir)) ?? []
            }
            
            let fullPaths = recoveredItems.map { (tempDir as NSString).appendingPathComponent($0) }
            
            if !fullPaths.isEmpty {
                let writer = ArchiveEngineFactory.makeWriter(for: .zip)
                _ = try writer.createArchiveSync(outputPath: repairedOutputPath, format: .zip, level: .normal, inputPaths: fullPaths, options: .defaultClean, password: nil)
            }
            
            return recoveredItems.count
        }.value
    }
    
    private static func salvageZipLocalHeaders(fileData: Data, outputDir: String) {
        fileData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress, rawBuffer.count >= 30 else { return }
            let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
            let totalCount = rawBuffer.count
            let signature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
            var offset = 0
            
            while offset + 30 <= totalCount {
                if bytes[offset] == signature[0] &&
                    bytes[offset + 1] == signature[1] &&
                    bytes[offset + 2] == signature[2] &&
                    bytes[offset + 3] == signature[3] {
                    
                    let compSize32 = UInt32(bytes[offset + 18]) |
                                     (UInt32(bytes[offset + 19]) << 8) |
                                     (UInt32(bytes[offset + 20]) << 16) |
                                     (UInt32(bytes[offset + 21]) << 24)
                    let compSize = Int(compSize32)
                    
                    let fnLen = Int(UInt16(bytes[offset + 26]) | (UInt16(bytes[offset + 27]) << 8))
                    let extraLen = Int(UInt16(bytes[offset + 28]) | (UInt16(bytes[offset + 29]) << 8))
                    
                    let headerTotalLen = 30 + fnLen + extraLen
                    if fnLen > 0 && offset + headerTotalLen <= totalCount {
                        let fnBytes = UnsafeBufferPointer(start: bytes + offset + 30, count: fnLen)
                        let fnData = Data(fnBytes)
                        let rawNameStr = String(data: fnData, encoding: .utf8) ?? String(data: fnData, encoding: .ascii)
                        if let rawName = rawNameStr, !rawName.isEmpty, !rawName.hasSuffix("/") {
                            let cleanName = (rawName as NSString).lastPathComponent.trimmingCharacters(in: .controlCharacters)
                            let finalName = cleanName.isEmpty ? "salvaged_\(offset).bin" : cleanName
                            let destPath = (outputDir as NSString).appendingPathComponent(finalName)
                            
                            let payloadStart = offset + headerTotalLen
                            let maxPayloadLen = max(0, totalCount - payloadStart)
                            let actualPayloadLen = min(compSize, maxPayloadLen)
                            if actualPayloadLen > 0 {
                                let payloadBytes = UnsafeBufferPointer(start: bytes + payloadStart, count: actualPayloadLen)
                                let payloadData = Data(payloadBytes)
                                try? payloadData.write(to: URL(fileURLWithPath: destPath))
                            }
                        }
                    }
                    
                    let validCompSize = (compSize >= 0 && compSize <= totalCount) ? compSize : 0
                    let jumpOffset = 30 + fnLen + extraLen + validCompSize
                    offset += max(1, jumpOffset)
                } else {
                    offset += 1
                }
            }
        }
    }
}

/// 2. TAR truncated stream fault-tolerant salvage strategy (`TarTruncatedSalvageStrategy`).
public final class TarTruncatedSalvageStrategy: ArchiveRepairStrategyProtocol {
    public let repairStrategyName: String = "TAR Truncated Stream Salvage Strategy"
    
    public init() {}
    
    public func canRepair(damagedArchivePath: String) async -> Bool {
        let lower = damagedArchivePath.lowercased()
        return ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { lower.hasSuffix($0) })
    }
    
    public func repair(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: damagedArchivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("repair_tar_\(UUID().uuidString)").path
            try? fileManager.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(atPath: tempDir) }
            
            let extractor = ArchiveEngineFactory.makeExtractor()
            _ = try? extractor.extractSync(archivePath: damagedArchivePath, destinationDir: tempDir, options: .defaultClean, password: nil)
            
            var recoveredItems = (try? fileManager.contentsOfDirectory(atPath: tempDir)) ?? []
            
            if recoveredItems.isEmpty, let fileData = try? Data(contentsOf: URL(fileURLWithPath: damagedArchivePath)) {
                Self.salvageTarBlocks(fileData: fileData, outputDir: tempDir)
                recoveredItems = (try? fileManager.contentsOfDirectory(atPath: tempDir)) ?? []
            }
            
            let fullPaths = recoveredItems.map { (tempDir as NSString).appendingPathComponent($0) }
            
            if !fullPaths.isEmpty {
                let writer = ArchiveEngineFactory.makeWriter(for: .tar)
                _ = try writer.createArchiveSync(outputPath: repairedOutputPath, format: .tar, level: .store, inputPaths: fullPaths, options: .defaultClean, password: nil)
            }
            
            return recoveredItems.count
        }.value
    }
    
    private static func salvageTarBlocks(fileData: Data, outputDir: String) {
        fileData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress, rawBuffer.count >= 512 else { return }
            let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
            let totalCount = rawBuffer.count
            var offset = 0
            
            while offset + 512 <= totalCount {
                let blockBytes = bytes + offset
                var nameLen = 0
                while nameLen < 100 && blockBytes[nameLen] != 0 {
                    nameLen += 1
                }
                
                if nameLen > 0 {
                    let nameData = Data(bytes: blockBytes, count: nameLen)
                    if let rawName = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters), !rawName.isEmpty {
                        let sizeData = Data(bytes: blockBytes + 124, count: 12)
                        let sizeStr = String(data: sizeData, encoding: .ascii)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? "0"
                        
                        let parsedSize = Int(sizeStr, radix: 8) ?? 0
                        let fileSize = max(0, min(parsedSize, 10_000_000_000))
                        
                        let payloadStart = offset + 512
                        let cleanName = (rawName as NSString).lastPathComponent.trimmingCharacters(in: .controlCharacters)
                        if !cleanName.isEmpty {
                            let destPath = (outputDir as NSString).appendingPathComponent(cleanName)
                            let actualLen = min(fileSize, max(0, totalCount - payloadStart))
                            if actualLen > 0 {
                                let payloadData = Data(bytes: bytes + payloadStart, count: actualLen)
                                try? payloadData.write(to: URL(fileURLWithPath: destPath))
                            }
                        }
                        
                        let blocks = (fileSize + 511) / 512
                        let jump = 512 + (blocks * 512)
                        offset += max(512, jump)
                        continue
                    }
                }
                offset += 512
            }
        }
    }
}

/// 3. 7-Zip magic header and stream block repair strategy (`SevenZipMagicHeaderRepairStrategy`).
public final class SevenZipMagicHeaderRepairStrategy: ArchiveRepairStrategyProtocol {
    public let repairStrategyName: String = "7-Zip Magic Header & Block Repair Strategy"
    
    public init() {}
    
    public func canRepair(damagedArchivePath: String) async -> Bool {
        let lower = damagedArchivePath.lowercased()
        if ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { lower.hasSuffix($0) }) {
            return true
        }
        guard let fileHandle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: damagedArchivePath)) else { return false }
        defer { try? fileHandle.close() }
        let headerData = (try? fileHandle.read(upToCount: 6)) ?? Data()
        return headerData == Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
    }
    
    public func repair(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: damagedArchivePath) else {
            throw ArchiveError.fileNotFound
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("repair_7z_\(UUID().uuidString)").path
            try? fileManager.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(atPath: tempDir) }
            
            let extractor = ArchiveEngineFactory.makeExtractor()
            _ = try? extractor.extractSync(archivePath: damagedArchivePath, destinationDir: tempDir, options: .defaultClean, password: nil)
            
            let recoveredItems = (try? fileManager.contentsOfDirectory(atPath: tempDir)) ?? []
            let fullPaths = recoveredItems.map { (tempDir as NSString).appendingPathComponent($0) }
            
            if !fullPaths.isEmpty {
                let writer = ArchiveEngineFactory.makeWriter(for: .sevenZip)
                _ = try writer.createArchiveSync(outputPath: repairedOutputPath, format: .sevenZip, level: .normal, inputPaths: fullPaths, options: .defaultClean, password: nil)
            }
            
            return recoveredItems.count
        }.value
    }
}

// MARK: - Archive Repair Strategy Context

/// Coordinator selecting and executing archive repair strategies.
public final class ArchiveRepairStrategyContext: @unchecked Sendable {
    public static let shared = ArchiveRepairStrategyContext()
    private let lock = NSLock()
    private var strategies: [ArchiveRepairStrategyProtocol] = []
    
    private init() {
        registerDefaultStrategies()
    }
    
    private func registerDefaultStrategies() {
        strategies = [
            ZipCentralDirectoryReconstructionStrategy(),
            TarTruncatedSalvageStrategy(),
            SevenZipMagicHeaderRepairStrategy()
        ]
    }
    
    public func register(strategy: ArchiveRepairStrategyProtocol) {
        lock.lock()
        defer { lock.unlock() }
        strategies.append(strategy)
    }
    
    private func getStrategies() -> [ArchiveRepairStrategyProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return strategies
    }
    
    /// Matches the most suitable repair strategy for a damaged archive.
    public func selectStrategy(for damagedArchivePath: String) async -> ArchiveRepairStrategyProtocol {
        let currentStrategies = getStrategies()
        
        for strategy in currentStrategies {
            if await strategy.canRepair(damagedArchivePath: damagedArchivePath) {
                return strategy
            }
        }
        return currentStrategies.first ?? ZipCentralDirectoryReconstructionStrategy()
    }
    
    /// Repairs damaged archive using selected strategy.
    public func repairArchive(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let strategy = await selectStrategy(for: damagedArchivePath)
        return try await strategy.repair(damagedArchivePath: damagedArchivePath, repairedOutputPath: repairedOutputPath)
    }
}
