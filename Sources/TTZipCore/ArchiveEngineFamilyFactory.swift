// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Standard Portable Tuner Implementation

/// Standard portable hardware tuning strategy for generic architectures and fallback execution.
public final class StandardPortableTuner: HardwareTunerProtocol, @unchecked Sendable {
    public static let shared = StandardPortableTuner()
    
    private init() {}
    
    public var totalCores: Int {
        return max(1, ProcessInfo.processInfo.processorCount)
    }
    
    public var optimalZstdLongWindowLog: Int {
        return 0
    }
    
    public var optimalAlignedBufferSize: Int {
        return 64 * 1024 // 64KB standard I/O buffer
    }
    
    public func boostCurrentThreadPriority() {
        // Portable mode preserves default QoS
    }
}

// MARK: - Abstract Factory Pattern Protocol

/// Abstract Factory Pattern: Defines interface for creating families of related engine components.
public protocol ArchiveEngineFamilyFactoryProtocol: Sendable {
    /// Hardware tuner bound to this family factory.
    var tuner: HardwareTunerProtocol { get }
    /// Creates archive writer product.
    func makeWriter(for format: ArchiveCompressionFormat?) -> ArchiveWriting
    /// Creates archive extractor product.
    func makeExtractor(for format: ArchiveCompressionFormat?) -> ArchiveExtracting
    /// Creates archive reader product.
    func makeReader(for format: ArchiveCompressionFormat?) -> ArchiveReading
    /// Creates low-level Bridge Pattern implementor product.
    func makeImplementor(for format: ArchiveCompressionFormat?) -> ArchiveEngineImplementorProtocol
    /// Creates integrity checking engine product.
    func makeIntegrityChecker() -> ArchiveIntegrityChecking
    /// Creates cryptographic hash calculator product.
    func makeHashCalculator() -> HashCalculating
}

public extension ArchiveEngineFamilyFactoryProtocol {
    func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return makeWriter(for: format)
    }
    func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return makeExtractor(for: format)
    }
    func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return makeReader(for: format)
    }
    func makeImplementor(for format: ArchiveCompressionFormat? = nil) -> ArchiveEngineImplementorProtocol {
        return makeImplementor(for: format)
    }
}

// MARK: - Concrete Engine Family Factories

/// Concrete Abstract Factory: Apple Silicon hardware-accelerated engine family.
///
/// Configures ARM64 NEON SIMD acceleration, 16KB page buffer alignment, and APFS pre-allocation.
public final class AppleSiliconAcceleratedEngineFactory: ArchiveEngineFamilyFactoryProtocol, @unchecked Sendable {
    public static let shared = AppleSiliconAcceleratedEngineFactory()
    
    public let tuner: HardwareTunerProtocol
    
    public init(tuner: HardwareTunerProtocol = AppleSiliconTuner.shared) {
        self.tuner = tuner
    }
    
    public func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return ArchiveWriter(
            hardwareTuner: tuner,
            targetFormat: format
        )
    }
    
    public func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return ArchiveExtractor(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return ArchiveReader(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeImplementor(for format: ArchiveCompressionFormat? = nil) -> ArchiveEngineImplementorProtocol {
        let targetFmt = format ?? .zip
        switch targetFmt {
        case .zip:
            return ZipEngineBridgeImplementor()
        case .sevenZip:
            return SevenZipEngineBridgeImplementor()
        case .zst, .tarZst:
            return ZstdEngineBridgeImplementor()
        case .tar, .tarGz, .gz, .bz2, .tarBz2, .xz, .tarXz, .lzip, .lz4, .brotli, .lrzip, .snappy, .aar, .wim, .dmg, .iso:
            return TarEngineBridgeImplementor()
        }
    }
    
    public func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return ArchiveIntegrityChecker(hashCalculator: makeHashCalculator())
    }
    
    public func makeHashCalculator() -> HashCalculating {
        return HashCalculator(hardwareTuner: tuner)
    }
}

/// Concrete Abstract Factory: Portable fallback engine family.
public final class StandardPortableEngineFactory: ArchiveEngineFamilyFactoryProtocol, @unchecked Sendable {
    public static let shared = StandardPortableEngineFactory()
    
    public let tuner: HardwareTunerProtocol
    
    public init(tuner: HardwareTunerProtocol = StandardPortableTuner.shared) {
        self.tuner = tuner
    }
    
    public func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return ArchiveWriter(
            hardwareTuner: tuner,
            targetFormat: format
        )
    }
    
    public func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return ArchiveExtractor(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return ArchiveReader(hardwareTuner: tuner, targetFormat: format)
    }
    
    public func makeImplementor(for format: ArchiveCompressionFormat? = nil) -> ArchiveEngineImplementorProtocol {
        let targetFmt = format ?? .zip
        switch targetFmt {
        case .zip:
            return ZipEngineBridgeImplementor()
        case .sevenZip:
            return SevenZipEngineBridgeImplementor()
        case .zst, .tarZst:
            return ZstdEngineBridgeImplementor()
        case .tar, .tarGz, .gz, .bz2, .tarBz2, .xz, .tarXz, .lzip, .lz4, .brotli, .lrzip, .snappy, .aar, .wim, .dmg, .iso:
            return TarEngineBridgeImplementor()
        }
    }
    
    public func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return ArchiveIntegrityChecker(hashCalculator: makeHashCalculator())
    }
    
    public func makeHashCalculator() -> HashCalculating {
        return HashCalculator(hardwareTuner: tuner)
    }
}

// MARK: - Engine Family Provider & Environment Awareness

/// Engine family selection mode.
public enum EngineFamilyMode: String, Sendable, CaseIterable {
    /// Auto-detects hardware topology (Apple Silicon accelerated on ARM64, Portable on x86_64).
    case auto
    /// Enforces Apple Silicon accelerated engine family.
    case appleSiliconAccelerated
    /// Enforces standard portable engine family.
    case standardPortable
}

/// Environment-aware factory provider resolving the optimal engine family at runtime.
public final class ArchiveEngineFamilyProvider: @unchecked Sendable {
    public static let shared = ArchiveEngineFamilyProvider()
    
    private let lock = NSLock()
    private var _mode: EngineFamilyMode = .auto
    private var _overrideFactory: ArchiveEngineFamilyFactoryProtocol?
    
    private init() {}
    
    /// Current engine family selection mode.
    public var mode: EngineFamilyMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _mode
        }
        set {
            lock.lock()
            _mode = newValue
            lock.unlock()
        }
    }
    
    /// Sets an explicit override factory (used for testing and mock injection).
    public func setOverrideFactory(_ factory: ArchiveEngineFamilyFactoryProtocol?) {
        lock.lock()
        defer { lock.unlock() }
        _overrideFactory = factory
    }
    
    /// Resets provider state back to `.auto` with nil override.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _mode = .auto
        _overrideFactory = nil
    }
    
    /// Obtains the resolved factory instance for current runtime environment.
    public var currentFactory: ArchiveEngineFamilyFactoryProtocol {
        lock.lock()
        if let override = _overrideFactory {
            lock.unlock()
            return override
        }
        let currentMode = _mode
        lock.unlock()
        
        switch currentMode {
        case .appleSiliconAccelerated:
            return AppleSiliconAcceleratedEngineFactory.shared
        case .standardPortable:
            return StandardPortableEngineFactory.shared
        case .auto:
            if isAppleSiliconEnvironment {
                return AppleSiliconAcceleratedEngineFactory.shared
            } else {
                return StandardPortableEngineFactory.shared
            }
        }
    }
    
    /// Whether current runtime host is Apple Silicon (ARM64).
    public var isAppleSiliconEnvironment: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}
