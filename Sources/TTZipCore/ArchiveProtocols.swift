// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 3-Tier archive encryption classification topology.
public enum ArchiveEncryptionTier: String, Sendable, Codable, Equatable {
    /// Tier 0: Unencrypted archive.
    case none = "NONE"
    /// Tier 1: Entry payloads are encrypted, but metadata headers remain in cleartext (browsable without password).
    case dataOnly = "DATA_ONLY"
    /// Tier 2: Both metadata headers and entry payloads are encrypted (password required to list directory tree).
    case headerAndData = "HEADER_AND_DATA"
    /// Encryption status cannot be reliably determined or is unsupported.
    case unsupported = "UNSUPPORTED"
}

/// Core archive inspection and metadata discovery interface.
public protocol ArchiveReading: Sendable {
    /// Inspects archive contents and returns a flat array of archive entries.
    func inspect(archivePath: String) async throws -> [ArchiveEntry]
    
    /// Inspects archive contents with optional password or candidate password list.
    func inspect(archivePath: String, password: String?, candidatePasswords: [String]?) async throws -> [ArchiveEntry]
    
    /// Asynchronously inspects archive and returns a hierarchical directory tree (Composite Pattern).
    func inspectTree(archivePath: String, password: String?, candidatePasswords: [String]?) async throws -> ArchiveCompositeDirectory
    
    /// Fast zero-decompression probe of archive encryption tier.
    func probeEncryption(archivePath: String) async throws -> ArchiveEncryptionTier
}

extension ArchiveReading {
    /// Convenience facade method to list entries of an archive.
    @inline(__always)
    public func listEntries(archivePath: String, password: String? = nil) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
    }
}

/// Core archive creation and compression engine interface.
public protocol ArchiveWriting: Sendable {
    func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws

    func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        password: String?,
        splitVolumeSizeBytes: Int64?,
        advancedOptions: ArchiveAdvancedOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws
}

/// Core archive decompression and extraction engine interface.
public protocol ArchiveExtracting: Sendable {
    func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions?
    ) async throws

    func extractSingleFile(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String?
    ) async throws
    
    func extractSync(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions?
    ) throws

    func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool
}

extension ArchiveExtracting {
    /// Convenience facade method to extract an archive.
    @inline(__always)
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws {
        try await extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        )
    }
}

/// Archive data integrity and checksum verification interface.
public protocol ArchiveIntegrityChecking: Sendable {
    func computeCRC32(filePath: String) -> String
    func computeSHA256(filePath: String) async throws -> String
    @discardableResult
    func verifyExtractedDirectory(
        directoryPath: String,
        expectedOriginalBytes: Int64,
        sourceFilePath: String?,
        sourceCRC32: String?,
        label: String
    ) -> (isValid: Bool, totalExtractedBytes: Int64, crc32: String?)
}

/// Cryptographic hash calculation interface.
public protocol HashCalculating: Sendable {
    func computeHashSync(filePath: String, type: HashType) throws -> String
    func computeHash(filePath: String, type: HashType) async throws -> String
}

/// ZIP format hardware-accelerated encryption and decryption engine interface.
public protocol ZipCryptoEngineProtocol: Sendable {
    func decryptZipCrypto(payload: Data, password: String) -> Data?
    func encryptAES256(payload: Data, password: String, actualCompressionMethod: UInt16) -> (payload: Data, compressionMethod: UInt16, extraField: Data)?
    func decryptAES256(payloadPtr: UnsafePointer<UInt8>, count: Int, password: String) -> Data?
    func decryptAES256Direct(payloadPtr: UnsafePointer<UInt8>, count: Int, password: String, destinationPtr: UnsafeMutablePointer<UInt8>) -> Bool
    func decryptAES256(payload: Data, password: String) -> Data?
}

/// 7z format PBKDF2-SHA256 and AES-256-CBC engine interface.
public protocol SevenZipCryptoEngineProtocol: Sendable {
    func deriveKey(password: String, salt: Data, numCyclesPower: Int) -> Data
    func processParallelAES256(
        inputData: Data,
        key: Data,
        iv: Data,
        encrypt: Bool,
        chunkSize: Int
    ) -> Data?
}

// MARK: - Progress

//
//


