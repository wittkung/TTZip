// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unit tests for Interactive 2D Pareto Canvas and Multi-Volume Split Manager Modals.

use crate::app::modal_state::{ParetoFilter, ParetoModalState, SplitModalState, SplitPreset};
use crate::app::{AppMode, AppState};
use crate::ui::modals::pareto::render_pareto_modal;
use crate::ui::modals::split::{derive_split_volumes, render_split_modal};
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::backend::TestBackend;
use ratatui::Terminal;
use std::io::Write;
use std::path::Path;
use ttzip_glue::archive::split::VolumeNamingScheme;
use ttzip_glue::types::TTZipEncryptionMethod;
use ttzip_glue::zip::writer::{assemble_zip_archive, compress_items_parallel, ZipInputItem};

fn create_test_zip_file() -> tempfile::NamedTempFile {
    let items = vec![ZipInputItem {
        rel_path: "sample.txt".to_string(),
        data: b"Hello TTZip Phase 4 2D Pareto & Split Test Payload!".to_vec(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    }];

    let compressed =
        compress_items_parallel(items, 6, TTZipEncryptionMethod::None, None, 2).unwrap();
    let zip_bytes = assemble_zip_archive(&compressed).unwrap();

    let mut tmp = tempfile::NamedTempFile::new().unwrap();
    tmp.write_all(&zip_bytes).unwrap();
    tmp
}

#[test]
fn test_pareto_filter_cycling_and_filtering() {
    let mut state = ParetoModalState::new();
    assert_eq!(state.filter, ParetoFilter::All);
    assert_eq!(state.filtered_items().len(), state.items.len());

    // Cycle to Pareto Optimal
    state.filter = state.filter.next();
    assert_eq!(state.filter, ParetoFilter::ParetoOptimal);
    let opt_count = state.filtered_items().len();
    assert!(opt_count > 0);
    for it in state.filtered_items() {
        assert!(it.raw.is_pareto_optimal);
    }

    // Cycle to Convex Hull
    state.filter = state.filter.next();
    assert_eq!(state.filter, ParetoFilter::ConvexHull);
    let hull_count = state.filtered_items().len();
    assert!(hull_count > 0);
    assert!(hull_count <= opt_count);
    for it in state.filtered_items() {
        assert!(it.raw.is_on_convex_envelope);
    }

    // Cycle to TTZip Only
    state.filter = state.filter.next();
    assert_eq!(state.filter, ParetoFilter::TTZipOnly);
    for it in state.filtered_items() {
        assert!(it.name.starts_with("TTZip"));
    }

    // Cycle back to All
    state.filter = state.filter.next();
    assert_eq!(state.filter, ParetoFilter::All);
}

#[test]
fn test_pareto_focus_item_and_zoom() {
    let mut state = ParetoModalState::new();
    assert!(state.current_focus_item().is_some());
    assert_eq!(state.selected_index, 0);

    state.zoom_level = 1.0;
    state.zoom_level = (state.zoom_level + 0.2).min(3.0);
    assert!((state.zoom_level - 1.2).abs() < 1e-6);

    state.zoom_level = (state.zoom_level - 0.4).max(0.5);
    assert!((state.zoom_level - 0.8).abs() < 1e-6);
}

#[test]
fn test_split_presets_and_byte_calculations() {
    let cd_size = SplitPreset::Cd700M.byte_size("").unwrap();
    assert_eq!(cd_size, 700 * 1024 * 1024);

    let dvd_size = SplitPreset::Dvd4700M.byte_size("").unwrap();
    assert_eq!(dvd_size, (4.7 * 1024.0 * 1024.0 * 1024.0) as u64);

    let fat32_size = SplitPreset::Fat32_4G.byte_size("").unwrap();
    assert_eq!(fat32_size, 4 * 1024 * 1024 * 1024 - 1);

    let discord25 = SplitPreset::Discord25M.byte_size("").unwrap();
    assert_eq!(discord25, 25 * 1024 * 1024);

    let discord500 = SplitPreset::Discord500M.byte_size("").unwrap();
    assert_eq!(discord500, 500 * 1024 * 1024);

    // Custom sizes
    assert_eq!(SplitPreset::Custom.byte_size("100M").unwrap(), 100 * 1024 * 1024);
    assert_eq!(SplitPreset::Custom.byte_size("1.5G").unwrap(), (1.5 * 1024.0 * 1024.0 * 1024.0) as u64);
    assert!(SplitPreset::Custom.byte_size("invalid").is_err());
}

#[test]
fn test_derive_split_volumes_numbered_and_pkzip() {
    let base_path = Path::new("/path/to/archive.zip");
    let total_bytes = 1_500_000_000u64; // ~1.5 GB
    let chunk_size = 700 * 1024 * 1024; // 700 MB

    // 1. NumberedExtension
    let vols_num = derive_split_volumes(base_path, total_bytes, chunk_size, VolumeNamingScheme::NumberedExtension);
    assert_eq!(vols_num.len(), 3);
    assert_eq!(vols_num[0].filename, "archive.zip.001");
    assert_eq!(vols_num[0].size_bytes, chunk_size);
    assert_eq!(vols_num[1].filename, "archive.zip.002");
    assert_eq!(vols_num[1].size_bytes, chunk_size);
    assert_eq!(vols_num[2].filename, "archive.zip.003");
    assert_eq!(vols_num[2].size_bytes, total_bytes - (chunk_size * 2));

    // 2. PKZip Spanned
    let vols_pk = derive_split_volumes(base_path, total_bytes, chunk_size, VolumeNamingScheme::PkzipSpanned);
    assert_eq!(vols_pk.len(), 3);
    assert_eq!(vols_pk[0].filename, "archive.z01");
    assert_eq!(vols_pk[1].filename, "archive.z02");
    assert_eq!(vols_pk[2].filename, "archive.zip");
}

#[test]
fn test_headless_pareto_modal_rendering() {
    let file = create_test_zip_file();
    let mut app_state = AppState::new(file.path().to_path_buf()).expect("init AppState");
    app_state.pareto_modal_state = Some(ParetoModalState::new());
    app_state.current_mode = AppMode::ParetoBenchmark;

    let backend = TestBackend::new(100, 40);
    let mut terminal = Terminal::new(backend).unwrap();

    terminal
        .draw(|f| {
            render_pareto_modal(f, f.area(), &app_state);
        })
        .unwrap();

    let buffer = terminal.backend().buffer();
    let buffer_str = format!("{:?}", buffer);
    assert!(buffer_str.contains("Pareto Frontier"));
    assert!(buffer_str.contains("Throughput"));
}

#[test]
fn test_headless_split_modal_rendering() {
    let file = create_test_zip_file();
    let mut app_state = AppState::new(file.path().to_path_buf()).expect("init AppState");
    app_state.split_modal_state = Some(SplitModalState::new(".".to_string()));
    app_state.current_mode = AppMode::SplitManager;

    let backend = TestBackend::new(100, 40);
    let mut terminal = Terminal::new(backend).unwrap();

    terminal
        .draw(|f| {
            render_split_modal(f, f.area(), &app_state);
        })
        .unwrap();

    let buffer = terminal.backend().buffer();
    let buffer_str = format!("{:?}", buffer);
    assert!(buffer_str.contains("Split Manager"));
    assert!(buffer_str.contains("CD (700 MB)"));
}

#[test]
fn test_app_state_pareto_and_split_key_input() {
    let file = create_test_zip_file();
    let mut app_state = AppState::new(file.path().to_path_buf()).expect("init AppState");
    let (tx, _rx) = crossbeam_channel::unbounded();

    // Navigate to Pareto
    app_state.handle_key_event(KeyEvent::from(KeyCode::Char('b')), tx.clone());
    assert_eq!(app_state.current_mode, AppMode::ParetoBenchmark);

    // Zoom in
    let z_before = app_state.pareto_modal_state.as_ref().unwrap().zoom_level;
    app_state.handle_key_event(KeyEvent::from(KeyCode::Char('+')), tx.clone());
    let z_after = app_state.pareto_modal_state.as_ref().unwrap().zoom_level;
    assert!(z_after > z_before);

    // Cycle filter
    app_state.handle_key_event(KeyEvent::from(KeyCode::Tab), tx.clone());
    assert_eq!(app_state.pareto_modal_state.as_ref().unwrap().filter, ParetoFilter::ParetoOptimal);

    // Roam focus
    app_state.handle_key_event(KeyEvent::from(KeyCode::Char('j')), tx.clone());
    assert_eq!(app_state.pareto_modal_state.as_ref().unwrap().selected_index, 1);

    // Close Pareto
    app_state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
    assert_eq!(app_state.current_mode, AppMode::Explorer);

    // Navigate to Split
    app_state.handle_key_event(KeyEvent::from(KeyCode::Char('s')), tx.clone());
    assert_eq!(app_state.current_mode, AppMode::SplitManager);

    // Switch preset
    app_state.handle_key_event(KeyEvent::from(KeyCode::Tab), tx.clone());
    assert_eq!(app_state.split_modal_state.as_ref().unwrap().preset_index, 1);

    // Toggle naming scheme
    app_state.handle_key_event(KeyEvent::from(KeyCode::Char('n')), tx.clone());
    assert_eq!(app_state.split_modal_state.as_ref().unwrap().naming_scheme_idx, 1);

    // Close Split
    app_state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx);
    assert_eq!(app_state.current_mode, AppMode::Explorer);
}
