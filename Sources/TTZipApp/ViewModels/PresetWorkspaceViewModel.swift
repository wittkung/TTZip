import SwiftUI
import TTZipCore

@MainActor
public final class PresetWorkspaceViewModel: ObservableObject, ArchiveMediatorComponentProtocol {
    public typealias Memento = PresetEditorMemento
    
    // MARK: - 【4.5 依赖注入模式 (Dependency Injection Pattern)】使用 @Injected 解耦 PresetManager 与 Mediator
    @Injected public var manager: PresetManager
    @Injected public var appMediator: ArchiveMediatorProtocol
    
    nonisolated public var mediator: ArchiveMediatorProtocol? {
        get { ArchiveAppMediator.shared }
        set {}
    }

    @Published public var presets: [CompressionPreset] = []
    @Published public var selectedPresetID: UUID? = nil
    
    // 当前选中预设的编辑状态
    @Published public var editorName: String = ""
    @Published public var editorFormat: ArchiveCompressionFormat = .sevenZip
    @Published public var editorLevel: ArchiveCompressionLevel = .normal
    @Published public var editorSplitVolumeOption: Int64? = nil
    @Published public var editorSkipMacJunk: Bool = true
    @Published public var editorSkipGitDirectory: Bool = false
    @Published public var editorDefaultPassword: String = ""
    
    @Published public var activeEditingPrototype: CompressionPreset? = nil
    @Published public var statusMessage: String = ""
    
    // MARK: - 【3.9 备忘录模式 (Memento Pattern)】草稿历史管理者
    public let caretaker = PresetEditorCaretaker()
    
    public init(manager: PresetManager = .shared) {
        appMediator.register(component: self)
        loadPresets()
    }
    
    nonisolated public func receive(event: AppMediatorEvent) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                if case .presetSelected(let presetIdStr) = event, let uuid = UUID(uuidString: presetIdStr) {
                    if self.selectedPresetID != uuid, let preset = self.presets.first(where: { $0.id == uuid }) {
                        self.selectedPresetID = uuid
                        self.loadPresetIntoEditor(preset)
                    }
                }
            }
        } else {
            Task { @MainActor in
                if case .presetSelected(let presetIdStr) = event, let uuid = UUID(uuidString: presetIdStr) {
                    if self.selectedPresetID != uuid, let preset = self.presets.first(where: { $0.id == uuid }) {
                        self.selectedPresetID = uuid
                        self.loadPresetIntoEditor(preset)
                    }
                }
            }
        }
    }
    
    nonisolated public func receive(event: CoreEngineMediatorEvent) {}
    
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
    
    /// 使用原型模式 (Prototype Pattern) 克隆当前预设进入编辑态
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
        
        caretaker.clear()
        saveDraftSnapshot()
        
        mediator?.send(event: .presetSelected(presetId: preset.id.uuidString), from: self)
    }
    
    // MARK: - 【3.9 备忘录模式 (Memento Pattern)】Originator 协议实现
}

extension PresetWorkspaceViewModel: ArchiveOriginatorProtocol {
    nonisolated public func createMemento() -> PresetEditorMemento {
        MainActor.assumeIsolated {
            PresetEditorMemento(
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
    }
    
    nonisolated public func restoreMemento(_ memento: PresetEditorMemento) {
        MainActor.assumeIsolated {
            self.selectedPresetID = memento.presetID
            self.editorName = memento.name
            self.editorFormat = memento.format
            self.editorLevel = memento.level
            self.editorSplitVolumeOption = memento.splitVolumeSizeBytes
            self.editorSkipMacJunk = memento.skipMacJunk
            self.editorSkipGitDirectory = memento.skipGitDirectory
            self.editorDefaultPassword = memento.defaultPassword
        }
    }
}

extension PresetWorkspaceViewModel {
    
    /// 自动记录当前编辑状态至 Caretaker 历史栈
    public func saveDraftSnapshot() {
        caretaker.saveMemento(createMemento())
    }
    
    /// 撤销草稿修改 (⌘Z)
    public func undoDraft() {
        if let previous = caretaker.undo() {
            restoreMemento(previous)
            statusMessage = "已撤销草稿 (⌘Z)"
        }
    }
    
    /// 重做草稿修改 (⇧⌘Z)
    public func redoDraft() {
        if let next = caretaker.redo() {
            restoreMemento(next)
            statusMessage = "已重做草稿 (⇧⌘Z)"
        }
    }
    
    /// 放弃草稿修改
    public func discardDraft() {
        guard let id = selectedPresetID, let current = presets.first(where: { $0.id == id }) else { return }
        loadPresetIntoEditor(current)
        statusMessage = "已放弃草稿修改"
    }
    
    public var canUndoDraft: Bool {
        caretaker.canUndo
    }
    
    public var canRedoDraft: Bool {
        caretaker.canRedo
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
        statusMessage = "保存成功！"
    }
    
    public func createNewPreset() {
        let basePreset = presets.first ?? PresetManager.defaultBuiltInPresets[0]
        let newPreset = basePreset.clone(
            newId: UUID(),
            newName: "自定义预设 \(presets.count + 1)"
        )
        presets.append(newPreset)
        manager.savePreset(newPreset)
        selectedPresetID = newPreset.id
        loadPresetIntoEditor(newPreset)
    }
    
    /// 使用原型模式 (Prototype Pattern) 克隆衍生当前选中的预设方案
    public func duplicateSelectedPreset() {
        guard let id = selectedPresetID else { return }
        duplicatePreset(id: id)
    }
    
    /// 基于指定预设的原型 ID 衍生新预设
    public func duplicatePreset(id: UUID) {
        if let cloned = manager.duplicatePreset(id: id) {
            presets = manager.presets
            selectedPresetID = cloned.id
            loadPresetIntoEditor(cloned)
            statusMessage = "已基于原型生成克隆预设！"
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
        case .store: return "仅打包存储，不进行 CPU 压缩计算"
        case .fastest, .fast, .fast1, .fast2, .fast3, .fast4, .fast5: return "注重物理速度，占用极低 CPU 算力"
        case .normal, .level5, .level6, .level7: return "平衡压缩率与打包解压时间"
        case .maximum, .ultra, .level8, .level9, .level10, .level11, .level12, .level13, .level14, .level15, .level16, .level17, .level18, .level19, .level20, .level21, .level22: return "极致算法吞吐，适合高密度文件存档"
        default: return ""
        }
    }
}
