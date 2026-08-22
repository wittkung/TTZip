// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
