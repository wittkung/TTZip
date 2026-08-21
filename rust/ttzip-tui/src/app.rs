// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Core Application State Machine, Key Action Dispatch, and Safe Extraction Integration.

use crate::event::AppEvent;
use crate::preview::{generate_preview, PreviewData, SyntaxHighlighter};
use crate::ui::progress::ProgressSnapshot;
use crate::vfs::{VfsEntryMeta, VfsSearchResult, VfsTree};
use crossbeam_channel::Sender;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use std::fs;
use std::path::PathBuf;
use std::thread;
use std::time::{Duration, Instant};
use ttzip_glue::fs::safe_extract::sanitize_and_validate_path;
use ttzip_glue::runtime::cancellation::{CancellationReason, CancellationToken};
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::types::TTZipStatus;
use ttzip_glue::zip::ZipArchive;

/// Active TUI modal and operational mode.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppMode {
    Explorer,
    Search,
    Preview,
    Progress,
    Help,
    Exiting,
}

/// TTZip Archive Format enum.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ArchiveFormat {
    Zip,
    SevenZ,
    Unknown,
}

impl ArchiveFormat {
    pub fn as_str(&self) -> &'static str {
        match self {
            ArchiveFormat::Zip => "ZIP",
            ArchiveFormat::SevenZ => "7-Zip",
            ArchiveFormat::Unknown => "Unknown",
        }
    }
}

/// Central application state machine.
pub struct AppState {
    pub archive_path: PathBuf,
    pub archive_format: String,
    pub total_size_bytes: u64,
    pub uncompressed_size_bytes: u64,
    pub entries_count: usize,
    pub selected_index: usize,
    pub vfs: VfsTree,
    pub search_query: String,
    pub search_results: Vec<VfsSearchResult>,
    pub search_selected_index: usize,
    pub preview_content: Option<PreviewData>,
    pub preview_scroll: usize,
    pub progress_state: Option<ProgressSnapshot>,
    pub current_mode: AppMode,
    pub cancellation_token: CancellationToken,
    pub status_message: Option<(String, Instant)>,
    pub highlighter: SyntaxHighlighter,
    archive_raw_data: Vec<u8>,
    all_selected_toggle: bool,
}

