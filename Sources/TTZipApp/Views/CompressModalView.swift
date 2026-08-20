// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

public struct CompressModalView: View {
    @ObservedObject private var l10n = AppLocalizationState.shared
    @Binding public var isPresented: Bool
    public let initialInputPaths: [String]
    public var onCompleteOpenArchive: ((String) -> Void)? = nil
    
    @State private var itemsList: [CompressFileItem] = []
    @State private var selectedItemIDs: Set<CompressFileItem.ID> = []
    @State private var outputName: String = "Archive"
    @State private var targetDirectory: String = NSHomeDirectory()
    @State private var selectedFormat: ArchiveCompressionFormat = .sevenZip
    @State private var compressionLevel: ArchiveCompressionLevel = .normal
    @State private var splitVolumeOption: Int64? = nil
    @State private var isCustomVolumeSelected: Bool = false
    @State private var customVolumeValueString: String = "100"
    @State private var customVolumeUnit: String = "MB"
    @State private var enableEncryption: Bool = false
    @State private var password: String = ""
    @State private var createSeparateArchives: Bool = false
    @State private var deleteSourceAfterCompress: Bool = false
    @State private var openFinderAfterCompress: Bool = true
    @State private var skipMacJunk: Bool = true
    @State private var selectedPresetID: UUID? = nil
    
    @State private var isAlgorithmMatrixPresented: Bool = false
    @State private var isCompressionGuidePresented: Bool = false
    @State private var isPasswordVaultPresented: Bool = false
    
    @State private var cpuThreadsOption: String = "All Cores"
    @State private var dictionarySizeMB: Int = 32
    @State private var compressionAlgorithm: String = "LZMA2"
    @State private var zipEncryptionMethod: String = "AES-256"
    @State private var zipEncodingUTF8: Bool = true
    @State private var zstdLevel: Int = 3
    @State private var zstdEnableLDM: Bool = false
    @State private var preservePosixAttributes: Bool = true
    @State private var enableSolidArchive: Bool = true
    @State private var encryptFileNames: Bool = true
    
    @State private var isProcessing: Bool = false
    @State private var isProgressModalPresented: Bool = false
    @State private var currentProgress: ArchiveProgress = .zero
    @State private var activeCompressionTask: Task<Void, Never>? = nil
    
    @State private var isSummarySheetPresented: Bool = false
    @State private var completedArchivePath: String = ""
    @State private var completedOriginalBytes: Int64 = 0
    @State private var completedCompressedBytes: Int64 = 0
    @State private var completedElapsedSeconds: Double = 0.0
    @State private var completedThroughputMBs: Double = 0.0
    
    private let cachedTotalCores = AppleSiliconTuner.shared.topology.totalCores
    
    public init(isPresented: Binding<Bool>, initialInputPaths: [String], onCompleteOpenArchive: ((String) -> Void)? = nil) {
        self._isPresented = isPresented
        self.initialInputPaths = initialInputPaths
        self.onCompleteOpenArchive = onCompleteOpenArchive
    }
    
    private var totalSizeBytes: Int64 {
        itemsList.reduce(0) { $0 + $1.size }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            CompressModalHeaderView(
                selectedPresetID: $selectedPresetID,
                onOpenGuide: { isCompressionGuidePresented = true },
                onClose: { isPresented = false }
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CompressFileListView(
                        itemsList: $itemsList,
                        selectedItemIDs: $selectedItemIDs,
                        totalSizeBytes: totalSizeBytes,
                        onAddFiles: pickFiles,
                        onAddFolder: pickFolders,
                        onClearAll: { itemsList.removeAll() },
                        onRemoveSelected: removeSelectedItems
                    )
                    
                    CompressIntegratedConfigSectionView(
                        outputName: $outputName,
                        targetDirectory: $targetDirectory,
                        selectedFormat: $selectedFormat,
                        compressionLevel: $compressionLevel,
                        compressionAlgorithm: $compressionAlgorithm,
                        dictionarySizeMB: $dictionarySizeMB,
                        zipEncryptionMethod: $zipEncryptionMethod,
                        zipEncodingUTF8: $zipEncodingUTF8,
                        zstdLevel: $zstdLevel,
                        zstdEnableLDM: $zstdEnableLDM,
                        preservePosixAttributes: $preservePosixAttributes,
                        cpuThreadsOption: $cpuThreadsOption,
                        splitVolumeOption: $splitVolumeOption,
                        isCustomVolumeSelected: $isCustomVolumeSelected,
                        customVolumeValueString: $customVolumeValueString,
                        customVolumeUnit: $customVolumeUnit,
                        enableEncryption: $enableEncryption,
                        password: $password,
                        enableSolidArchive: $enableSolidArchive,
                        encryptFileNames: $encryptFileNames,
                        skipMacJunk: $skipMacJunk,
                        createSeparateArchives: $createSeparateArchives,
                        deleteSourceAfterCompress: $deleteSourceAfterCompress,
                        openFinderAfterCompress: $openFinderAfterCompress,
                        cachedTotalCores: cachedTotalCores,
                        onPickDirectory: pickDirectory,
                        onOpenPasswordVault: { isPasswordVaultPresented = true },
                        onShowMatrix: { isAlgorithmMatrixPresented = true }
                    )
                }
                .padding(16)
            }
            