/// Archive operation type classification.
public enum ArchiveOperationType: String, Sendable, Equatable, CaseIterable {
    case compress = "Compress"
    case extract = "Extract"
    case repair = "Repair"
    case batch = "Batch"
    case recover = "PasswordRecovery"
    case inspect = "Inspect"
}

/// Real-time progress and telemetry metadata for archiving operations.
public struct ArchiveProgress: Sendable {
    /// Progress lifecycle states.
    public enum State: Sendable, Equatable {
        case idle
        case processing
        case completed
        case cancelled
        case failed(error: String)
    }
    
    /// Current execution state.
    public let state: State
    /// Number of bytes processed so far.
    public let bytesProcessed: Int64
    /// Total byte size of expected workload.
    public let totalBytes: Int64
    /// Name or path of file currently being compressed or extracted.
    public let currentFileName: String
    /// Monotonic throughput calculation in MB/s.
    public let throughputMBs: Double
    
    /// Normalized fraction completed (0.0 to 1.0).
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesProcessed) / Double(totalBytes)))
    }
    
    public init(
        state: State = .idle,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        currentFileName: String = "",
        throughputMBs: Double = 0.0
    ) {
        self.state = state
        self.bytesProcessed = max(0, bytesProcessed)
        self.totalBytes = max(0, totalBytes)
        self.currentFileName = currentFileName
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
    }
    
    public static let zero = ArchiveProgress()
}

/// Detailed progress data packet delivered to archive progress observers.
public struct ArchiveProgressInfo: Sendable, Equatable {
    public let state: ArchiveProgress.State
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let currentFileName: String
    public let throughputMBs: Double
    public let estimatedTimeRemaining: TimeInterval?
    public let operationType: ArchiveOperationType
    
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesProcessed) / Double(totalBytes)))
    }
    
    public init(
        state: ArchiveProgress.State = .processing,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        currentFileName: String = "",
        throughputMBs: Double = 0.0,
        estimatedTimeRemaining: TimeInterval? = nil,
        operationType: ArchiveOperationType = .compress
    ) {
        self.state = state
        self.bytesProcessed = max(0, bytesProcessed)
        self.totalBytes = max(0, totalBytes)
        self.currentFileName = currentFileName
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
        if let eta = estimatedTimeRemaining, !eta.isNaN, !eta.isInfinite, eta >= 0 {
            self.estimatedTimeRemaining = eta
        } else {
            self.estimatedTimeRemaining = nil
        }
        self.operationType = operationType
    }
}

/// Progress data packet delivered to multi-file and batch task observers.
public struct BatchProgressInfo: Sendable, Equatable {
    public let completedTasks: Int
    public let totalTasks: Int
    public let currentTaskPath: String
    public let totalBytesProcessed: Int64
    public let totalBytesCount: Int64
    public let throughputMBs: Double
    public let estimatedTimeRemaining: TimeInterval?
    
    public var fractionCompleted: Double {
        guard totalTasks > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(completedTasks) / Double(totalTasks)))
    }
    
    public init(
        completedTasks: Int,
        totalTasks: Int,
        currentTaskPath: String = "",
        totalBytesProcessed: Int64 = 0,
        totalBytesCount: Int64 = 0,
        throughputMBs: Double = 0.0,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.completedTasks = max(0, completedTasks)
        self.totalTasks = max(0, totalTasks)
        self.currentTaskPath = currentTaskPath
        self.totalBytesProcessed = max(0, totalBytesProcessed)
        self.totalBytesCount = max(0, totalBytesCount)
        self.throughputMBs = (throughputMBs.isNaN || throughputMBs.isInfinite || throughputMBs < 0) ? 0.0 : throughputMBs
        if let eta = estimatedTimeRemaining, !eta.isNaN, !eta.isInfinite, eta >= 0 {
            self.estimatedTimeRemaining = eta
        } else {
            self.estimatedTimeRemaining = nil
        }
    }
}

/// Archive progress observer protocol.
public protocol ArchiveProgressObserverProtocol: AnyObject, Sendable {
    func onProgressUpdated(_ progress: ArchiveProgressInfo)
    func onBatchProgressUpdated(_ progress: BatchProgressInfo)
}

