// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unified protocol for strongly-typed localization keys.
public protocol LocaleKeyProtocol: Sendable {
    var rawKey: String { get }
}

public extension LocaleKeyProtocol where Self: RawRepresentable, RawValue == String {
    @inlinable var rawKey: String { rawValue }
}

/// Strongly-typed namespaced localization keys.
public enum L10n {
    
    // MARK: - 1. Common Actions & States
    public enum Common: String, LocaleKeyProtocol, CaseIterable {
        case cancel = "common.cancel"
        case ok = "common.ok"
        case done = "common.done"
        case save = "common.save"
        case close = "common.close"
        case retry = "common.retry"
        case delete = "common.delete"
        case apply = "common.apply"
        case search = "common.search"
        case success = "common.success"
        case failed = "common.failed"
        case loading = "common.loading"
        case warning = "common.warning"
        case error = "common.error"
        case processing = "common.processing"
        case copy = "common.copy"
        case paste = "common.paste"
        case clear = "common.clear"
        case export = "common.export"
        case importAction = "common.import"
        case selectAll = "common.select_all"
        case revealInFinder = "common.reveal_in_finder"
        case selectDestination = "common.select_destination"
        case openFiles = "common.open_files"
        case chooseFolder = "common.choose_folder"
    }
    
    // MARK: - 2. Sidebar Navigation & Layout
    public enum Sidebar: String, LocaleKeyProtocol, CaseIterable {
        case homeAndExtract = "sidebar.home_and_extract"
        case newArchive = "sidebar.new_archive"
        case presets = "sidebar.presets"
        case benchmark = "sidebar.benchmark"
        case vault = "sidebar.vault"
        case licensing = "sidebar.licensing"
        case settings = "sidebar.settings"
        case queue = "sidebar.queue"
        case indexHeader = "sidebar.index_header"
        case proBadge = "sidebar.pro_badge"
        case openArchiveHeader = "sidebar.open_archive_header"
        case printedInMacOS = "sidebar.printed_in_macos"
        case zeroCopyAcceleration = "sidebar.zero_copy_acceleration"
    }
    
    // MARK: - 3. File Explorer & Archive Outline
    public enum Explorer: String, LocaleKeyProtocol, CaseIterable {
        case columnsView = "explorer.columns_view"
        case gridView = "explorer.grid_view"
        case listView = "explorer.list_view"
        case sortByName = "explorer.sort_by_name"
        case sortBySize = "explorer.sort_by_size"
        case sortByDate = "explorer.sort_by_date"
        case sortByKind = "explorer.sort_by_kind"
        case emptyDirectory = "explorer.empty_directory"
        case dragDropPrompt = "explorer.drag_drop_prompt"
        case encryptedBadge = "explorer.encrypted_badge"
        case quickLook = "explorer.quick_look"
        case deleteEntryPrompt = "explorer.delete_entry_prompt"
        case folderComposition = "explorer.folder_composition"
        case extractToPrompt = "explorer.extract_to_prompt"
        case nameHeader = "explorer.name_header"
        case sizeHeader = "explorer.size_header"
        case ratioHeader = "explorer.ratio_header"
        case dateHeader = "explorer.date_header"
        case kindHeader = "explorer.kind_header"
        case crc32Header = "explorer.crc32_header"
        case compressedSizeHeader = "explorer.compressed_size_header"
        case itemsCountHeader = "explorer.items_count_header"
        case folderHeader = "explorer.folder_header"
        case archiveHeader = "explorer.archive_header"
        case passwordProtectedArchive = "explorer.password_protected_archive"
        case loadingArchiveStructure = "explorer.loading_archive_structure"
    }
    
