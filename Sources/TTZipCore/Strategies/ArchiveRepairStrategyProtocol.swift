import Foundation

/// 【3.1 策略模式】损坏归档修复与数据拯救策略接口协议
public protocol ArchiveRepairStrategyProtocol: Sendable {
    /// 策略显示名称
    var repairStrategyName: String { get }
    
    /// 探查归档文件特征，判断本策略是否可用于修复该损坏归档
    func canRepair(damagedArchivePath: String) async -> Bool
    
    /// 执行数据拯救与重构，返回成功挽救的有效条目数量
    func repair(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int
}

// MARK: - 具体损坏归档修复策略实现 (Concrete Archive Repair Strategies)

/// 1. Zip 中央目录重构与标头扫描修复策略 (`ZipCentralDirectoryReconstructionStrategy`)
public final class ZipCentralDirectoryReconstructionStrategy: ArchiveRepairStrategyProtocol {
    public let repairStrategyName: String = "Zip 中央目录重构与标头扫描策略"
    
    public init() {}
    
    public func canRepair(damagedArchivePath: String) async -> Bool {
        let pathLower = damagedArchivePath.lowercased()
        if pathLower.hasSuffix(".zip") || pathLower.hasSuffix(".jar") || pathLower.hasSuffix(".docx") {
            return true
        }
        // 尝试读取前 4 字节判断 local file header 魔数 (0x04034b50 / PK\x03\x04)
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
            
            // 如果标准解包失败/只救回 0 个条目（如 End of Central Directory 被物理截断），执行 Raw Local File Header 字节补救
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

/// 2. Tar 截断流容错拯救策略 (`TarTruncatedSalvageStrategy`)
public final class TarTruncatedSalvageStrategy: ArchiveRepairStrategyProtocol {
    public let repairStrategyName: String = "Tar 截断流容错拯救策略"
    
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
            
            // 如果标准解包归档已截断导致提取失败，启动 POSIX Tar Block Header 分片扫频补救
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

/// 3. 7-Zip Magic Header 与数据块修复策略 (`SevenZipMagicHeaderRepairStrategy`)
public final class SevenZipMagicHeaderRepairStrategy: ArchiveRepairStrategyProtocol {
    public let repairStrategyName: String = "7-Zip Magic Header 与块修复策略"
    
    public init() {}
    
    public func canRepair(damagedArchivePath: String) async -> Bool {
        let lower = damagedArchivePath.lowercased()
        if ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { lower.hasSuffix($0) }) {
            return true
        }
        // 7z 魔数判断 `7z\xBC\xAF\x27\x1C`
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

/// 损坏归档修复策略调配上下文 (`ArchiveRepairStrategyContext`)
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
    
    /// 匹配最适合修复给用损坏归档的策略
    public func selectStrategy(for damagedArchivePath: String) async -> ArchiveRepairStrategyProtocol {
        let currentStrategies = getStrategies()
        
        for strategy in currentStrategies {
            if await strategy.canRepair(damagedArchivePath: damagedArchivePath) {
                return strategy
            }
        }
        return currentStrategies.first ?? ZipCentralDirectoryReconstructionStrategy()
    }
    
    /// 使用匹配策略修复损坏归档
    public func repairArchive(damagedArchivePath: String, repairedOutputPath: String) async throws -> Int {
        let strategy = await selectStrategy(for: damagedArchivePath)
        return try await strategy.repair(damagedArchivePath: damagedArchivePath, repairedOutputPath: repairedOutputPath)
    }
}
