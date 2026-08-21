// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Core Application State Machine, modal mode navigation, and event loop tests.

mod recovery_tests;
mod repair_tests;

use super::*;
use crate::event::AppEvent;
use crossterm::event::{KeyCode, KeyEvent};
use std::io::Write;
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

    let compressed =
        compress_items_parallel(items, 6, TTZipEncryptionMethod::None, None, 2).unwrap();
    let zip_bytes = assemble_zip_archive(&compressed).unwrap();

    let mut tmp = tempfile::NamedTempFile::new().unwrap();
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

#[test]
fn test_modal_mode_transitions_and_hotkeys() {
    let tmp = create_test_zip_file();
    let mut state = AppState::new(tmp.path().to_path_buf()).expect("init state");
    let (tx, _rx) = crossbeam_channel::unbounded();

    // 1. Password Recovery ('r')
    state.handle_key_event(KeyEvent::from(KeyCode::Char('r')), tx.clone());
    assert_eq!(state.current_mode, AppMode::PasswordRecovery);
    assert!(state.recovery_modal_state.is_some());
    // Esc back to Explorer
    state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
    assert_eq!(state.current_mode, AppMode::Explorer);

    // 2. Repair Wizard ('R')
    state.handle_key_event(KeyEvent::from(KeyCode::Char('R')), tx.clone());
    assert_eq!(state.current_mode, AppMode::RepairWizard);
    assert!(state.repair_state.is_some());
    // Esc back to Explorer
    state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
    assert_eq!(state.current_mode, AppMode::Explorer);

    // 3. Pareto Benchmark ('B')
    state.handle_key_event(KeyEvent::from(KeyCode::Char('B')), tx.clone());
    assert_eq!(state.current_mode, AppMode::ParetoBenchmark);
    // Tab switching in Pareto mode
    if state.pareto_modal_state.is_none() {
        state.pareto_modal_state = Some(ParetoModalState::new());
    }
    state.handle_key_event(KeyEvent::from(KeyCode::Tab), tx.clone());
    assert_eq!(state.pareto_modal_state.as_ref().unwrap().filter, ParetoFilter::ParetoOptimal);
    // Esc back to Explorer
    state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
    assert_eq!(state.current_mode, AppMode::Explorer);

    // 4. Split Manager ('S')
    state.handle_key_event(KeyEvent::from(KeyCode::Char('S')), tx.clone());
    assert_eq!(state.current_mode, AppMode::SplitManager);
    if state.split_modal_state.is_none() {
        state.split_modal_state = Some(SplitModalState::new(".".to_string()));
    }
    assert!(state.split_modal_state.is_some());
    // Esc back to Explorer
    state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
    assert_eq!(state.current_mode, AppMode::Explorer);
}

#[test]
fn test_modal_event_handling_state_updates() {
    let tmp = create_test_zip_file();
    let mut state = AppState::new(tmp.path().to_path_buf()).expect("init state");
    let (tx, _rx) = crossbeam_channel::unbounded();

    state.recovery_modal_state = Some(RecoveryModalState::default());
    state.pareto_modal_state = Some(ParetoModalState::new());
    state.split_modal_state = Some(SplitModalState::new(".".to_string()));

    // 1. Recovery Progress & Complete events
    state.handle_event(
        AppEvent::RecoveryProgress {
            tested: 500,
            total: 10000,
            speed: 25000.0,
            elapsed_secs: 0.02,
            eta_secs: 0.38,
        },
        tx.clone(),
    );
    let rec_state = state.recovery_modal_state.as_ref().unwrap();
    assert_eq!(rec_state.tested_keys, 500);
    assert_eq!(rec_state.total_keys, 10000);
    assert_eq!(rec_state.speed_keys_per_sec, 25000.0);

    state.handle_event(
        AppEvent::RecoveryCompleted(Ok(Some("secret123".to_string()))),
        tx.clone(),
    );
    assert_eq!(state.recovered_password.as_deref(), Some("secret123"));
    assert_eq!(
        state
            .recovery_modal_state
            .as_ref()
            .unwrap()
            .found_password
            .as_deref(),
        Some("secret123")
    );

    // 2. Pareto Benchmark Completed event
    state.handle_event(
        AppEvent::ParetoBenchmarkCompleted(Ok("Total MIPS: 45000".to_string())),
        tx.clone(),
    );
    assert_eq!(
        state
            .pareto_modal_state
            .as_ref()
            .unwrap()
            .mips_summary
            .as_deref(),
        Some("Total MIPS: 45000")
    );

    // 3. Split Completed event
    state.handle_event(
        AppEvent::SplitCompleted(Ok(vec![
            "archive.z01".to_string(),
            "archive.zip".to_string(),
        ])),
        tx.clone(),
    );
    assert_eq!(
        state.split_modal_state.as_ref().unwrap().created_volumes.len(),
        2
    );
}

#[test]
fn test_adaptive_centered_rect_and_modal_layout() {
    use crate::ui::modals::centered_rect_adaptive;
    use ratatui::layout::Rect;

    // Normal terminal area
    let area = Rect::new(0, 0, 100, 50);
    let rect = centered_rect_adaptive(60, 80, 20, 70, area);
    assert_eq!(rect.width, 80);
    assert_eq!(rect.height, 35);
    assert_eq!(rect.x, 10);
    assert_eq!(rect.y, 7);

    // Min bounds clamping (requested percentage smaller than min)
    let rect_min = centered_rect_adaptive(70, 50, 25, 40, area);
    assert_eq!(rect_min.width, 70);
    assert_eq!(rect_min.height, 25);

    // Small terminal area (smaller than min)
    let small_area = Rect::new(5, 5, 40, 15);
    let rect_small = centered_rect_adaptive(60, 80, 20, 70, small_area);
    assert_eq!(rect_small.width, 40); // Clamped to area width
    assert_eq!(rect_small.height, 15); // Clamped to area height
    assert_eq!(rect_small.x, 5);
    assert_eq!(rect_small.y, 5);

    // Zero area
    let zero_area = Rect::default();
    let rect_zero = centered_rect_adaptive(60, 80, 20, 70, zero_area);
    assert_eq!(rect_zero.width, 0);
    assert_eq!(rect_zero.height, 0);
}