    // MARK: - 4. Compression Options & Progress
    public enum Compress: String, LocaleKeyProtocol, CaseIterable {
        case title = "compress.title"
        case startAction = "compress.start_action"
        case format = "compress.format"
        case level = "compress.level"
        case levelStore = "compress.level_store"
        case levelFastest = "compress.level_fastest"
        case levelNormal = "compress.level_normal"
        case levelMaximum = "compress.level_maximum"
        case levelUltra = "compress.level_ultra"
        case solidArchive = "compress.solid_archive"
        case splitVolume = "compress.split_volume"
        case splitVolumeCustom = "compress.split_volume_custom"
        case splitVolumeNone = "compress.split_volume_none"
        case encryption = "compress.encryption"
        case encryptFileNames = "compress.encrypt_file_names"
        case deleteSource = "compress.delete_source"
        case openFinder = "compress.open_finder"
        case filterMacJunk = "compress.filter_mac_junk"
        case cpuThreads = "compress.cpu_threads"
        case allCores = "compress.all_cores"
        case dictionarySize = "compress.dictionary_size"
        case summaryOriginal = "compress.summary_original"
        case summaryCompressed = "compress.summary_compressed"
        case summaryRatio = "compress.summary_ratio"
        case summarySpeed = "compress.summary_speed"
        case fastPresetDesc = "compress.fast_preset_desc"
        case normalPresetDesc = "compress.normal_preset_desc"
        case maximumPresetDesc = "compress.maximum_preset_desc"
        case smartStoreBypassTitle = "compress.smart_store_bypass_title"
        case smartStoreBypassDesc = "compress.smart_store_bypass_desc"
        case targetFolder = "compress.target_folder"
        case archiveNamePlaceholder = "compress.archive_name_placeholder"
    }
    
    // MARK: - 5. Extraction Workflow
    public enum Extract: String, LocaleKeyProtocol, CaseIterable {
        case title = "extract.title"
        case action = "extract.action"
        case here = "extract.here"
        case toSubfolder = "extract.to_subfolder"
        case destination = "extract.destination"
        case autoOpenFolder = "extract.auto_open_folder"
        case passwordPrompt = "extract.password_prompt"
        case saveToVault = "extract.save_to_vault"
        case conflictOverwrite = "extract.conflict_overwrite"
        case conflictSkip = "extract.conflict_skip"
        case conflictRename = "extract.conflict_rename"
        case successNotice = "extract.success_notice"
        case failureNotice = "extract.failure_notice"
        case enterPasswordPlaceholder = "extract.enter_password_placeholder"
        case incorrectPasswordPrompt = "extract.incorrect_password_prompt"
        case extractingTo = "extract.extracting_to"
        case totalExtractedFiles = "extract.total_extracted_files"
        case speedMetric = "extract.speed_metric"
    }
    
    // MARK: - 6. Benchmark Metrics & Speed Test
    public enum Benchmark: String, LocaleKeyProtocol, CaseIterable {
        case throughput = "benchmark.throughput"
        case compressionRatio = "benchmark.compression_ratio"
        case duration = "benchmark.duration"
        case memoryUsage = "benchmark.memory_usage"
        case peakThroughput = "benchmark.peak_throughput"
        case speedup = "benchmark.speedup"
        case runAction = "benchmark.run_action"
        case passStatus = "benchmark.pass_status"
        case appleSiliconTopology = "benchmark.apple_silicon_topology"
        case competitorCompare = "benchmark.competitor_compare"
        case benchmarkMatrixTitle = "benchmark.benchmark_matrix_title"
        case benchmarkSuiteShortcut = "benchmark.benchmark_suite_shortcut"
        case spaceReducedSummary = "benchmark.space_reduced_summary"
        case singleCoreVsMultiCore = "benchmark.single_core_vs_multicore"
        case hardwareCoresFormat = "benchmark.hardware_cores_format"
        case hardwareMemoryFormat = "benchmark.hardware_memory_format"
        case liveDialTitle = "benchmark.live_dial_title"
    }
    
    // MARK: - 7. Custom Presets Workspace
    public enum Presets: String, LocaleKeyProtocol, CaseIterable {
        case title = "presets.title"
        case createNew = "presets.create_new"
        case duplicate = "presets.duplicate"
        case resetDefaults = "presets.reset_defaults"
        case proConfig = "presets.pro_config"
        case undo = "presets.undo"
        case redo = "presets.redo"
        case saveDraft = "presets.save_draft"
        case name = "presets.name"
        case desc = "presets.desc"
        case deletePreset = "presets.delete_preset"
        case presetNamePlaceholder = "presets.preset_name_placeholder"
        case formatSelector = "presets.format_selector"
        case compressionTier = "presets.compression_tier"
        case filterMacJunkOption = "presets.filter_mac_junk_option"
        case solidBlockOption = "presets.solid_block_option"
    }
    
