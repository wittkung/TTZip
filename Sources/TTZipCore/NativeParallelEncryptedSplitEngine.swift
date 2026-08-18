// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

/// Hardware-accelerated encrypted multi-volume archive engine (7z `.7z.001` and ZIP `.zip.001`).
///
/// Output volumes are 100% compliant with standard 7-Zip, Bandizip, WinRAR, Keka, and macOS Archive Utility.
public final class NativeParallelEncryptedSplitEngine: @unchecked Sendable {
    public init() {}
    
    public enum SplitFormat: String, Sendable {
        case sevenZip = "7z"
        case zip = "zip"
    }
    
    /// Creates standard encrypted multi-volume split archives (100% in-process C execution).
    public func createStandardEncryptedSplitVolume(
        format: SplitFormat = .sevenZip,
        sourcePaths: [String],
        outputDir: String,
        baseName: String,
        splitVolumeSizeBytes: Int64,
        password: String,
        encryptFileNames: Bool = true,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [String] {
        guard !sourcePaths.isEmpty else {
            throw ArchiveError.readFailed(code: -404)
        }
        
        AppleSiliconTuner.shared.boostCurrentThreadPriority()
        
        let targetExtension = (format == .sevenZip) ? "7z" : "zip"
        let primaryOutputPath = (outputDir as NSString).appendingPathComponent("\(baseName).\(targetExtension)")
        try? FileManager.default.removeItem(atPath: primaryOutputPath)
        
        progressHandler?(0.1)
        
        let success: Bool
        if format == .sevenZip {
            success = (try? SevenZipCAdapter.shared.createArchive(
                outputPath: primaryOutputPath,
                inputPaths: sourcePaths,
                level: .store,
                password: password,
                progressHandler: nil
            )) ?? false
        } else {
            let res = CUnsafeBufferAdapter.withCString(primaryOutputPath) { cOutputPath in
                CUnsafeBufferAdapter.withCStringsArray(sourcePaths) { cInputPaths in
                    CUnsafeBufferAdapter.withCString(password) { cPassword in
                        guard let cOutputPath = cOutputPath else { return Int32(-1) }
                        let status = ttzip_create_zip_parallel_c(cOutputPath, cInputPaths, sourcePaths.count, 0, false, cPassword)
                        if status == 0 { return Int32(0) }
                        return ttzip_create_archive_tuned(cOutputPath, "zip", cInputPaths, sourcePaths.count, false, 0, 0, 16, cPassword)
                    }
                }
            }
            success = (res == 0)
        }
        
        guard success, FileManager.default.fileExists(atPath: primaryOutputPath) else {
            throw ArchiveError.readFailed(code: -405)
        }
        
        progressHandler?(0.7)
        
        // In-process slicing
        try ArchiveWriter.sliceArchiveIfNeeded(archivePath: primaryOutputPath, splitSizeBytes: splitVolumeSizeBytes)
        
        progressHandler?(1.0)
        
        // Retrieve generated volume list
        let fm = FileManager.default
        let allFiles = (try? fm.contentsOfDirectory(atPath: outputDir)) ?? []
        let generatedVolumes = allFiles.filter { file in
            file.hasPrefix(baseName) && (file.contains(".7z.") || file.contains(".z") || file.contains(".00") || file.hasSuffix(".7z") || file.hasSuffix(".zip"))
        }.sorted().map { (outputDir as NSString).appendingPathComponent($0) }
        
        return generatedVolumes
    }
}
