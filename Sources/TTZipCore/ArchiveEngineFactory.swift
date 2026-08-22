// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Strategy Pattern & Abstract Factory Pattern engine factory.
///
/// Provides factory methods for creating format-specific writers, extractors, readers,
/// strategy engines, bridge implementors, and decorated engine chains.
public enum ArchiveEngineFactory {
    
    /// Obtains current active engine family factory (Abstract Factory).
    public static var currentFamilyFactory: ArchiveEngineFamilyFactoryProtocol {
        return ArchiveEngineFamilyProvider.shared.currentFactory
    }

    /// Creates an archive writer for the specified format.
    public static func makeWriter(for format: ArchiveCompressionFormat? = nil) -> ArchiveWriting {
        return currentFamilyFactory.makeWriter(for: format)
    }
    
    /// Creates an archive extractor for the specified format.
    public static func makeExtractor(for format: ArchiveCompressionFormat? = nil) -> ArchiveExtracting {
        return currentFamilyFactory.makeExtractor(for: format)
    }
    
    /// Creates an archive reader for the specified format.
    public static func makeReader(for format: ArchiveCompressionFormat? = nil) -> ArchiveReading {
        return currentFamilyFactory.makeReader(for: format)
    }

    /// Constructs format-specific strategy engine instance.
    public static func makeStrategy(for format: ArchiveCompressionFormat) -> ArchiveFormatEngineStrategy {
        switch format {
        case .zip:
            return ZipFormatEngineStrategy()
        case .sevenZip:
            return SevenZipFormatEngineStrategy()
        case .zst:
            return ZstdFormatEngineStrategy()
        case .tar, .tarGz, .gz, .bz2, .tarBz2, .xz, .tarXz, .tarZst, .lzip, .lz4, .brotli, .lrzip, .snappy, .aar, .wim, .dmg, .iso:
            return TarFormatEngineStrategy(format: format)
        }
    }

    /// Discovers and builds strategy engine from filesystem path extension.
    public static func makeStrategy(for path: String) -> ArchiveFormatEngineStrategy? {
        return ArchiveEngineRegistry.shared.findExtractor(for: path)
    }

    /// Creates an integrity checker engine instance.
    public static func makeIntegrityChecker() -> ArchiveIntegrityChecking {
        return currentFamilyFactory.makeIntegrityChecker()
    }

    /// Creates a hardware-accelerated cryptographic hash calculator instance.
    public static func makeHashCalculator(hardwareTuner: HardwareTunerProtocol? = nil) -> HashCalculating {
        if let tuner = hardwareTuner {
            return HashCalculator(hardwareTuner: tuner)
        }
        return currentFamilyFactory.makeHashCalculator()
    }

    // MARK: - Bridge Pattern Factory Methods

    /// Creates a low-level engine implementor for Bridge Pattern decoupling.
    public static func makeImplementor(for format: ArchiveCompressionFormat = .zip) -> ArchiveEngineImplementorProtocol {
        return currentFamilyFactory.makeImplementor(for: format)
    }

    /// Constructs high-level `ArchiveOperationAbstraction` with an implementor.
    public static func makeOperationAbstraction(for format: ArchiveCompressionFormat = .zip) -> ArchiveOperationAbstraction {
        let implementor = makeImplementor(for: format)
        return ArchiveOperationAbstraction(implementor: implementor)
    }

    // MARK: - Decorator Pattern Factory Methods

    /// Assembles an implementor wrapped with dynamic decorator chains.
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
}
