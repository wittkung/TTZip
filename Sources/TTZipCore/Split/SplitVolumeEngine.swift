// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-level engine providing multi-volume split archive management, slicing, and reassembly.
public final class SplitVolumeEngine: @unchecked Sendable {
    public static let shared = SplitVolumeEngine()
    
    public init() {}
    
    /// Slices an existing monolithic archive file into multi-volume segments.
    public func sliceArchive(
        archivePath: String,
        splitSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension,
        cleanOnFailure: Bool = true
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: archivePath) else { return }
        let attrs = try fm.attributesOfItem(atPath: archivePath)
        guard let fileSize = attrs[.size] as? Int64, fileSize > 0 else { return }
        guard splitSizeBytes >= 65536 && splitSizeBytes < fileSize else { return }
        
        let schemeVal: Int32
        switch namingPattern {
        case .numberedExtension:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_NUMBERED.rawValue)
        case .pkzipSpanned:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_PKZIP.rawValue)
        case .rawSplit:
            schemeVal = Int32(TTZIP_VOLUME_NAMING_RAW.rawValue)
        }
        
        let res = archivePath.withCString { cSrc in
            archivePath.withCString { cDst in
                ttzip_rust_split_file(cSrc, cDst, UInt64(splitSizeBytes), schemeVal, cleanOnFailure)
            }
        }
        
        guard res == TTZIP_STATUS_OK else {
            throw ArchiveError.readFailed(code: res.rawValue)
        }
        
        if namingPattern != .pkzipSpanned {
            try? fm.removeItem(atPath: archivePath)
        }
    }
    
    /// Joins multi-volume split files into a continuous output archive.
    public func joinVolumes(
        firstVolumePath: String,
        outputPath: String,
        progressHandler: (@Sendable (Double) -> Bool)? = nil
    ) throws {
        try SplitVolumeConcatenator.shared.join(
            firstVolumePath: firstVolumePath,
            outputPath: outputPath,
            progressHandler: progressHandler
        )
    }
    
    /// Creates a streaming multi-volume writer for pipeline-based archive operations.
    public func makeStreamWriter(
        baseOutputPath: String,
        config: SplitVolumeConfig
    ) throws -> SplitVolumeStreamWriter {
        return try SplitVolumeStreamWriter(
            baseOutputPath: baseOutputPath,
            volumeSizeBytes: config.volumeSizeBytes,
            namingPattern: config.namingPattern,
            cleanOnFailure: config.cleanOnFailure
        )
    }
    
    /// Discovers and lists all volume paths belonging to a split archive set from a seed volume.
    public func resolveVolumes(seedPath: String) -> [String] {
        return SplitVolumeConcatenator.shared.inspect(seedPath: seedPath)?.volumePaths ?? [seedPath]
    }
}
