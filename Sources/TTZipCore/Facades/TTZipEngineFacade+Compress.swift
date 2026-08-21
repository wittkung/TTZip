// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - 1. 快捷统一压缩门面 (Compress Facade)

extension TTZipEngineFacade {
    public func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        filterOptions: ArchiveFilterOptions = .defaultClean,
        advancedOptions: ArchiveAdvancedOptions? = nil,
        progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws -> ArchiveOperationResult {
        guard !inputs.isEmpty && !outputPath.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let valCtx = ArchiveValidationContext.forCompress(
            sourcePaths: inputs,
            destinationPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            options: ArchiveValidationOptions(
                isSplit: splitSize != nil && splitSize! > 0,
                splitVolumeSizeBytes: splitSize,
                isEncrypted: password != nil && !password!.isEmpty,
                compressionLevel: level,
                skipMacJunk: filterOptions.skipMacJunk,
                format: format
            )
        )
        do {
            try ArchiveValidationPipeline.buildDefaultCompressPipeline().validateOrThrow(context: valCtx)
        } catch let valErr as ArchiveValidationError {
            throw valErr.asArchiveError
        }
        
        let combinedProgress: @Sendable (ArchiveProgress) -> Void = { p in
            progress?(p)
            let info = ArchiveProgressInfo(
                state: p.state,
                bytesProcessed: p.bytesProcessed,
                totalBytes: p.totalBytes,
                currentFileName: p.currentFileName,
                throughputMBs: p.throughputMBs,
                estimatedTimeRemaining: ArchiveProgressInfo.calculateETA(bytesProcessed: p.bytesProcessed, totalBytes: p.totalBytes, throughputMBs: p.throughputMBs),
                operationType: .compress
            )
            ArchiveProgressBroadcaster.shared.broadcastProgress(info)
        }
        
        if let splitBytes = splitSize, splitBytes > 0, (format == .sevenZip || format == .zip) {
            let splitFormat: NativeParallelEncryptedSplitEngine.SplitFormat = (format == .sevenZip) ? .sevenZip : .zip
            let outputDir = (outputPath as NSString).deletingLastPathComponent
            let baseName = (outputPath as NSString).lastPathComponent
            let targetDir = outputDir.isEmpty ? "." : outputDir
            
            let startTime = Date()
            let generatedVolumes = try await splitEngine.createStandardEncryptedSplitVolume(
                format: splitFormat,
                sourcePaths: inputs,
                outputDir: targetDir,
                baseName: baseName,
                splitVolumeSizeBytes: splitBytes,
                password: password ?? ""
            )
            
            let elapsed = max(0.001, Date().timeIntervalSince(startTime))
            var totalOrigBytes: Int64 = 0
            let fm = FileManager.default
            for p in inputs {
                if let attr = try? fm.attributesOfItem(atPath: p) {
                    if (attr[.type] as? FileAttributeType) == .typeDirectory {
                        let component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: p)
                        totalOrigBytes += component.sizeBytes
                    } else {
                        totalOrigBytes += (attr[.size] as? Int64) ?? 0
                    }
                }
            }
            
            var compressedSize: Int64 = 0
            for vol in generatedVolumes {
                if let attr = try? fm.attributesOfItem(atPath: vol) {
                    compressedSize += (attr[.size] as? Int64) ?? 0
                }
            }
            let rate = (Double(totalOrigBytes) / 1024.0 / 1024.0) / elapsed
            
            let res = ArchiveOperationResult(
                outputPath: outputPath,
                originalBytes: totalOrigBytes,
                compressedBytes: compressedSize,
                durationSeconds: elapsed,
                throughputMBs: rate
            )
            ArchiveEventCenter.shared.postArchiveCompleted(
                archivePath: outputPath,
                operationType: .compress,
                duration: elapsed,
                totalBytes: totalOrigBytes
            )
            return res
        }
        
        var builder = pipelineBuilderProvider()
            .withInputPaths(inputs)
            .withOutputPath(outputPath)
            .withFormat(format)
            .withLevel(level)
            .withFilterOptions(filterOptions)
            .withPassword(password)
            .withSplitVolumeSize(splitSize)
        
        if let adv = advancedOptions {
            builder = builder.withAdvancedOptions(adv)
        }
        
        builder = builder.withProgressHandler(combinedProgress)
        
        let res = try await builder.executeCreate()
        ArchiveEventCenter.shared.postArchiveCompleted(
            archivePath: outputPath,
            operationType: .compress,
            duration: res.durationSeconds,
            totalBytes: res.originalBytes
        )
        return res
    }
}
