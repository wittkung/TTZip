// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension L10n {
    
    // MARK: - 11. Media & Document Previews
    public enum Preview: String, LocaleKeyProtocol, CaseIterable {
        case loading = "preview.loading"
        case unsupported = "preview.unsupported"
        case fullScreen = "preview.full_screen"
        case exitFullScreen = "preview.exit_full_screen"
        case pageCount = "preview.page_count"
        case dimensions = "preview.dimensions"
        case rawTextView = "preview.raw_text_view"
        case audioVisualizer = "preview.audio_visualizer"
        case documentReader = "preview.document_reader"
        case syntaxHighlighting = "preview.syntax_highlighting"
        case cannotPreviewFormat = "preview.cannot_preview_format"
        case mediaMetadata = "preview.media_metadata"
    }
    
    // MARK: - 12. AppKit Menu & Finder Extensions
    public enum Menu: String, LocaleKeyProtocol, CaseIterable {
        case about = "menu.about"
        case hide = "menu.hide"
        case hideOthers = "menu.hide_others"
        case showAll = "menu.show_all"
        case quit = "menu.quit"
        case closeWindow = "menu.close_window"
        case minimize = "menu.minimize"
        case zoom = "menu.zoom"
        case fileMenu = "menu.file_menu"
        case editMenu = "menu.edit_menu"
        case viewMenu = "menu.view_menu"
        case windowMenu = "menu.window_menu"
        case helpMenu = "menu.help_menu"
        case checkForUpdates = "menu.check_for_updates"
        case preferences = "menu.preferences"
        case openArchive = "menu.open_archive"
        case newArchiveMenu = "menu.new_archive_menu"
        case selectAllMenu = "menu.select_all_menu"
        case toggleFullScreen = "menu.toggle_full_screen"
        case finderExtractHere = "menu.finder_extract_here"
        case finderExtractSubfolder = "menu.finder_extract_subfolder"
        case finderInspect = "menu.finder_inspect"
        case finderAutofillVault = "menu.finder_autofill_vault"
        case finderComputeHash = "menu.finder_compute_hash"
        case finderCompress7z = "menu.finder_compress_7z"
        case finderCompressZip = "menu.finder_compress_zip"
        case finderCompressSeparate = "menu.finder_compress_separate"
        case finderCompressDeleteSource = "menu.finder_compress_delete_source"
        case finderCompressAdvanced = "menu.finder_compress_advanced"
    }
    
    // MARK: - 13. System Dialogs & Confirmations
    public enum Dialogs: String, LocaleKeyProtocol, CaseIterable {
        case confirmDeleteTitle = "dialogs.confirm_delete_title"
        case confirmDeleteMessage = "dialogs.confirm_delete_message"
        case overwriteTitle = "dialogs.overwrite_title"
        case overwriteMessage = "dialogs.overwrite_message"
        case unsavedChangesTitle = "dialogs.unsaved_changes_title"
        case unsavedChangesMessage = "dialogs.unsaved_changes_message"
        case wrongPasswordTitle = "dialogs.wrong_password_title"
        case wrongPasswordMessage = "dialogs.wrong_password_message"
        case operationErrorTitle = "dialogs.operation_error_title"
        case alertOk = "dialogs.alert_ok"
        case alertCancel = "dialogs.alert_cancel"
        case alertOverwrite = "dialogs.alert_overwrite"
        case alertSkip = "dialogs.alert_skip"
    }
    
    // MARK: - 14. Error Diagnostics & Defense
    public enum Errors: String, LocaleKeyProtocol, CaseIterable {
        case fileNotFound = "error.file_not_found"
        case permissionDenied = "error.permission_denied"
        case diskFull = "error.disk_full"
        case zipSlipDetected = "error.zip_slip_detected"
        case corruptedHeader = "error.corrupted_header"
        case crcMismatch = "error.crc_mismatch"
        case outOfMemory = "error.out_of_memory"
        case operationCancelled = "error.operation_cancelled"
        case passwordRequired = "error.password_required"
        case incorrectPassword = "error.incorrect_password"
        case unsupportedFormat = "error.unsupported_format"
        case corruptData = "error.corrupt_data"
        case readError = "error.read_error"
        case writeError = "error.write_error"
    }
    
    // MARK: - 15. Units of Measurement & Counters
    public enum Units: String, LocaleKeyProtocol, CaseIterable {
        case bytes = "units.bytes"
        case kb = "units.kb"
        case mb = "units.mb"
        case gb = "units.gb"
        case tb = "units.tb"
        case mbPerSec = "units.mb_per_sec"
        case seconds = "units.seconds"
        case percent = "units.percent"
        case itemsCount = "units.items_count"
        case coresCount = "units.cores_count"
        case unifiedMemoryGB = "units.unified_memory_gb"
    }
    
    // MARK: - 16. Standalone CLI Output
    public enum CLI: String, LocaleKeyProtocol, CaseIterable {
        case usageHeader = "cli.usage_header"
        case subcommands = "cli.subcommands"
        case globalOptions = "cli.global_options"
        case errorMissingArg = "cli.error_missing_arg"
        case errorFileNotFound = "cli.error_file_not_found"
        case errorInvalidFormat = "cli.error_invalid_format"
        case dryRunPrefix = "cli.dry_run_prefix"
        case benchRunning = "cli.bench_running"
        case testSummary = "cli.test_summary"
    }
    
    // MARK: - 17. System Notifications
    public enum Notification: String, LocaleKeyProtocol, CaseIterable {
        case taskCompletedTitle = "notification.task_completed_title"
        case taskCompletedBody = "notification.task_completed_body"
        case taskFailedTitle = "notification.task_failed_title"
        case taskFailedBody = "notification.task_failed_body"
        case threatInterceptedTitle = "notification.threat_intercepted_title"
        case threatInterceptedBody = "notification.threat_intercepted_body"
    }
}
