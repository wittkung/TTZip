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
    @ObservedObject var l10n = AppLocalizationState.shared
    @Binding public var isPresented: Bool
    public let initialInputPaths: [String]
    public var onCompleteOpenArchive: ((String) -> Void)? = nil
    
    @State var itemsList: [CompressFileItem] = []
    @State var selectedItemIDs: Set<CompressFileItem.ID> = []
    @State var outputName: String = "Archive"
    @State var targetDirectory: String = NSHomeDirectory()
    @State var selectedFormat: ArchiveCompressionFormat = .sevenZip
    @State var compressionLevel: ArchiveCompressionLevel = .normal
    @State var splitVolumeOption: Int64? = nil
    @State var isCustomVolumeSelected: Bool = false
    @State var customVolumeValueString: String = "100"
    @State var customVolumeUnit: String = "MB"
    @State var enableEncryption: Bool = false
    @State var password: String = ""
    @State var createSeparateArchives: Bool = false
    @State var deleteSourceAfterCompress: Bool = false
    @State var openFinderAfterCompress: Bool = true
    @State var skipMacJunk: Bool = true
    @State var selectedPresetID: UUID? = nil
    
    @State var isAlgorithmMatrixPresented: Bool = false
    @State var isCompressionGuidePresented: Bool = false
    @State var isPasswordVaultPresented: Bool = false
    
    @State var cpuThreadsOption: String = "All Cores"
    @State var dictionarySizeMB: Int = 32
    @State var compressionAlgorithm: String = "LZMA2"
    @State var zipEncryptionMethod: String = "AES-256"
    @State var zipEncodingUTF8: Bool = true
    @State var zstdLevel: Int = 3
    @State var zstdEnableLDM: Bool = false
    @State var preservePosixAttributes: Bool = true
    @State var enableSolidArchive: Bool = true
    @State var encryptFileNames: Bool = true
    
    @State var isProcessing: Bool = false
    @State var isProgressModalPresented: Bool = false
    @State var currentProgress: ArchiveProgress = .zero
    @State var activeCompressionTask: Task<Void, Never>? = nil
    
    @State var isSummarySheetPresented: Bool = false
    @State var completedArchivePath: String = ""
    @State var completedOriginalBytes: Int64 = 0
    @State var completedCompressedBytes: Int64 = 0
    @State var completedElapsedSeconds: Double = 0.0
    @State var completedThroughputMBs: Double = 0.0
    
    let cachedTotalCores = AppleSiliconTuner.shared.topology.totalCores
    
    public init(isPresented: Binding<Bool>, initialInputPaths: [String], onCompleteOpenArchive: ((String) -> Void)? = nil) {
        self._isPresented = isPresented
        self.initialInputPaths = initialInputPaths
        self.onCompleteOpenArchive = onCompleteOpenArchive
    }
    
    var totalSizeBytes: Int64 {
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
}
