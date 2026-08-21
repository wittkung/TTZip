// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unit and integration tests for Repair Wizard and archive salvage.

use crate::app::repair_runner::{
    reconstruct_salvaged_archive, scan_salvageable_tar_entries, scan_salvageable_zip_entries,
};
use crate::app::state::AppState;
use crate::app::types::AppMode;
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::backend::TestBackend;
use ratatui::Terminal;
use std::io::Write;
use ttzip_glue::types::TTZipEncryptionMethod;
use ttzip_glue::zip::writer::{assemble_zip_archive, compress_items_parallel, ZipInputItem};
use ttzip_glue::zip::ZipArchive;

pub fn create_corrupt_truncated_zip() -> (tempfile::NamedTempFile, Vec<u8>) {
    let items = vec![
        ZipInputItem {
            rel_path: "doc1.txt".to_string(),
            data: b"First salvaged document payload".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "doc2.txt".to_string(),
            data: b"Second salvaged document payload with more bytes".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
    ];

    let compressed =
        compress_items_parallel(items, 0, TTZipEncryptionMethod::None, None, 2).unwrap();
    let zip_bytes = assemble_zip_archive(&compressed).unwrap();

    // Truncate before Central Directory (simulate damaged / incomplete download)
    let cd_offset = zip_bytes
        .windows(4)
        .position(|w| w == [0x50, 0x4b, 0x01, 0x02])
        .unwrap_or(zip_bytes.len());
    let truncated = zip_bytes[..cd_offset].to_vec();

    let mut tmp = tempfile::NamedTempFile::new().unwrap();
    tmp.write_all(&truncated).unwrap();
    (tmp, truncated)
}

#[test]
fn test_repair_runner_simd_salvage_scanner_and_reconstruct() {
    let (_tmp, truncated_data) = create_corrupt_truncated_zip();

    // 1. NEON SIMD Salvage Scanner
    let salvaged = scan_salvageable_zip_entries(&truncated_data);
    assert_eq!(salvaged.len(), 2);
    assert_eq!(salvaged[0].rel_path, "doc1.txt");
    assert_eq!(salvaged[1].rel_path, "doc2.txt");
    assert!(salvaged[0].is_selected);
    assert!(salvaged[1].is_selected);

    // 2. TOC Reconstruction & Assembly
    let output_tmp = tempfile::NamedTempFile::new().unwrap();
    let count = reconstruct_salvaged_archive(&truncated_data, &salvaged, output_tmp.path(), "ZIP")
        .expect("reconstruct archive");
    assert_eq!(count, 2);

    // 3. Verify healthy rebuilt archive structure
    let rebuilt_bytes = std::fs::read(output_tmp.path()).expect("read rebuilt");
    let archive = ZipArchive::open_slice(&rebuilt_bytes).expect("open rebuilt zip");
    assert_eq!(archive.entries().len(), 2);

    let doc1_bytes = archive.extract_entry_bytes(0, None).expect("extract doc1");
    assert_eq!(doc1_bytes, b"First salvaged document payload");

    let doc2_bytes = archive.extract_entry_bytes(1, None).expect("extract doc2");
    assert_eq!(
        doc2_bytes,
        b"Second salvaged document payload with more bytes"
    );
}

#[test]
fn test_repair_runner_tar_salvage() {
    let mut tar_data = vec![0u8; 1536];
    let name_bytes = b"test_salvage.txt";
    tar_data[0..name_bytes.len()].copy_from_slice(name_bytes);
    tar_data[124..136].copy_from_slice(b"00000000020 "); // 16 bytes octal

    let mut chk = 0u32;
    for (i, &b) in tar_data[0..512].iter().enumerate() {
        if (148..156).contains(&i) {
            chk += b' ' as u32;
        } else {
            chk += b as u32;
        }
    }
    let chk_str = format!("{:06o}\0 ", chk);
    tar_data[148..148 + chk_str.len()].copy_from_slice(chk_str.as_bytes());
    tar_data[512..512 + 16].copy_from_slice(b"Salvaged payload");

    let entries = scan_salvageable_tar_entries(&tar_data);
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].rel_path, "test_salvage.txt");
    assert_eq!(entries[0].uncompressed_size, 16);

    let out_tmp = tempfile::NamedTempFile::new().unwrap();
    let count = reconstruct_salvaged_archive(&tar_data, &entries, out_tmp.path(), "TAR")
        .expect("reconstruct tar");
    assert_eq!(count, 1);
}

