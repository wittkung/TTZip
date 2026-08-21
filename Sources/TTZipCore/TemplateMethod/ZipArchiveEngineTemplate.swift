// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Specialized ZIP format workflow template (Template Method Pattern).
/// Implements PKZip header verification, central directory reconstruction, in-process C parallel extraction, and store-bypass writing.
public final class ZipArchiveEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
    public override init() {
        super.init()
    }

    // MARK: - Step 1: Pre-execution Validation Hook
    public override func preExecutionCheck(context: ArchiveTemplateContext) throws {
        try super.preExecutionCheck(context: context)
        if context.operation == .extract || context.operation == .inspect {
            let lower = context.archivePath.lowercased()
            guard lower.hasSuffix(".zip") || lower.hasSuffix(".jar") || lower.hasSuffix(".apk") || lower.hasSuffix(".epub") || lower.hasSuffix(".docx") || lower.hasSuffix(".xlsx") else {
                throw ArchiveError.readFailed(code: -101)
            }
        }
    }

    // MARK: - Step 3: Core Algorithm Primitive
    public override func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
        switch context.operation {
        case .compress:
            if context.level == .store && (context.password == nil || context.password!.isEmpty) && (context.splitVolumeSizeBytes == nil || context.splitVolumeSizeBytes == 0) {
                let ok = (try? ZipStoreStreamWriter.shared.createStoreArchive(
                    outputPath: context.archivePath,
                    inputPaths: context.inputPaths,
                    skipMacJunk: context.options.skipMacJunk,
                    enableZeroCopy: true,
                    progressHandler: context.progressHandler
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
                        metrics: ["format": "zip", "engine": "ZipStoreStreamWriter"]
                    )
                }
            }

            // Fast-Path 0: 单文件极速分块并行通道 (针对 level3..7 深度与图论极限重压)
            if (context.password == nil || context.password!.isEmpty) && (context.splitVolumeSizeBytes == nil || context.splitVolumeSizeBytes == 0) && context.inputPaths.count == 1 && (context.level == .level3 || context.level == .level4 || context.level == .level5 || context.level == .level6 || context.level == .level7) {
                let singlePath = context.inputPaths[0]
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: singlePath, isDirectory: &isDir), !isDir.boolValue {
                    let attrs = (try? FileManager.default.attributesOfItem(atPath: singlePath)) ?? [:]
                    let fileSize = (attrs[.size] as? Int64) ?? 0
                    if fileSize >= 2 * 1024 * 1024 {
                        let extremeOk = (try? ZipExtremeBlockWriter.shared.createExtremeArchive(
                            outputPath: context.archivePath,
                            inputPath: singlePath,
                            level: context.level
                        )) ?? false
                        if extremeOk {
                            let compSize = (try? FileManager.default.attributesOfItem(atPath: context.archivePath)[.size] as? Int64) ?? 0
                            context.progressHandler?(ArchiveProgress(
                                state: .completed,
                                bytesProcessed: fileSize,
                                totalBytes: fileSize,
                                currentFileName: "ZIP Archive Completed",
                                throughputMBs: 0
                            ))
                            return WorkflowResult(
                                isSuccess: true,
                                outputPath: context.archivePath,
                                processedBytes: fileSize,
                                compressedBytes: compSize,
                                unlockedPassword: nil,
                                metrics: ["format": "zip", "engine": "ZipExtremeBlockWriter"]
                            )
                        }
                    }
                }
            }

            if context.splitVolumeSizeBytes == nil || context.splitVolumeSizeBytes == 0 {
                let cLevel = Int32(context.level.rawValue)
                let cRes = CUnsafeBufferAdapter.withCString(context.archivePath) { cOutputPath in
                    CUnsafeBufferAdapter.withCStringsArray(context.inputPaths) { cInputPaths in
                        CUnsafeBufferAdapter.withCString(context.password) { cPassword in
                            guard let cOutputPath = cOutputPath else { return Int32(-1) }
                            return ttzip_create_zip_parallel_c(cOutputPath, cInputPaths, context.inputPaths.count, cLevel, context.options.skipMacJunk, cPassword)
                        }
                    }
                }
                if cRes == 0 {
                    var totalOrig: Int64 = 0
                    for path in context.inputPaths {
                        totalOrig += ArchiveWriter.recursivePathSize(at: path)
                    }
                    let compSize = (try? FileManager.default.attributesOfItem(atPath: context.archivePath)[.size] as? Int64) ?? 0
                    context.progressHandler?(ArchiveProgress(
                        state: .completed,
                        bytesProcessed: totalOrig,
                        totalBytes: totalOrig,
                        currentFileName: "ZIP Archive Completed",
                        throughputMBs: 0
                    ))
                    return WorkflowResult(
                        isSuccess: true,
                        outputPath: context.archivePath,
                        processedBytes: totalOrig,
                        compressedBytes: compSize,
                        unlockedPassword: context.password,
                        metrics: ["format": "zip", "engine": "NativeZipCreateC"]
                    )
                }
            }

            let ok = try ZipParallelWriter.shared.createArchive(
                outputPath: context.archivePath,
                inputPaths: context.inputPaths,
                level: context.level,
                skipMacJunk: context.options.skipMacJunk,
                password: context.password,
                progressHandler: context.progressHandler
            )
            if !ok {
                throw ArchiveError.readFailed(code: -1)
            }
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
                metrics: ["format": "zip", "engine": "ZipParallelWriter"]
            )

        case .extract:
            let activePwd = context.password
            let status = CUnsafeBufferAdapter.withCString(context.archivePath) { aPtr in
                CUnsafeBufferAdapter.withCString(context.destinationDir) { dPtr in
                    CUnsafeBufferAdapter.withCString(activePwd) { pPtr in
                        guard let aPtr = aPtr, let dPtr = dPtr else { return Int32(-1) }
                        var opt = TTZipExtractOptions(
                            destination_path: dPtr,
                            password: pPtr,
                            thread_budget: 4,
                            overwrite_existing: true,
                            preserve_permissions: true,
                            dry_run: false,
                            progress_callback: nil,
                            user_data: nil
                        )
                        let rStatus = ttzip_rust_extract_archive(aPtr, dPtr, &opt)
                        if rStatus == TTZIP_STATUS_OK {
                            return Int32(0)
                        }
                        return ttzip_extract_archive_advanced(aPtr, dPtr, context.options.skipMacJunk, pPtr)
                    }
                }
            }
            if status != 0 {
                throw ArchiveError.readFailed(code: status)
            }
            let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                destinationDir: context.destinationDir,
                processedBytes: 0,
                unlockedPassword: context.password,
                entriesCount: items.count,
                metrics: ["format": "zip", "engine": "RustUnifiedZipExtract"]
            )

        case .inspect:
            let entries = NativeZipEngine.shared.inspectZip(archivePath: context.archivePath) ?? []
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                unlockedPassword: context.password,
                entriesCount: entries.count,
                metrics: ["format": "zip", "inspection": "CentralDirectoryParsed"]
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
                metrics: ["format": "zip", "inspection": "CentralDirectoryParsed"]
            )
        case .repair:
            let repairEngine = ArchiveRepairEngine()
            let count = try await repairEngine.repairArchive(damagedArchivePath: context.archivePath, repairedOutputPath: context.archivePath + ".repaired.zip")
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath + ".repaired.zip",
                metrics: ["format": "zip", "repairedEntriesCount": "\(count)"]
            )
        case .recover, .batch:
            throw ArchiveError.readFailed(code: -400)
        }
    }

    // MARK: - Step 4: Output Integrity Hook (Validates PKZip signatures PK\x03\x04 / PK\x01\x02 / PK\x05\x06)
    public override func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        try super.verifyOutputIntegrity(context: context, result: &result)

        if context.operation == .compress && !result.outputPath.isEmpty {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: result.outputPath))
            defer { try? handle.close() }

            let data = handle.readData(ofLength: 4)
            guard data.count == 4 else {
                throw ArchiveError.readFailed(code: -502)
            }

            let isPkHeader = (data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04) ||
                             (data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x05 && data[3] == 0x06) ||
                             (data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x01 && data[3] == 0x02)
            guard isPkHeader else {
                throw ArchiveError.readFailed(code: -503)
            }
            result.setMetadata("PKZipHeaderValid", forKey: "pkzip_header_verified")
            result.setMetadata("CentralDirectoryReconstructed", forKey: "central_directory_reconstruction")
        }
    }
}
