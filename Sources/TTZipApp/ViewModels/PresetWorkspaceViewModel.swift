// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct PresetDraftState: Sendable, Equatable {
    public let presetID: UUID
    public let name: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let splitVolumeSizeBytes: Int64?
    public let skipMacJunk: Bool
    public let skipGitDirectory: Bool
    public let defaultPassword: String
}

@MainActor
public final class PresetWorkspaceViewModel: ObservableObject {
    public var manager: PresetManager

    @Published public var presets: [CompressionPreset] = []
    @Published public var selectedPresetID: UUID? = nil
    
    // Preset Editor State
    @Published public var editorName: String = ""
    @Published public var editorFormat: ArchiveCompressionFormat = .sevenZip
    @Published public var editorLevel: ArchiveCompressionLevel = .normal
    @Published public var editorSplitVolumeOption: Int64? = nil
    @Published public var editorSkipMacJunk: Bool = true
    @Published public var editorSkipGitDirectory: Bool = false
    @Published public var editorDefaultPassword: String = ""
    
    @Published public var activeEditingPrototype: CompressionPreset? = nil
    @Published public var statusMessage: String = ""
    
    private var undoStack: [PresetDraftState] = []
    private var redoStack: [PresetDraftState] = []
    
    public init(manager: PresetManager = .shared) {
        self.manager = manager
        loadPresets()
    }
    
    public func loadPresets() {
        self.presets = manager.presets
        if self.presets.isEmpty {
            manager.resetToDefaults()
            self.presets = manager.presets
            self.selectedPresetID = nil
        }
        if selectedPresetID == nil || !presets.contains(where: { $0.id == selectedPresetID }) {
            if let first = presets.first {
                selectedPresetID = first.id
                loadPresetIntoEditor(first)
            } else {
                selectedPresetID = nil
                activeEditingPrototype = nil
            }
        } else if let id = selectedPresetID, let current = presets.first(where: { $0.id == id }) {
            loadPresetIntoEditor(current)
        }
    }
    
    /// Loads cloned preset prototype into editor.
    public func loadPresetIntoEditor(_ preset: CompressionPreset) {
        let prototype = preset.clone()
        self.activeEditingPrototype = prototype
        editorName = prototype.name
        editorFormat = prototype.format
        editorLevel = prototype.level
        editorSplitVolumeOption = prototype.splitVolumeSizeBytes
        editorSkipMacJunk = prototype.skipMacJunk
        editorSkipGitDirectory = prototype.skipGitDirectory
        editorDefaultPassword = prototype.defaultPassword ?? ""
        statusMessage = ""
        
        undoStack.removeAll()
        redoStack.removeAll()
        saveDraftSnapshot()
    }
    
    public func currentDraftState() -> PresetDraftState {
        PresetDraftState(
            presetID: self.selectedPresetID ?? UUID(),
            name: self.editorName,
            format: self.editorFormat,
            level: self.editorLevel,
            splitVolumeSizeBytes: self.editorSplitVolumeOption,
            skipMacJunk: self.editorSkipMacJunk,
            skipGitDirectory: self.editorSkipGitDirectory,
            defaultPassword: self.editorDefaultPassword
        )
    }
    
    public func restoreDraftState(_ draft: PresetDraftState) {
        self.selectedPresetID = draft.presetID
        self.editorName = draft.name
        self.editorFormat = draft.format
        self.editorLevel = draft.level
        self.editorSplitVolumeOption = draft.splitVolumeSizeBytes
        self.editorSkipMacJunk = draft.skipMacJunk
        self.editorSkipGitDirectory = draft.skipGitDirectory
        self.editorDefaultPassword = draft.defaultPassword
    }
    
    public func saveDraftSnapshot() {
        undoStack.append(currentDraftState())
        redoStack.removeAll()
    }
    
    public func undoDraft() {
        guard undoStack.count > 1 else { return }
        let current = undoStack.removeLast()
        redoStack.append(current)
        if let previous = undoStack.last {
            restoreDraftState(previous)
            statusMessage = "Draft undone (⌘Z)"
        }
    }
    
    public func redoDraft() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(next)
        restoreDraftState(next)
        statusMessage = "Draft redone (⇧⌘Z)"
    }
    
    public func discardDraft() {
        guard let id = selectedPresetID, let current = presets.first(where: { $0.id == id }) else { return }
        loadPresetIntoEditor(current)
        statusMessage = "Draft discarded"
    }
    
    public var canUndoDraft: Bool {
        undoStack.count > 1
    }
    
    public var canRedoDraft: Bool {
        !redoStack.isEmpty
    }
    
    public func saveActivePreset() {
        guard let id = selectedPresetID, let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let basePrototype = activeEditingPrototype ?? presets[index]
        var updated = basePrototype.clone(newId: id, newName: editorName)
        updated.format = editorFormat
        updated.level = editorLevel
        updated.splitVolumeSizeBytes = editorSplitVolumeOption
        updated.defaultPassword = editorDefaultPassword.isEmpty ? nil : editorDefaultPassword
        updated.skipMacJunk = editorSkipMacJunk
        updated.skipGitDirectory = editorSkipGitDirectory
        
        presets[index] = updated
        activeEditingPrototype = updated
        manager.savePreset(updated)
        statusMessage = "Saved successfully"
    }
    
    public func createNewPreset() {
        let basePreset = presets.first ?? PresetManager.defaultBuiltInPresets[0]
        let newPreset = basePreset.clone(
            newId: UUID(),
            newName: "Custom Preset \(presets.count + 1)"
        )
        presets.append(newPreset)
        manager.savePreset(newPreset)
        selectedPresetID = newPreset.id
        loadPresetIntoEditor(newPreset)
    }
    
    public func duplicateSelectedPreset() {
        guard let id = selectedPresetID else { return }
        duplicatePreset(id: id)
    }
    
    public func duplicatePreset(id: UUID) {
        if let cloned = manager.duplicatePreset(id: id) {
            presets = manager.presets
            selectedPresetID = cloned.id
            loadPresetIntoEditor(cloned)
            statusMessage = "Preset cloned"
        }
    }

    public func resetToDefaults() {
        manager.resetToDefaults()
        presets = manager.presets
        if let first = presets.first {
            selectedPresetID = first.id
            loadPresetIntoEditor(first)
        }
    }
    
    public func deleteSelectedPreset() {
        guard let id = selectedPresetID else { return }
        manager.deletePreset(id: id)
        presets = manager.presets
        if let first = presets.first {
            selectedPresetID = first.id
            loadPresetIntoEditor(first)
        }
    }
    
    public func levelDescription(_ level: ArchiveCompressionLevel) -> String {
        switch level {
        case .store: return "Pack only without compression"
        case .fastest, .fast, .fast1, .fast2, .fast3, .fast4, .fast5: return "High speed with low CPU usage"
        case .normal, .level5, .level6, .level7: return "Balanced compression ratio and speed"
        case .maximum, .ultra, .level8, .level9, .level10, .level11, .level12, .level13, .level14, .level15, .level16, .level17, .level18, .level19, .level20, .level21, .level22: return "Maximum ratio for dense archive storage"
        default: return ""
        }
    }
}
