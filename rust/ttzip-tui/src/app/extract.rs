// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Background asynchronous extraction task execution.

use super::state::AppState;
use super::types::AppMode;
use crate::event::AppEvent;
use crate::ui::progress::ProgressSnapshot;
use crossbeam_channel::Sender;
use std::fs;
use std::path::PathBuf;
use std::thread;
use std::time::Instant;
use ttzip_glue::fs::safe_extract::sanitize_and_validate_path;
use ttzip_glue::runtime::cancellation::CancellationToken;
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::zip::ZipArchive;

impl AppState {
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
}
