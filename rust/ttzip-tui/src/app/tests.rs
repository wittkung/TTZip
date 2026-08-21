// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use super::*;
use crossterm::event::{KeyCode, KeyEvent};
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