impl AppState {
    /// Creates and initializes an `AppState` from an archive file path.
    pub fn new(archive_path: PathBuf) -> Result<Self, TTZipStatus> {
        let raw_data = fs::read(&archive_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
        let total_size_bytes = raw_data.len() as u64;

        let mut format = ArchiveFormat::Unknown;
        let mut entries = Vec::new();
        let mut uncompressed_size_bytes = 0u64;

        // Try parsing as ZIP
        if let Ok(zip_archive) = ZipArchive::open_slice(&raw_data) {
            format = ArchiveFormat::Zip;
            for (idx, e) in zip_archive.entries().iter().enumerate() {
                uncompressed_size_bytes += e.uncompressed_size;
                entries.push(VfsEntryMeta {
                    path: e.rel_path.clone(),
                    uncompressed_size: e.uncompressed_size,
                    compressed_size: e.compressed_size,
                    crc32: e.crc32,
                    mtime_epoch_secs: e.mtime_epoch_secs as i64,
                    mode: e.mode,
                    is_directory: e.is_directory,
                    is_encrypted: e.is_encrypted,
                    entry_idx: Some(idx),
                });
            }
        } else if let Ok(sevenz_archive) = SevenZArchive::open_slice(&raw_data) {
            // Try parsing as 7z
            format = ArchiveFormat::SevenZ;
            let info = sevenz_archive.info();
            let mut stream_idx = 0usize;

            for (idx, f) in info.files.iter().enumerate() {
                let (uncomp_sz, crc) = if !f.is_directory && !f.is_empty_stream {
                    let sz = info.stream_sizes.get(stream_idx).copied().unwrap_or(0);
                    let c = info.stream_crcs.get(stream_idx).copied().unwrap_or(0);
                    stream_idx += 1;
                    (sz, c)
                } else {
                    (0, 0)
                };

                uncompressed_size_bytes += uncomp_sz;
                entries.push(VfsEntryMeta {
                    path: f.rel_path.clone(),
                    uncompressed_size: uncomp_sz,
                    compressed_size: if uncomp_sz > 0 { info.payload_len as u64 / info.stream_sizes.len().max(1) as u64 } else { 0 },
                    crc32: crc,
                    mtime_epoch_secs: f.mtime_epoch_secs.unwrap_or(0),
                    mode: f.mode,
                    is_directory: f.is_directory,
                    is_encrypted: info.is_encrypted,
                    entry_idx: Some(idx),
                });
            }
        }

        let entries_count = entries.len();
        let mut vfs = VfsTree::from_metadata_list(&archive_path.to_string_lossy(), &entries);
        // Expand root by default
        vfs.set_all_expanded(true);

        Ok(Self {
            archive_path,
            archive_format: format.as_str().to_string(),
            total_size_bytes,
            uncompressed_size_bytes,
            entries_count,
            selected_index: 0,
            vfs,
            search_query: String::new(),
            search_results: Vec::new(),
            search_selected_index: 0,
            preview_content: None,
            preview_scroll: 0,
            progress_state: None,
            current_mode: AppMode::Explorer,
            cancellation_token: CancellationToken::new(),
            status_message: None,
            highlighter: SyntaxHighlighter::new(),
            archive_raw_data: raw_data,
            all_selected_toggle: false,
        })
    }

    /// Handles incoming application event.
    pub fn handle_event(&mut self, event: AppEvent, event_sender: Sender<AppEvent>) {
        match event {
            AppEvent::Key(key) => self.handle_key_event(key, event_sender),
            AppEvent::Progress(snap) => {
                self.progress_state = Some(snap);
            }
            AppEvent::TaskCompleted(res) => {
                self.current_mode = AppMode::Explorer;
                match res {
                    Ok(msg) => self.set_status(msg),
                    Err(err) => self.set_status(format!("Error: {}", err)),
                }
            }
            AppEvent::CancellationRequested => {
                self.cancellation_token.cancel(CancellationReason::UserRequested);
                self.set_status("Cancellation requested...".to_string());
            }
            AppEvent::Tick => {
                // Clear old status messages after 5 seconds
                if let Some((_, instant)) = &self.status_message {
                    if instant.elapsed() > Duration::from_secs(5) {
                        self.status_message = None;
                    }
                }
            }
            _ => {}
        }
    }

    /// Handles keyboard input based on current mode state machine.
    pub fn handle_key_event(&mut self, key: KeyEvent, event_sender: Sender<AppEvent>) {
        match self.current_mode {
            AppMode::Explorer => self.handle_explorer_key(key, event_sender),
            AppMode::Search => self.handle_search_key(key),
            AppMode::Preview => self.handle_preview_key(key),
            AppMode::Progress => self.handle_progress_key(key),
            AppMode::Help => self.handle_help_key(key),
            AppMode::Exiting => {}
        }
    }

    fn handle_explorer_key(&mut self, key: KeyEvent, event_sender: Sender<AppEvent>) {
        let visible_count = self.vfs.flatten_visible().len();

        match key.code {
            KeyCode::Char('q') => {
                self.current_mode = AppMode::Exiting;
            }
            KeyCode::Esc => {
                // If preview open, close preview
                if self.preview_content.is_some() {
                    self.preview_content = None;
                } else {
                    self.current_mode = AppMode::Exiting;
                }
            }
            KeyCode::Char('j') | KeyCode::Down => {
                if visible_count > 0 {
                    self.selected_index = (self.selected_index + 1).min(visible_count - 1);
                    if self.preview_content.is_some() {
                        self.update_preview_content();
                    }
                }
            }
            KeyCode::Char('k') | KeyCode::Up => {
                if visible_count > 0 {
                    self.selected_index = self.selected_index.saturating_sub(1);
                    if self.preview_content.is_some() {
                        self.update_preview_content();
                    }
                }
            }
            KeyCode::Char('g') | KeyCode::Home => {
                self.selected_index = 0;
                if self.preview_content.is_some() {
                    self.update_preview_content();
                }
            }
            KeyCode::Char('G') | KeyCode::End => {
                if visible_count > 0 {
                    self.selected_index = visible_count - 1;
                    if self.preview_content.is_some() {
                        self.update_preview_content();
                    }
                }
            }
            KeyCode::Char(' ') => {
                let target_path = self.vfs.flatten_visible().get(self.selected_index).map(|item| item.node.relative_path.clone());
                if let Some(path) = target_path {
                    self.vfs.toggle_selected(&path);
                }
            }
            KeyCode::Char('a') => {
                self.all_selected_toggle = !self.all_selected_toggle;
                self.vfs.select_all(self.all_selected_toggle);
                self.set_status(if self.all_selected_toggle {
                    "Selected all entries".to_string()
                } else {
                    "Deselected all entries".to_string()
                });
            }
            KeyCode::Enter => {
                let target_node_info = self.vfs.flatten_visible().get(self.selected_index).map(|item| (item.node.relative_path.clone(), item.node.is_dir));
                if let Some((path, is_dir)) = target_node_info {
                    if is_dir {
                        self.vfs.toggle_expanded(&path);
                    } else {
                        // Trigger extraction of selected or current file
                        self.trigger_extraction(event_sender);
                    }
                }
            }
            KeyCode::Char('p') | KeyCode::Tab => {
                if self.preview_content.is_some() {
                    self.preview_content = None;
                    self.current_mode = AppMode::Explorer;
                } else {
                    self.update_preview_content();
                    self.current_mode = AppMode::Preview;
                }
            }
            KeyCode::Char('/') => {
                self.search_query.clear();
                self.search_results.clear();
                self.search_selected_index = 0;
                self.current_mode = AppMode::Search;
            }
            KeyCode::Char('?') | KeyCode::Char('h') => {
                self.current_mode = AppMode::Help;
            }
            _ => {}
        }
    }

    fn handle_search_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Esc => {
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Enter => {
                if let Some(matched) = self.search_results.get(self.search_selected_index) {
                    let target_path = matched.relative_path.clone();
                    // Expand parents if collapsed
                    self.vfs.set_all_expanded(true);
                    let visible = self.vfs.flatten_visible();
                    if let Some(idx) = visible.iter().position(|r| r.node.relative_path == target_path) {
                        self.selected_index = idx;
                    }
                }
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Up => {
                if !self.search_results.is_empty() {
                    self.search_selected_index = self.search_selected_index.saturating_sub(1);
                }
            }
            KeyCode::Down => {
                if !self.search_results.is_empty() {
                    self.search_selected_index = (self.search_selected_index + 1).min(self.search_results.len() - 1);
                }
            }
            KeyCode::Backspace => {
                self.search_query.pop();
                self.update_search_results();
            }
            KeyCode::Char(c) => {
                if !key.modifiers.contains(KeyModifiers::CONTROL) && !key.modifiers.contains(KeyModifiers::ALT) {
                    self.search_query.push(c);
                    self.update_search_results();
                }
            }
            _ => {}
        }
    }

    fn update_search_results(&mut self) {
        self.search_results = self.vfs.fuzzy_search(&self.search_query);
        self.search_selected_index = 0;
    }

    fn handle_preview_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('p') | KeyCode::Tab => {
                self.preview_content = None;
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Char('j') | KeyCode::Down => {
                self.preview_scroll = self.preview_scroll.saturating_add(1);
            }
            KeyCode::Char('k') | KeyCode::Up => {
                self.preview_scroll = self.preview_scroll.saturating_sub(1);
            }
            KeyCode::Char('d') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                self.preview_scroll = self.preview_scroll.saturating_add(10);
            }
            KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                self.preview_scroll = self.preview_scroll.saturating_sub(10);
            }
            _ => {}
        }
    }

    fn handle_progress_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => {
                self.cancellation_token.cancel(CancellationReason::UserRequested);
                self.set_status("Cancelling extraction safely...".to_string());
            }
            _ => {}
        }
    }

    fn handle_help_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Enter | KeyCode::Char('?') | KeyCode::Char('h') => {
                self.current_mode = AppMode::Explorer;
            }
            _ => {}
        }
    }

    /// Updates preview buffer for the currently selected item.
    pub fn update_preview_content(&mut self) {
        let node_info = {
            let visible = self.vfs.flatten_visible();
            visible.get(self.selected_index).map(|item| {
                (
                    item.node.is_dir,
                    item.node.name.clone(),
                    item.node.uncompressed_size,
                    item.node.relative_path.clone(),
                )
            })
        };

        if let Some((is_dir, filename, full_size, rel_path)) = node_info {
            if is_dir {
                self.preview_content = Some(PreviewData::Unsupported {
                    reason: "Directories cannot be previewed".to_string(),
                    file_size_bytes: 0,
                });
                self.preview_scroll = 0;
                return;
            }

            let raw_data = self.archive_raw_data.clone();

            // Extract stream bytes for preview
            let preview_bytes = if self.archive_format == "ZIP" {
                if let Ok(archive) = ZipArchive::open_slice(&raw_data) {
                    if let Some(idx) = archive.entries().iter().position(|e| e.rel_path == rel_path) {
                        archive.extract_entry_bytes(idx, None).unwrap_or_default()
                    } else {
                        Vec::new()
                    }
                } else {
                    Vec::new()
                }
            } else if self.archive_format == "7-Zip" {
                if let Ok(archive) = SevenZArchive::open_slice(&raw_data) {
                    if let Some(idx) = archive.files().iter().position(|f| f.rel_path == rel_path) {
                        archive.extract_entry_bytes(idx, None).unwrap_or_default()
                    } else {
                        Vec::new()
                    }
                } else {
                    Vec::new()
                }
            } else {
                Vec::new()
            };

            let preview = generate_preview(&filename, &preview_bytes, full_size, &self.highlighter);
            self.preview_content = Some(preview);
            self.preview_scroll = 0;
        }
    }

    /// Triggers extraction of either marked entries or the selected entry to `./` or target dir.
    pub fn trigger_extraction(&mut self, event_sender: Sender<AppEvent>) {
        let mut selected_paths = self.vfs.get_selected_paths();
        if selected_paths.is_empty() {
            let visible = self.vfs.flatten_visible();
            if let Some(item) = visible.get(self.selected_index) {
                if !item.node.is_dir {
                    selected_paths.push(item.node.relative_path.clone());
                }
            }
        }

        if selected_paths.is_empty() {
            self.set_status("No files selected to extract.".to_string());
            return;
        }

        self.current_mode = AppMode::Progress;
        self.cancellation_token = CancellationToken::new();

        let token = self.cancellation_token.clone();
        let raw_data = self.archive_raw_data.clone();
        let is_zip = self.archive_format == "ZIP";
        let dest_dir = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));

        thread::spawn(move || {
            let start = Instant::now();
            let total_entries = selected_paths.len();
            let mut processed_bytes = 0u64;
            let mut total_bytes = 0u64;

            // Calculate total size
            if is_zip {
                if let Ok(archive) = ZipArchive::open_slice(&raw_data) {
                    for path in &selected_paths {
                        if let Some(e) = archive.entries().iter().find(|e| e.rel_path == *path) {
                            total_bytes += e.uncompressed_size;
                        }
                    }
                }
            } else if let Ok(archive) = SevenZArchive::open_slice(&raw_data) {
                let info = archive.info();
                for path in &selected_paths {
                    let mut stream_idx = 0usize;
                    for f in &info.files {
                        if !f.is_directory && !f.is_empty_stream {
                            if f.rel_path == *path {
                                let sz = info.stream_sizes.get(stream_idx).copied().unwrap_or(0);
                                total_bytes += sz;
                                break;
                            }
                            stream_idx += 1;
                        }
                    }
                }
            }

            for (proc_count, rel_path) in selected_paths.iter().enumerate() {
                if token.is_cancelled() {
                    let _ = event_sender.send(AppEvent::TaskCompleted(Err("Extraction cancelled by user".to_string())));
                    return;
                }

                let target_path = match sanitize_and_validate_path(&dest_dir, rel_path) {
                    Ok(p) => p,
                    Err(_) => {
                        let _ = event_sender.send(AppEvent::TaskCompleted(Err(format!("Security violation on path: {}", rel_path))));
                        return;
                    }
                };

                if let Some(parent) = target_path.parent() {
                    let _ = fs::create_dir_all(parent);
                }

                let mut uncomp_size = 0u64;

                let file_data = if is_zip {
                    if let Ok(archive) = ZipArchive::open_slice(&raw_data) {
                        if let Some(idx) = archive.entries().iter().position(|e| e.rel_path == *rel_path) {
                            uncomp_size = archive.entries()[idx].uncompressed_size;
                            archive.extract_entry_bytes(idx, None).unwrap_or_default()
                        } else {
                            Vec::new()
                        }
                    } else {
                        Vec::new()
                    }
                } else if let Ok(archive) = SevenZArchive::open_slice(&raw_data) {
                    if let Some(idx) = archive.files().iter().position(|f| f.rel_path == *rel_path) {
                        let bytes = archive.extract_entry_bytes(idx, None).unwrap_or_default();
                        uncomp_size = bytes.len() as u64;
                        bytes
                    } else {
                        Vec::new()
                    }
                } else {
                    Vec::new()
                };

                let _ = fs::write(&target_path, &file_data);
                processed_bytes += uncomp_size;

                let elapsed = start.elapsed().as_secs_f64();
                let speed_mb = if elapsed > 0.0 {
                    (processed_bytes as f64 / (1024.0 * 1024.0)) / elapsed
                } else {
                    0.0
                };
                let eta = if speed_mb > 0.0 && total_bytes > processed_bytes {
                    ((total_bytes - processed_bytes) as f64 / (1024.0 * 1024.0)) / speed_mb
                } else {
                    0.0
                };

                let snap = ProgressSnapshot {
                    task_title: format!("Extracting {} entries", total_entries),
                    current_entry_name: rel_path.clone(),
                    processed_bytes,
                    total_bytes,
                    processed_entries: proc_count + 1,
                    total_entries,
                    instant_throughput_mb_per_sec: speed_mb,
                    elapsed_seconds: elapsed,
                    eta_seconds: eta,
                };

                let _ = event_sender.send(AppEvent::Progress(snap));
            }

            let _ = event_sender.send(AppEvent::TaskCompleted(Ok(format!(
                "Successfully extracted {} files ({}) in {:.2?}",
                total_entries,
                crate::ui::explorer::format_bytes(processed_bytes),
                start.elapsed()
            ))));
        });
    }

    /// Sets an ephemeral status bar message with auto-expiration timestamp.
    pub fn set_status(&mut self, message: String) {
        self.status_message = Some((message, Instant::now()));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ttzip_glue::types::TTZipEncryptionMethod;
    use ttzip_glue::zip::writer::{assemble_zip_archive, compress_items_parallel, ZipInputItem};

    fn create_test_zip_file() -> tempfile::NamedTempFile {
        let items = vec![
            ZipInputItem {
                rel_path: "README.md".to_string(),
                data: b"# TTZip TUI\nInteractive archive browser".to_vec(),
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
            },
            ZipInputItem {
                rel_path: "src/main.rs".to_string(),
                data: b"fn main() { println!(\"TTZip\"); }".to_vec(),
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
            },
        ];

        let compressed = compress_items_parallel(items, 6, TTZipEncryptionMethod::None, None, 2).unwrap();
        let zip_bytes = assemble_zip_archive(&compressed).unwrap();

        let mut tmp = tempfile::NamedTempFile::new().unwrap();
        use std::io::Write;
        tmp.write_all(&zip_bytes).unwrap();
        tmp
    }

    #[test]
    fn test_app_state_initialization() {
        let tmp = create_test_zip_file();
        let state = AppState::new(tmp.path().to_path_buf()).expect("init state");

        assert_eq!(state.archive_format, "ZIP");
        assert_eq!(state.entries_count, 2);
        assert_eq!(state.current_mode, AppMode::Explorer);
        assert!(!state.vfs.flatten_visible().is_empty());
    }

    #[test]
    fn test_app_state_mode_transitions_and_navigation() {
        let tmp = create_test_zip_file();
        let mut state = AppState::new(tmp.path().to_path_buf()).expect("init state");
        let (tx, _rx) = crossbeam_channel::unbounded();

        // Down
        state.handle_key_event(KeyEvent::from(KeyCode::Char('j')), tx.clone());
        assert!(state.selected_index <= 2);

        // Search mode
        state.handle_key_event(KeyEvent::from(KeyCode::Char('/')), tx.clone());
        assert_eq!(state.current_mode, AppMode::Search);

        // Type query
        state.handle_key_event(KeyEvent::from(KeyCode::Char('m')), tx.clone());
        state.handle_key_event(KeyEvent::from(KeyCode::Char('a')), tx.clone());
        state.handle_key_event(KeyEvent::from(KeyCode::Char('i')), tx.clone());
        state.handle_key_event(KeyEvent::from(KeyCode::Char('n')), tx.clone());
        assert_eq!(state.search_query, "main");
        assert!(!state.search_results.is_empty());

        // Escape to explorer
        state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
        assert_eq!(state.current_mode, AppMode::Explorer);

        // Help modal
        state.handle_key_event(KeyEvent::from(KeyCode::Char('?')), tx.clone());
        assert_eq!(state.current_mode, AppMode::Help);

        state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
        assert_eq!(state.current_mode, AppMode::Explorer);

        // Preview
        state.handle_key_event(KeyEvent::from(KeyCode::Char('p')), tx.clone());
        assert_eq!(state.current_mode, AppMode::Preview);
        assert!(state.preview_content.is_some());
    }
}
