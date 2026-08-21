// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Core Application State Machine definition and lifecycle.

use super::types::{AppMode, ArchiveFormat};
use crate::event::AppEvent;
use crate::preview::{PreviewData, SyntaxHighlighter};
use crate::ui::progress::ProgressSnapshot;
use crate::vfs::{VfsEntryMeta, VfsSearchResult, VfsTree};
use crossbeam_channel::Sender;
use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant};
use ttzip_glue::runtime::cancellation::{CancellationReason, CancellationToken};
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::types::TTZipStatus;
use ttzip_glue::zip::ZipArchive;

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
    pub(crate) archive_raw_data: Vec<u8>,
    pub(crate) all_selected_toggle: bool,
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

    /// Sets an ephemeral status bar message with auto-expiration timestamp.
    pub fn set_status(&mut self, message: String) {
        self.status_message = Some((message, Instant::now()));
    }
}