extension ArchiveProgressObserverProtocol {
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {}
    public func onBatchProgressUpdated(_ progress: BatchProgressInfo) {}
}

/// System-wide global archive event type.
public enum ArchiveEventType: String, Sendable, Equatable, Hashable, CaseIterable {
    case archiveCompleted
    case extractionFailed
    case securityThreatIntercepted
    case passwordVaultUnlocked
    case presetChanged
    case taskStateChanged
}

/// System-wide global archive event payload data.
public enum ArchiveEvent: Sendable, Equatable {
    case archiveCompleted(archivePath: String, operationType: ArchiveOperationType, duration: TimeInterval, totalBytes: Int64)
    case extractionFailed(archivePath: String, error: String)
    case securityThreatIntercepted(archivePath: String, threatDescription: String)
    case passwordVaultUnlocked(archivePath: String, password: String, isVaultUnlocked: Bool)
    case presetChanged(oldPresetName: String?, newPresetName: String)
    case taskStateChanged(taskId: UUID, oldState: String, newState: String)
    
    public var eventType: ArchiveEventType {
        switch self {
        case .archiveCompleted: return .archiveCompleted
        case .extractionFailed: return .extractionFailed
        case .securityThreatIntercepted: return .securityThreatIntercepted
        case .passwordVaultUnlocked: return .passwordVaultUnlocked
        case .presetChanged: return .presetChanged
        case .taskStateChanged: return .taskStateChanged
        }
    }
    
    public var archivePath: String? {
        switch self {
        case .archiveCompleted(let path, _, _, _): return path
        case .extractionFailed(let path, _): return path
        case .securityThreatIntercepted(let path, _): return path
        case .passwordVaultUnlocked(let path, _, _): return path
        case .presetChanged, .taskStateChanged: return nil
        }
    }
}

/// System-wide global archive event observer protocol.
public protocol ArchiveEventObserverProtocol: AnyObject, Sendable {
    func onArchiveEvent(_ event: ArchiveEvent)
}

// MARK: - Factory

//
//


/// Unified factory providing standard writers, extractors, readers, and C-ABI bridge implementors.
public enum ArchiveEngineFactory {
    
    /// Creates an archive writer.
    public static func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return ArchiveWriter()
    }
    
    /// Creates an archive extractor.
    public static func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return ArchiveExtractor()
    }
    
    /// Creates an archive reader.
    public static func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return ArchiveReader()
    }

    /// Creates an integrity checker engine instance.
    public static func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return ArchiveIntegrityChecker()
    }

    /// Creates a cryptographic hash calculator instance.
    public static func makeHashCalculator(hardwareTuner: HardwareTunerProtocol? = nil) -> HashCalculating {
        return HashCalculator(hardwareTuner: hardwareTuner ?? AppleSiliconTuner.shared)
    }

    /// Creates a low-level engine implementor for Bridge Pattern decoupling.
    public static func makeImplementor(for format: ArchiveCompressionFormat = .zip) -> ArchiveEngineImplementorProtocol {
        return ArchiveEngineBridge.makeImplementor(for: format)
    }

    /// Creates a decorated engine implementor.
    public static func makeDecoratedImplementor(
        for format: ArchiveCompressionFormat = .zip,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil,
        enableChecksum: Bool = false,
        enableMetrics: Bool = false
    ) -> ArchiveEngineImplementorProtocol {
        return makeImplementor(for: format)
    }

    /// Constructs high-level `ArchiveOperationAbstraction` with an implementor.
    public static func makeOperationAbstraction(for format: ArchiveCompressionFormat = .zip) -> ArchiveOperationAbstraction {
        let implementor = makeImplementor(for: format)
        return ArchiveOperationAbstraction(implementor: implementor)
    }
}

// MARK: - Conformances

//
//


// MARK: - ArchiveReading Default Implementations & Extensions

extension ArchiveReading {
    public func inspect(archivePath: String, password: String?) async throws -> [ArchiveEntry] {
        return try await inspect(archivePath: archivePath, password: password, candidatePasswords: nil)
    }
    
    public func inspectTree(archivePath: String, password: String? = nil, candidatePasswords: [String]? = nil) async throws -> ArchiveCompositeDirectory {
        let entries = try await inspect(archivePath: archivePath, password: password, candidatePasswords: candidatePasswords)
        return ArchiveComponentTreeBuilder.buildTree(from: entries)
    }
    
