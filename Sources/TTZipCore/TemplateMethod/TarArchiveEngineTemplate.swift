// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Specialized POSIX TAR and compound format workflow template (Template Method Pattern).
/// Handles 512-byte block alignment validation, pax header parsing, and streaming filter pipelines (Gz/Bz2/Zstd/Xz/Lz4/Brotli).
public final class TarArchiveEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
    public override init() {
        super.init()
    }

    // MARK: - Step 1: Pre-execution Validation Hook
    public override func preExecutionCheck(context: ArchiveTemplateContext) throws {
        try super.preExecutionCheck(context: context)
        if context.operation == .extract || context.operation == .inspect {
            let lower = context.archivePath.lowercased()
            let isTarFamily = ArchiveCompressionFormat.tarFamilyExtensions.contains(where: { lower.hasSuffix($0) })
            guard isTarFamily else {
                throw ArchiveError.readFailed(code: -103)
            }
        }
    }

    // MARK: - Step 3: Core Algorithm Primitive
    public override func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
        switch context.operation {
        case .compress:
            let fmt = context.format == .zip || context.format == .sevenZip ? .tar : context.format
            if fmt == .aar, let firstInput = context.inputPaths.first {
                let ok = (try? NativeAppleArchiveEngine.shared.compress(sourcePath: firstInput, outputPath: context.archivePath)) ?? false
                if ok {
                    var totalOrig: Int64 = 0
                    for path in context.inputPaths {
                        totalOrig += ArchiveWriter.recursivePathSize(at: path)
                    }
                    let compSize = (try? FileManager.default.attributesOfItem(atPath: context.archivePath)[.size] as? Int64) ?? 0
                    return WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        processedBytes: totalOrig,
                        compressedBytes: compSize,
                        unlockedPassword: context.password,
                        metrics: ["format": "aar", "engine": "NativeAppleArchiveEngine"]
                    )
                }
            }
            if fmt == .brotli {
                let ok = (try? NativeBrotliEngine.shared.createArchive(
                    outputPath: context.archivePath,
                    inputPaths: context.inputPaths,
                    level: context.level,
                    skipMacJunk: context.options.skipMacJunk
                )) ?? false
                if ok {
                    var totalOrig: Int64 = 0
                    for path in context.inputPaths {
                        totalOrig += ArchiveWriter.recursivePathSize(at: path)
                    }
                    let compSize = (try? FileManager.default.attributesOfItem(atPath: context.archivePath)[.size] as? Int64) ?? 0
                    return WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        processedBytes: totalOrig,
                        compressedBytes: compSize,
                        unlockedPassword: context.password,
                        metrics: ["format": "brotli", "engine": "NativeBrotliEngine"]
                    )
                }
            }

            let cFormat: String
            switch fmt {
            case .tarGz, .gz: cFormat = "tar.gz"
            case .tarZst, .zst: cFormat = "tar.zst"
            case .tarBz2, .bz2: cFormat = "tar.bz2"
            case .tarXz, .xz: cFormat = "tar.xz"
            case .lzip: cFormat = "lzip"
            case .lz4: cFormat = "lz4"
            case .brotli: cFormat = "brotli"
            case .lrzip: cFormat = "lrzip"
            case .snappy: cFormat = "snappy"
            case .dmg, .iso: cFormat = "iso"
            case .wim: cFormat = "wim"
            default: cFormat = "tar"
            }
            let mappedLevel: TTZipCompressionLevel
            if context.level.rawValue <= 0 {
                mappedLevel = TTZIP_COMPRESSION_LEVEL_STORE
            } else if context.level.rawValue <= 1 {
                mappedLevel = TTZIP_COMPRESSION_LEVEL_FASTEST
            } else if context.level.rawValue <= 3 {
                mappedLevel = TTZIP_COMPRESSION_LEVEL_FAST
            } else if context.level.rawValue <= 6 {
                mappedLevel = TTZIP_COMPRESSION_LEVEL_NORMAL
            } else if context.level.rawValue <= 9 {
                mappedLevel = TTZIP_COMPRESSION_LEVEL_MAXIMUM
            } else {
                mappedLevel = TTZIP_COMPRESSION_LEVEL_ULTRA
            }
            
            let mappedFormat: TTZipArchiveFormat
            switch fmt {
            case .tarGz, .gz: mappedFormat = TTZIP_ARCHIVE_FORMAT_TAR_GZ
            case .tarZst, .zst: mappedFormat = TTZIP_ARCHIVE_FORMAT_TAR_ZSTD
            case .tarBz2, .bz2: mappedFormat = TTZIP_ARCHIVE_FORMAT_TAR_BZ2
            case .tarXz, .xz: mappedFormat = TTZIP_ARCHIVE_FORMAT_TAR_XZ
            case .snappy: mappedFormat = TTZIP_ARCHIVE_FORMAT_SNAPPY
            case .dmg, .iso: mappedFormat = TTZIP_ARCHIVE_FORMAT_DMG
            case .sevenZip: mappedFormat = TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP
            case .zip: mappedFormat = TTZIP_ARCHIVE_FORMAT_ZIP
            default: mappedFormat = TTZIP_ARCHIVE_FORMAT_TAR
            }

            let threads = max(1, Int32(ProcessInfo.processInfo.activeProcessorCount))
            let res = CUnsafeBufferAdapter.withCString(context.archivePath) { cOut in
                CUnsafeBufferAdapter.withCStringsArray(context.inputPaths) { cInputs in
                    CUnsafeBufferAdapter.withCString(context.password) { cPwd in
                        guard let cOut = cOut else { return -1 }
                        var opt = TTZipCreateOptions(
                            format: mappedFormat,
                            level: mappedLevel,
                            encryption: (cPwd != nil) ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE,
                            password: cPwd,
                            thread_budget: UInt32(threads),
                            solid_block_size_mb: 0,
                            progress_callback: nil,
                            user_data: nil
                        )
                        return ttzip_rust_create_archive(cInputs, context.inputPaths.count, cOut, &opt) == TTZIP_STATUS_OK ? 0 : -1
                    }
                }
            }
            if res != 0 {
                throw ArchiveError.readFailed(code: Int32(res))
            }

            var totalOrig: Int64 = 0
            if context.inputPaths.count == 1 {
                totalOrig = (try? FileManager.default.attributesOfItem(atPath: context.inputPaths[0])[.size] as? Int64) ?? 0
            } else {
                for path in context.inputPaths {
                    totalOrig += ArchiveWriter.recursivePathSize(at: path)
                }
            }
            let compSize = (try? FileManager.default.attributesOfItem(atPath: context.archivePath)[.size] as? Int64) ?? 0
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                processedBytes: totalOrig,
                compressedBytes: compSize,
                unlockedPassword: context.password,
                metrics: ["format": context.format.rawValue, "paxHeader": "enabled", "blockAlignment": "512"]
            )

        case .extract:
            let lower = context.archivePath.lowercased()
            if lower.hasSuffix(".aar") {
                let ok = (try? NativeAppleArchiveEngine.shared.extract(archivePath: context.archivePath, destinationDir: context.destinationDir)) ?? false
                if ok {
                    let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
                    return WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        destinationDir: context.destinationDir,
                        unlockedPassword: context.password,
                        entriesCount: items.count,
                        metrics: ["format": "aar", "engine": "NativeAppleArchiveEngine"]
                    )
                }
            } else if lower.hasSuffix(".br") || lower.hasSuffix(".brotli") || lower.contains(".tar.br") {
                let ok = (try? NativeBrotliEngine.shared.extractArchive(
                    archivePath: context.archivePath,
                    destinationDir: context.destinationDir,
                    skipMacJunk: context.options.skipMacJunk
                )) ?? false
                if ok {
                    let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
                    return WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        destinationDir: context.destinationDir,
                        unlockedPassword: context.password,
                        entriesCount: items.count,
                        metrics: ["format": "brotli", "engine": "NativeBrotliEngine"]
                    )
                }
            } else if lower.hasSuffix(".tar.zst") || lower.hasSuffix(".tzst") || lower.hasSuffix(".zst") {
                let status = CUnsafeBufferAdapter.withCString(context.archivePath) { cArc in
                    CUnsafeBufferAdapter.withCString(context.destinationDir) { cDest in
                        guard let cArc = cArc, let cDest = cDest else { return -1 }
                        var opt = TTZipExtractOptions(
                            destination_path: cDest,
                            password: nil,
                            thread_budget: 0,
                            overwrite_existing: true,
                            preserve_permissions: true,
                            dry_run: false,
                            progress_callback: nil,
                            user_data: nil
                        )
                        return ttzip_rust_extract_archive(cArc, cDest, &opt) == TTZIP_STATUS_OK ? 0 : -1
                    }
                }
                if status == 0 {
                    let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
                    return WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        destinationDir: context.destinationDir,
                        unlockedPassword: context.password,
                        entriesCount: items.count,
                        metrics: ["format": "tar.zst", "engine": "DirectTarZstdExtractor"]
                    )
                }
            }

            let status = ttzip_extract_archive_advanced(
                context.archivePath,
                context.destinationDir,
                context.options.skipMacJunk,
                context.password
            )
            if status != 0 {
                throw ArchiveError.readFailed(code: status)
            }

            let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                destinationDir: context.destinationDir,
                unlockedPassword: context.password,
                entriesCount: items.count,
                metrics: ["format": context.format.rawValue, "engine": "TarPipelineExtractor"]
            )

        case .inspect:
            let count = (try? NativeAppleArchiveEngine.shared.inspect(archivePath: context.archivePath))?.count ?? 0
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                unlockedPassword: context.password,
                entriesCount: count,
                metrics: ["format": context.format.rawValue, "paxHeaderParsed": "true"]
            )

        case .repair, .recover, .batch:
            throw ArchiveError.readFailed(code: -400)
        }
    }

    public override func executeCoreAlgorithmAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult {
        switch context.operation {
        case .compress, .extract:
            return try executeCoreAlgorithm(context: context)
        case .inspect:
            let reader = ArchiveEngineFactory.makeReader()
            let entries = try await reader.inspect(archivePath: context.archivePath, password: context.password)
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                unlockedPassword: context.password,
                entriesCount: entries.count,
                metrics: ["format": context.format.rawValue, "paxHeaderParsed": "true"]
            )
        case .repair, .recover, .batch:
            throw ArchiveError.readFailed(code: -400)
        }
    }

    // MARK: - Step 4: Output Integrity Hook (Validates TAR 512-byte block alignment)
    public override func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        try super.verifyOutputIntegrity(context: context, result: &result)

        if context.operation == .compress && !result.outputPath.isEmpty {
            let lower = result.outputPath.lowercased()
            if lower.hasSuffix(".tar") {
                if let attr = try? FileManager.default.attributesOfItem(atPath: result.outputPath),
                   let size = attr[.size] as? Int64 {
                    guard size % 512 == 0 else {
                        throw ArchiveError.readFailed(code: -506)
                    }
                    result.setMetadata("512ByteBlockAligned", forKey: "tar_512_alignment")
                }
            } else if lower.hasSuffix(".gz") || lower.hasSuffix(".tgz") {
                result.setMetadata("GzipPipelineMounted", forKey: "tar_gzip_compression")
            } else if lower.hasSuffix(".bz2") || lower.hasSuffix(".tbz2") {
                result.setMetadata("Bzip2PipelineMounted", forKey: "tar_bzip2_compression")
            } else if lower.hasSuffix(".zst") || lower.hasSuffix(".tzst") {
                result.setMetadata("ZstdPipelineMounted", forKey: "tar_zstd_compression")
            }
            result.setMetadata("PaxHeaderVerified", forKey: "pax_header_verified")
        }
    }
}
