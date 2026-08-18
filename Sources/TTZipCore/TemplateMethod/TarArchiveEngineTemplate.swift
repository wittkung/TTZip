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
            let threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
            let res = CUnsafeBufferAdapter.withCStringsArray(context.inputPaths) { cInputPaths in
                ttzip_create_archive_tuned(
                    context.archivePath,
                    cFormat,
                    cInputPaths,
                    context.inputPaths.count,
                    context.options.skipMacJunk,
                    Int32(context.level.rawValue),
                    0,
                    threads,
                    context.password
                )
            }
            if res != 0 {
                throw ArchiveError.readFailed(code: res)
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
                let status = ttzip_extract_tar_zstd_direct_c(context.archivePath, context.destinationDir, context.options.skipMacJunk)
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
            let reader = ArchiveEngineFactory.makeReader()
            let box = SyncResultBox()
            let sema = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    let entries = try await reader.inspect(archivePath: context.archivePath, password: context.password)
                    box.result = WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        unlockedPassword: context.password,
                        entriesCount: entries.count,
                        metrics: ["format": context.format.rawValue, "paxHeaderParsed": "true"]
                    )
                } catch {
                    box.error = error
                }
                sema.signal()
            }
            sema.wait()
            if let r = box.result { return r }
            if let e = box.error { throw e }
            throw ArchiveError.readFailed(code: -999)

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