    // MARK: - 8. Password Keychain Vault
    public enum Vault: String, LocaleKeyProtocol, CaseIterable {
        case title = "vault.title"
        case unlockPrompt = "vault.unlock_prompt"
        case addPassword = "vault.add_password"
        case emptyVault = "vault.empty_vault"
        case labelPlaceholder = "vault.label_placeholder"
        case passwordPlaceholder = "vault.password_placeholder"
        case unlockButton = "vault.unlock_button"
        case lockVault = "vault.lock_vault"
        case deleteEntry = "vault.delete_entry"
        case copyPassword = "vault.copy_password"
        case biometricPrompt = "vault.biometric_prompt"
        case vaultSecurityHeader = "vault.vault_security_header"
        case pbkdf2Desc = "vault.pbkdf2_desc"
        case volatileZeroingDesc = "vault.volatile_zeroing_desc"
        case aesGcmStorageDesc = "vault.aes_gcm_storage_desc"
        case noPasswordsSavedPrompt = "vault.no_passwords_saved_prompt"
    }
    
    // MARK: - 9. Preferences & Settings
    public enum Settings: String, LocaleKeyProtocol, CaseIterable {
        case title = "settings.title"
        case general = "settings.general"
        case localization = "settings.localization"
        case language = "settings.language"
        case byteUnits = "settings.byte_units"
        case unitSI = "settings.unit_si"
        case unitIEC = "settings.unit_iec"
        case licenseStatus = "settings.license_status"
        case hardwareTopology = "settings.hardware_topology"
        case defaultFormat = "settings.default_format"
        case finderIntegration = "settings.finder_integration"
        case smartStoreBypass = "settings.smart_store_bypass"
        case bypassHighEntropyDesc = "settings.bypass_high_entropy_desc"
        case instantSwitchNote = "settings.instant_switch_note"
        case proLicenseActive = "settings.pro_license_active"
        case freeEdition = "settings.free_edition"
        case macAppStoreLicenseActive = "settings.mac_app_store_license_active"
        case enterActivationKey = "settings.enter_activation_key"
        case activateProButton = "settings.activate_pro_button"
        case deactivateButton = "settings.deactivate_button"
        case licenseStatusActive = "settings.license_status_active"
        case invalidKeyError = "settings.invalid_key_error"
        case chipModel = "settings.chip_model"
        case cpuCores = "settings.cpu_cores"
        case unifiedMemory = "settings.unified_memory"
    }
    
    // MARK: - 10. Operations Queue
    public enum Queue: String, LocaleKeyProtocol, CaseIterable {
        case title = "queue.title"
        case activeTasks = "queue.active_tasks"
        case overallThroughput = "queue.overall_throughput"
        case emptyQueue = "queue.empty_queue"
        case cancelTask = "queue.cancel_task"
        case pauseAll = "queue.pause_all"
        case resumeAll = "queue.resume_all"
        case taskCompressing = "queue.task_compressing"
        case taskExtracting = "queue.task_extracting"
        case taskWaiting = "queue.task_waiting"
        case taskCompleted = "queue.task_completed"
        case taskCancelled = "queue.task_cancelled"
        case taskFailed = "queue.task_failed"
        case clearCompleted = "queue.clear_completed"
    }
    
    // MARK: - Meta-Type Registration & Reflective Key Collection
    public static let allKeyGroups: [any (LocaleKeyProtocol & CaseIterable).Type] = [
        Common.self, Sidebar.self, Explorer.self, Compress.self, Extract.self,
        Benchmark.self, Presets.self, Vault.self, Settings.self, Queue.self,
        Preview.self, Menu.self, Dialogs.self, Errors.self, Units.self,
        CLI.self, Notification.self
    ]
    
    /// Returns all defined raw keys across all localization namespaces.
    public static var allRawKeys: [String] {
        var keys: [String] = []
        for group in allKeyGroups {
            if let groupCases = group.allCases as? [any LocaleKeyProtocol] {
                keys.append(contentsOf: groupCases.map(\.rawKey))
            }
        }
        return keys
    }
}
