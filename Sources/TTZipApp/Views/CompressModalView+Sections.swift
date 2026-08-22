// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

extension CompressModalView {
    func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !itemsList.contains(where: { $0.path == url.path }) {
                    itemsList.append(CompressFileItem(path: url.path))
                }
            }
        }
    }
    
    func pickFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !itemsList.contains(where: { $0.path == url.path }) {
                    itemsList.append(CompressFileItem(path: url.path))
                }
            }
        }
    }
    
    func removeSelectedItems() {
        itemsList.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
    }
    
    func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            targetDirectory = url.path
        }
    }
    
    func startCompression() {
        guard !isProcessing && !itemsList.isEmpty && !outputName.isEmpty else { return }
        let ext = selectedFormat.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let inputPaths = itemsList.map { $0.path }
        guard !inputPaths.isEmpty else { return }
        let fullOutputPath = (targetDirectory as NSString).appendingPathComponent("\(outputName).\(ext)")
        
        isProcessing = true
        isProgressModalPresented = true
        
        let throttler = ThrottledProgressPublisher(maxFrequencyHz: 60.0)
        activeCompressionTask = Task {
            defer {
                Task { @MainActor in
                    self.isProcessing = false
                }
            }
            do {
                let advOpts = ArchiveAdvancedOptions.builder()
                    .withAlgorithm(compressionAlgorithm)
                    .withDictionarySizeMB(dictionarySizeMB)
                    .withCpuThreads(cachedTotalCores)
                    .withSolidArchive(enableSolidArchive)
                    .withEncryptFileNames(encryptFileNames)
                    .withZipEncryption(zipEncryptionMethod)
                    .withZipEncodingUTF8(zipEncodingUTF8)
                    .withZstdLevel(zstdLevel)
                    .withZstdEnableLDM(zstdEnableLDM)
                    .withPreservePosixAttributes(preservePosixAttributes)
                    .build()
                
                let cmdResult = try await TTZipEngineFacade.shared.compressWithCommand(
                    inputs: inputPaths,
                    outputPath: fullOutputPath,
                    format: selectedFormat,
                    level: compressionLevel,
                    password: enableEncryption ? password : nil,
                    splitSize: splitVolumeOption,
                    filterOptions: ArchiveFilterOptions(skipMacJunk: skipMacJunk),
                    advancedOptions: advOpts,
                    progress: { prog in
                        let isTerminal: Bool
                        switch prog.state {
                        case .completed, .failed: isTerminal = true
                        default: isTerminal = false
                        }
                        if isTerminal || throttler.shouldEmit() {
                            Task { @MainActor in
                                self.currentProgress = prog
                            }
                        }
                    },
                    engineFacade: SecurityProtectionProxy.shared
                )
                
                if openFinderAfterCompress {
                    NSWorkspace.shared.selectFile(fullOutputPath, inFileViewerRootedAtPath: targetDirectory)
                }
                
                let compressedSize = (cmdResult.metadata["compressedSize"] as NSString?)?.longLongValue ?? 0
                let originalSize = (cmdResult.metadata["originalSize"] as NSString?)?.longLongValue ?? 0
                let elapsed = cmdResult.executionDuration
                let throughput = elapsed > 0 ? (Double(originalSize) / 1024.0 / 1024.0) / elapsed : 0.0
                
                Task { @MainActor in
                    self.completedArchivePath = fullOutputPath
                    self.completedOriginalBytes = originalSize
                    self.completedCompressedBytes = compressedSize
                    self.completedElapsedSeconds = elapsed
                    self.completedThroughputMBs = throughput
                    self.isProgressModalPresented = false
                    self.isSummarySheetPresented = true
                }
            } catch {
                Task { @MainActor in
                    self.isProgressModalPresented = false
                }
            }
        }
    }
}
