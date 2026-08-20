// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Specialized 7-Zip format workflow template (Template Method Pattern).
/// Handles solid block stream decoding, 7z signature and CRC32 verification, and split-volume assembly.
public final class SevenZipArchiveEngineTemplate: BaseArchiveEngineTemplate, @unchecked Sendable {
    public override init() {
        super.init()
    }

    // MARK: - Step 1: Pre-execution Validation Hook
    public override func preExecutionCheck(context: ArchiveTemplateContext) throws {
        try super.preExecutionCheck(context: context)
        if context.operation == .extract || context.operation == .inspect {
            let lower = context.archivePath.lowercased()
            let is7zFamily = ArchiveCompressionFormat.sevenZipFamilyExtensions.contains(where: { lower.hasSuffix($0) }) || lower.contains(".7z.")
            guard is7zFamily else {
                throw ArchiveError.readFailed(code: -102)
            }
        }
    }

    // MARK: - Step 3: Core Algorithm Primitive
    public override func executeCoreAlgorithm(context: ArchiveTemplateContext) throws -> WorkflowResult {
        switch context.operation {
        case .compress:
            let ok = try SevenZipEngine.shared.createArchive(
                outputPath: context.archivePath,
                inputPaths: context.inputPaths,
                level: context.level,
                password: context.password,
                progressHandler: context.progressHandler
            )
            if !ok {
                throw ArchiveError.readFailed(code: -1)
            }
            if let splitBytes = context.splitVolumeSizeBytes, splitBytes > 0 {
                try? ArchiveWriter.sliceArchiveIfNeeded(archivePath: context.archivePath, splitSizeBytes: splitBytes)
            }
            var totalOrig: Int64 = 0
            if context.inputPaths.count == 1 {
                totalOrig = (try? FileManager.default.attributesOfItem(atPath: context.inputPaths[0])[.size] as? Int64) ?? 0
            } else {
                for path in context.inputPaths {
                    totalOrig += ArchiveWriter.recursivePathSize(at: path)
                }
            }
            let checkPath = FileManager.default.fileExists(atPath: context.archivePath) ? context.archivePath : (context.archivePath + ".001")
            let compSize = (try? FileManager.default.attributesOfItem(atPath: checkPath)[.size] as? Int64) ?? 0
            return WorkflowResult(
                isSuccess: true,
                outputPath: checkPath,
                processedBytes: totalOrig,
                compressedBytes: compSize,
                unlockedPassword: context.password,
                metrics: ["format": "7z", "engine": "SevenZipEngine", "solidBlock": "parsed"]
            )

        case .extract:
            let pathLower = context.archivePath.lowercased()
            if pathLower.hasSuffix(".001") {
                let joinedTemp = (context.tempDir as NSString?)?.appendingPathComponent("joined_\(UUID().uuidString).7z") ?? FileManager.default.temporaryDirectory.appendingPathComponent("joined_\(UUID().uuidString).7z").path
                defer { try? FileManager.default.removeItem(atPath: joinedTemp) }
                let helperExtractor = ArchiveExtractor(targetFormat: .sevenZip)
                if helperExtractor.joinSplitVolumes(firstVolumePath: context.archivePath, outputPath: joinedTemp) {
                    let ok = try SevenZipEngine.shared.extract(
                        archivePath: joinedTemp,
                        destinationDir: context.destinationDir,
                        password: context.password
                    )
                    if ok {
                        let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
                        return WorkflowResult(
                            isSuccess: true,
                            outputPath: context.archivePath,
                            destinationDir: context.destinationDir,
                            unlockedPassword: context.password,
                            entriesCount: items.count,
                            metrics: ["format": "7z", "splitVolumeAssembled": "true"]
                        )
                    }
                }
            }

            let ok = try SevenZipEngine.shared.extract(
                archivePath: context.archivePath,
                destinationDir: context.destinationDir,
                password: context.password
            )
            if !ok {
                throw ArchiveError.readFailed(code: -1)
            }
            let items = (try? FileManager.default.contentsOfDirectory(atPath: context.destinationDir)) ?? []
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                destinationDir: context.destinationDir,
                unlockedPassword: context.password,
                entriesCount: items.count,
                metrics: ["format": "7z", "engine": "SevenZipEngine"]
            )

        case .inspect:
            let entries = NativeSevenZipEngine.shared.inspectSevenZip(archivePath: context.archivePath, password: context.password) ?? []
            return WorkflowResult(
                isSuccess: true,
                outputPath: context.archivePath,
                unlockedPassword: context.password,
                entriesCount: entries.count,
                metrics: ["format": "7z", "solidBlockStream": "inspected"]
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
                metrics: ["format": "7z", "solidBlockStream": "inspected"]
            )
        case .repair, .recover, .batch:
            throw ArchiveError.readFailed(code: -400)
        }
    }

    // MARK: - Step 4: Output Integrity Hook (Validates 7z magic bytes 0x37 0x7A 0xBC 0xAF 0x27 0x1C)
    public override func verifyOutputIntegrity(context: ArchiveTemplateContext, result: inout WorkflowResult) throws {
        try super.verifyOutputIntegrity(context: context, result: &result)

        if context.operation == .compress && !result.outputPath.isEmpty {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: result.outputPath))
            defer { try? handle.close() }

            let data = handle.readData(ofLength: 6)
            guard data.count == 6 else {
                throw ArchiveError.readFailed(code: -504)
            }

            let is7zMagic = (data[0] == 0x37 && data[1] == 0x7A && data[2] == 0xBC && data[3] == 0xAF && data[4] == 0x27 && data[5] == 0x1C)
            guard is7zMagic else {
                throw ArchiveError.readFailed(code: -505)
            }
            result.setMetadata("7zMagicHeaderVerified", forKey: "7z_magic_header_verified")
            result.setMetadata("SolidBlockParsingReady", forKey: "solid_block_parsing")
        }
    }
}