            Divider()
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text(l10n.plural(key: L10n.Units.itemsCount, count: itemsList.count) + " · " + l10n.formatBytes(totalSizeBytes))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Text(l10n.t(L10n.Common.cancel))
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: startCompression) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(l10n.t(L10n.Compress.startAction) + " (⌘↵)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(TTZipTheme.bambooGradient)
                    .clipShape(Capsule())
                    .shadow(color: TTZipTheme.bambooGreen.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || itemsList.isEmpty || outputName.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 680, height: 600)
        .onAppear {
            if itemsList.isEmpty && !initialInputPaths.isEmpty {
                self.itemsList = initialInputPaths.map { CompressFileItem(path: $0) }
                if let first = initialInputPaths.first {
                    let parent = (first as NSString).deletingLastPathComponent
                    if !parent.isEmpty { self.targetDirectory = parent }
                    let name = (first as NSString).lastPathComponent
                    self.outputName = (name as NSString).deletingPathExtension
                }
            }
        }
        .sheet(isPresented: $isCompressionGuidePresented) {
            CompressionGuideSheetView(isPresented: $isCompressionGuidePresented)
        }
        .sheet(isPresented: $isPasswordVaultPresented) {
            VStack {
                HStack {
                    Spacer()
                    Button(l10n.t(L10n.Common.close)) { isPasswordVaultPresented = false }
                }
                .padding()
                PasswordVaultView(onSelectPassword: { pwd in
                    enableEncryption = true
                    password = pwd
                    isPasswordVaultPresented = false
                })
            }
            .frame(width: 600, height: 400)
        }
        .overlay {
            if isProgressModalPresented {
                CompressionProgressModalView(
                    outputFileName: "\(outputName).\(selectedFormat.rawValue)",
                    progress: currentProgress,
                    onCancel: {
                        activeCompressionTask?.cancel()
                        isProgressModalPresented = false
                    },
                    onMinimize: { isProgressModalPresented = false }
                )
            } else if isSummarySheetPresented {
                CompressionSummarySheetView(
                    archivePath: completedArchivePath,
                    originalSizeBytes: completedOriginalBytes,
                    compressedSizeBytes: completedCompressedBytes,
                    elapsedSeconds: completedElapsedSeconds,
                    throughputMBs: completedThroughputMBs,
                    format: selectedFormat,
                    isEncrypted: enableEncryption,
                    onCloseAndExplore: {
                        isSummarySheetPresented = false
                        isPresented = false
                        onCompleteOpenArchive?(completedArchivePath)
                    }
                )
            }
        }
        .onChange(of: selectedPresetID) { _, newID in
            if let id = newID, let preset = PresetManager.shared.presets.first(where: { $0.id == id }) {
                let snapshot = preset.clone()
                selectedFormat = snapshot.format
                compressionLevel = snapshot.level
                splitVolumeOption = snapshot.splitVolumeSizeBytes
                if let pwd = snapshot.defaultPassword, !pwd.isEmpty {
                    enableEncryption = true
                    password = pwd
                }
                skipMacJunk = snapshot.skipMacJunk
            }
        }
    }
    
    private func pickFiles() {
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
    
    private func pickFolders() {
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
    
    private func removeSelectedItems() {
        itemsList.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
    }
    
    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            targetDirectory = url.path
        }
    }
    
    private func startCompression() {
        guard !isProcessing && !itemsList.isEmpty && !outputName.isEmpty else { return }
        let ext = selectedFormat.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let inputPaths = itemsList.map { $0.path }
        let fullOutputPath = (targetDirectory as NSString).appendingPathComponent("\(outputName).\(ext)")
        let valCtx = ArchiveValidationContext.forCompress(
            sourcePaths: inputPaths,
            destinationPath: fullOutputPath,
            format: selectedFormat,
            level: compressionLevel,
            password: enableEncryption ? password : nil,
            splitSize: splitVolumeOption
        )
        let valResult = (try? ArchiveValidationPipeline.buildDefaultCompressPipeline().validate(context: valCtx)) ?? .success
        if case .failure(let err) = valResult {
            TTLogger.warning("Compression validation intercept: \(err.localizedDescription)")
            return
        }
        
        isProcessing = true
        isProgressModalPresented = true
        ArchiveAppMediator.shared.send(event: .requestCompression(inputPaths: inputPaths, outputPath: fullOutputPath))
        
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
                
                ArchiveAppMediator.shared.send(event: .compressionCompleted(outputPath: fullOutputPath))
                
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