#[test]
fn test_repair_wizard_interactive_lifecycle_and_auto_load() {
    let (corrupt_file, _) = create_corrupt_truncated_zip();
    let (tx, _rx) = crossbeam_channel::unbounded();

    let mut state =
        AppState::new(corrupt_file.path().to_path_buf()).expect("init corrupt state");
    assert_eq!(state.current_mode, AppMode::RepairWizard);
    assert!(state.repair_state.is_some());

    let repair = state.repair_state.as_ref().unwrap();
    assert_eq!(repair.salvaged_entries.len(), 2);
    assert_eq!(repair.selected_table_index, 0);

    // 1. Test table cursor navigation (j/k)
    state.handle_key_event(KeyEvent::from(KeyCode::Char('j')), tx.clone());
    assert_eq!(
        state.repair_state.as_ref().unwrap().selected_table_index,
        1
    );

    state.handle_key_event(KeyEvent::from(KeyCode::Char('k')), tx.clone());
    assert_eq!(
        state.repair_state.as_ref().unwrap().selected_table_index,
        0
    );

    // 2. Test entry selection toggle (Space)
    state.handle_key_event(KeyEvent::from(KeyCode::Char(' ')), tx.clone());
    assert!(!state.repair_state.as_ref().unwrap().salvaged_entries[0].is_selected);

    // 3. Test select all toggle (a)
    state.handle_key_event(KeyEvent::from(KeyCode::Char('a')), tx.clone());
    assert!(!state.repair_state.as_ref().unwrap().salvaged_entries[0].is_selected);
    assert!(!state.repair_state.as_ref().unwrap().salvaged_entries[1].is_selected);

    state.handle_key_event(KeyEvent::from(KeyCode::Char('a')), tx.clone());
    assert!(state.repair_state.as_ref().unwrap().salvaged_entries[0].is_selected);
    assert!(state.repair_state.as_ref().unwrap().salvaged_entries[1].is_selected);

    // 4. Test target output path editing (Tab / Chars)
    let repaired_target = tempfile::NamedTempFile::new().unwrap();
    let target_path_str = repaired_target.path().to_string_lossy().to_string();

    state.handle_key_event(KeyEvent::from(KeyCode::Tab), tx.clone());
    assert!(state.repair_state.as_ref().unwrap().is_editing_path);

    state.repair_state.as_mut().unwrap().output_path_input = target_path_str.clone();
    state.handle_key_event(KeyEvent::from(KeyCode::Enter), tx.clone());
    assert!(!state.repair_state.as_ref().unwrap().is_editing_path);

    // 5. Test Enter to execute TOC assembly and one-click auto-load
    state.handle_key_event(KeyEvent::from(KeyCode::Enter), tx.clone());

    assert_eq!(state.current_mode, AppMode::Explorer);
    assert_eq!(state.entries_count, 2);
    assert_eq!(state.archive_format, "ZIP");
    assert!(state.repair_state.is_none());
    assert!(state.status_message.is_some());
}

#[test]
fn test_render_repair_modal_widget_drawing() {
    let (corrupt_file, _) = create_corrupt_truncated_zip();
    let state = AppState::new(corrupt_file.path().to_path_buf()).expect("init state");

    let backend = TestBackend::new(100, 30);
    let mut terminal = Terminal::new(backend).expect("create terminal");

    terminal
        .draw(|f| {
            crate::ui::modals::repair::render_repair_modal(f, f.area(), &state);
        })
        .expect("draw repair modal");
}
