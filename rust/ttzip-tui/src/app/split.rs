// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Asynchronous multi-volume archive split pipeline runner.

use super::state::AppState;
use super::types::AppMode;
use crate::cli::format::format_bytes;
use crate::event::AppEvent;
use crate::ui::progress::ProgressSnapshot;
use crossbeam_channel::Sender;
use std::fs::File;
use std::io::Read;
use std::path::PathBuf;
use std::thread;
use std::time::Instant;
use ttzip_glue::archive::split::SplitVolumeWriter;
use ttzip_glue::runtime::cancellation::CancellationToken;

impl AppState {
    /// Triggers asynchronous multi-volume splitting of the active archive.
    pub fn trigger_split(&mut self, event_sender: Sender<AppEvent>) {
        let split_state = match &self.split_modal_state {
            Some(s) => s.clone(),
            None => return,
        };

        let chunk_size = match split_state.current_chunk_size_bytes() {
            Ok(sz) => sz,
            Err(err) => {
                self.set_status(format!("Split Error: {}", err));
                return;
            }
        };

        let source_path = self.archive_path.clone();
        if !source_path.exists() {
            self.set_status("Source archive file not found".to_string());
            return;
        }

        let naming_scheme = split_state.naming_scheme();
        let out_dir = if split_state.output_dir.is_empty() {
            source_path.parent().map(|p| p.to_path_buf()).unwrap_or_else(|| PathBuf::from("."))
        } else {
            PathBuf::from(&split_state.output_dir)
        };

        let filename = source_path
            .file_name()
            .unwrap_or_else(|| std::ffi::OsStr::new("archive"));
        let base_target_path = out_dir.join(filename);

        self.current_mode = AppMode::Progress;
        self.cancellation_token = CancellationToken::new();

        let token = self.cancellation_token.clone();
        let total_bytes = self.total_size_bytes;

        thread::spawn(move || {
            let start = Instant::now();
            let mut source_file = match File::open(&source_path) {
                Ok(f) => f,
                Err(e) => {
                    let _ = event_sender.send(AppEvent::TaskCompleted(Err(format!("Failed to open source archive: {}", e))));
                    return;
                }
            };

            let mut writer = match SplitVolumeWriter::new(&base_target_path, chunk_size, naming_scheme) {
                Ok(w) => w,
                Err(e) => {
                    let _ = event_sender.send(AppEvent::TaskCompleted(Err(format!("Failed to init SplitVolumeWriter: {}", e))));
                    return;
                }
            };

            let mut buffer = vec![0u8; 256 * 1024];
            let mut processed_bytes = 0u64;

            loop {
                if token.is_cancelled() {
                    let _ = event_sender.send(AppEvent::TaskCompleted(Err("Split cancelled by user".to_string())));
                    return;
                }

                let read_bytes = match source_file.read(&mut buffer) {
                    Ok(0) => break,
                    Ok(n) => n,
                    Err(e) => {
                        let _ = event_sender.send(AppEvent::TaskCompleted(Err(format!("Read error: {}", e))));
                        return;
                    }
                };

                if let Err(e) = std::io::Write::write_all(&mut writer, &buffer[..read_bytes]) {
                    let _ = event_sender.send(AppEvent::TaskCompleted(Err(format!("Write error: {}", e))));
                    return;
                }

                processed_bytes += read_bytes as u64;

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
                    task_title: format!("Splitting Archive into {} chunks", format_bytes(chunk_size)),
                    current_entry_name: format!("Writing segment offset {}", format_bytes(processed_bytes)),
                    processed_bytes,
                    total_bytes,
                    processed_entries: 1,
                    total_entries: 1,
                    instant_throughput_mb_per_sec: speed_mb,
                    elapsed_seconds: elapsed,
                    eta_seconds: eta,
                };

                let _ = event_sender.send(AppEvent::Progress(snap));
            }

            match writer.close() {
                Ok(vols) => {
                    let vol_names: Vec<String> = vols.iter().map(|p| p.to_string_lossy().to_string()).collect();
                    let _ = event_sender.send(AppEvent::SplitCompleted(Ok(vol_names)));
                    let _ = event_sender.send(AppEvent::TaskCompleted(Ok(format!(
                        "Successfully split archive into {} volumes ({}) in {:.2?}",
                        vols.len(),
                        format_bytes(processed_bytes),
                        start.elapsed()
                    ))));
                }
                Err(e) => {
                    let _ = event_sender.send(AppEvent::TaskCompleted(Err(format!("Failed to finalize split volumes: {}", e))));
                }
            }
        });
    }
}