    public func probeEncryption(archivePath: String) async throws -> ArchiveEncryptionTier {
        do {
            let entries = try await inspect(archivePath: archivePath, password: nil, candidatePasswords: nil)
            if entries.isEmpty {
                return .none
            }
            let hasEncrypted = entries.contains { $0.isEncrypted }
            return hasEncrypted ? .dataOnly : .none
        } catch let error as ArchiveError {
            switch error {
            case .passwordRequired, .passwordRequiredDetailed(_, .headerAndData):
                return .headerAndData
            case .passwordRequiredDetailed(_, .dataOnly):
                return .dataOnly
            default:
                throw error
            }
        } catch {
            throw error
        }
    }
}

// MARK: - ArchiveWriting Default Implementations & Extensions

extension ArchiveWriting {
    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        try await createArchive(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )
    }

    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        try createArchiveSync(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )
    }

    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        components: [ArchiveComponentProtocol],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        let inputPaths = components.map { $0.path }
        try await createArchive(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )
    }

    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        components: [ArchiveComponentProtocol],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        let inputPaths = components.map { $0.path }
        try createArchiveSync(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler
        )
    }
}

// MARK: - ArchiveExtracting Default Implementations & Extensions

extension ArchiveExtracting {
    public func joinSplitVolumes(firstVolumePath: String, outputPath: String) -> Bool {
        if let extractor = self as? ArchiveExtractor {
            return extractor.joinSplitVolumes(firstVolumePath: firstVolumePath, outputPath: outputPath)
        }
        return false
    }

    public func extract(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) async throws {
        try await extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options,
            password: password,
            advancedOptions: advancedOptions
        )
    }

    public func extractSingleFile(
        archivePath: String,
        entryPath: String,
        destinationDir: String,
        password: String? = nil
    ) async throws {
        if let extractor = self as? ArchiveExtractor {
            try await extractor.extractSingleFile(
                archivePath: archivePath,
                entryPath: entryPath,
                destinationDir: destinationDir,
                password: password
            )
        } else {
            try await extract(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: .defaultClean,
                password: password,
                advancedOptions: nil
            )
        }
    }

    public func extractSync(
        archivePath: String,
        destinationDir: String,
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions? = nil
    ) throws {
        if let extractor = self as? ArchiveExtractor {
            try extractor.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: options,
                password: password,
                advancedOptions: advancedOptions
            )
        } else {
            let extractor = ArchiveEngineFactory.makeExtractor()
            try extractor.extractSync(
                archivePath: archivePath,
                destinationDir: destinationDir,
                options: options,
                password: password,
                advancedOptions: advancedOptions
            )
        }
    }
}

// MARK: - ArchiveIntegrityChecking Default Implementations & Extensions

extension ArchiveIntegrityChecking {
    @discardableResult
    public func verifyExtractedDirectory(
        directoryPath: String,
        expectedOriginalBytes: Int64,
        sourceFilePath: String? = nil,
        sourceCRC32: String? = nil,
        label: String = "Verification"
    ) -> (isValid: Bool, totalExtractedBytes: Int64, crc32: String?) {
        return verifyExtractedDirectory(
            directoryPath: directoryPath,
            expectedOriginalBytes: expectedOriginalBytes,
            sourceFilePath: sourceFilePath,
            sourceCRC32: sourceCRC32,
            label: label
        )
    }
}

// MARK: - Compression Types

//
//


// MARK: - Archive Compression Types Module Gateway
//
// This file serves as the unified types aggregation and compatibility gateway.
// Submodule definitions are decomposed across:
// - `Types/ArchiveCompressionFormat.swift`: Archive formats, extensions, MIME resolution.
// - `Types/ArchiveCompressionOptions.swift`: Compression levels, format options, advanced configurations.
// - `Types/ArchiveEntryMetadata.swift`: Structured entry-level metadata models.

/// Common typealiases for compression and archive specifications.
public typealias CompressionFormat = ArchiveCompressionFormat
public typealias CompressionLevel = ArchiveCompressionLevel
public typealias CompressionOptions = ArchiveAdvancedOptions
public typealias EntryMetadata = ArchiveEntryMetadata
