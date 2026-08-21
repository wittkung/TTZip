// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unit and integration tests for Password Recovery Modal, speed gauge, and Rayon worker.

use crate::app::modal_state::RecoveryModalState;
use crate::app::recovery_runner::{
    extract_recovery_target, generate_numeric_pins, get_top_passwords, spawn_recovery_worker,
};
use crate::app::state::AppState;
use crate::app::types::AppMode;
use crate::event::AppEvent;
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::backend::TestBackend;
use ratatui::Terminal;
use std::io::Write;
use ttzip_glue::runtime::cancellation::CancellationToken;
use ttzip_glue::types::TTZipEncryptionMethod;
use ttzip_glue::zip::writer::{assemble_zip_archive, compress_items_parallel, ZipInputItem};

fn create_encrypted_zip_file(password: &str) -> tempfile::NamedTempFile {
    let items = vec![ZipInputItem {
        rel_path: "secret.txt".to_string(),
        data: b"Secret Payload Content 2026".to_vec(),
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
    }];

    let compressed =
        compress_items_parallel(items, 6, TTZipEncryptionMethod::Aes256, Some(password), 2)
            .expect("compress");
    let zip_bytes = assemble_zip_archive(&compressed).expect("assemble");

    let mut tmp = tempfile::NamedTempFile::new().expect("tempfile");
    tmp.write_all(&zip_bytes).expect("write");
    tmp
}

#[test]
fn test_recovery_modal_navigation_and_presets() {
    let tmp = create_encrypted_zip_file("SecretPassword123");
    let mut state = AppState::new(tmp.path().to_path_buf()).expect("init state");
    let (tx, _rx) = crossbeam_channel::unbounded();

    // 1. Enter Recovery Mode ('r')
    state.handle_key_event(KeyEvent::from(KeyCode::Char('r')), tx.clone());
    assert_eq!(state.current_mode, AppMode::PasswordRecovery);
    assert!(state.recovery_modal_state.is_some());

    // 2. Switch presets (1 -> 2 -> 3)
    state.handle_key_event(KeyEvent::from(KeyCode::Char('2')), tx.clone());
    assert_eq!(state.recovery_modal_state.as_ref().unwrap().dict_choice, 1);

    state.handle_key_event(KeyEvent::from(KeyCode::Char('3')), tx.clone());
    assert_eq!(state.recovery_modal_state.as_ref().unwrap().dict_choice, 2);

    // 3. Tab to path input and type custom dictionary
    state.handle_key_event(KeyEvent::from(KeyCode::Tab), tx.clone());
    assert_eq!(state.recovery_modal_state.as_ref().unwrap().selected_field, 1);

    for c in "dict.txt".chars() {
        state.handle_key_event(KeyEvent::from(KeyCode::Char(c)), tx.clone());
    }
    assert_eq!(
        state.recovery_modal_state.as_ref().unwrap().custom_dict_path,
        "dict.txt"
    );

    // Backspace
    state.handle_key_event(KeyEvent::from(KeyCode::Backspace), tx.clone());
    assert_eq!(
        state.recovery_modal_state.as_ref().unwrap().custom_dict_path,
        "dict.tx"
    );

    // BackTab to preset selector
    state.handle_key_event(KeyEvent::from(KeyCode::BackTab), tx.clone());
    assert_eq!(state.recovery_modal_state.as_ref().unwrap().selected_field, 0);

    // 4. Arrow navigation
    state.handle_key_event(KeyEvent::from(KeyCode::Left), tx.clone());
    assert_eq!(state.recovery_modal_state.as_ref().unwrap().dict_choice, 1);

    state.handle_key_event(KeyEvent::from(KeyCode::Right), tx.clone());
    assert_eq!(state.recovery_modal_state.as_ref().unwrap().dict_choice, 2);

    // 5. Esc closes modal
    state.handle_key_event(KeyEvent::from(KeyCode::Esc), tx.clone());
    assert_eq!(state.current_mode, AppMode::Explorer);
}

#[test]
fn test_recovery_runner_and_auto_unlock() {
    let password = "SecretPassword123";
    let tmp = create_encrypted_zip_file(password);
    let mut state = AppState::new(tmp.path().to_path_buf()).expect("init state");
    let (tx, rx) = crossbeam_channel::unbounded();

    state.current_mode = AppMode::PasswordRecovery;
    state.recovery_modal_state = Some(RecoveryModalState::default());

    // Start recovery with Top 10K (which contains SecretPassword123)
    state.handle_key_event(KeyEvent::from(KeyCode::Enter), tx.clone());

    let rec_state = state.recovery_modal_state.as_ref().unwrap();
    assert!(rec_state.is_running);
    assert!(rec_state.total_keys > 0);

    // Receive events from worker thread
    let mut found = false;
    while let Ok(event) = rx.recv_timeout(std::time::Duration::from_secs(3)) {
        match event {
            AppEvent::RecoveryCompleted(Ok(Some(pwd))) => {
                assert_eq!(pwd, password);
                state.handle_event(AppEvent::RecoveryCompleted(Ok(Some(pwd))), tx.clone());
                found = true;
                break;
            }
            AppEvent::RecoveryProgress { .. } => {
                state.handle_event(event, tx.clone());
            }
            _ => {}
        }
    }
    assert!(found);
    assert_eq!(state.recovered_password.as_deref(), Some(password));
    assert_eq!(
        state.recovery_modal_state.as_ref().unwrap().found_password.as_deref(),
        Some(password)
    );

    // Auto-unlock via Enter returns to Explorer with password stored
    state.handle_key_event(KeyEvent::from(KeyCode::Enter), tx.clone());
    assert_eq!(state.current_mode, AppMode::Explorer);
    assert_eq!(state.recovered_password.as_deref(), Some(password));
}

#[test]
fn test_recovery_runner_generator_and_cancellation() {
    let top = get_top_passwords();
    assert!(top.len() > 100);
    assert!(top.contains(&"123456".to_string()));

    let pins = generate_numeric_pins();
    assert_eq!(pins.len(), 10_000 + 1_000_000);
    assert_eq!(pins[0], "0000");

    let tmp = create_encrypted_zip_file("999999");
    let state = AppState::new(tmp.path().to_path_buf()).expect("init state");
    let target = extract_recovery_target(&state.archive_raw_data, &state.archive_format)
        .expect("extract target");

    let token = CancellationToken::new();
    let (tx, rx) = crossbeam_channel::unbounded();

    // Spawn huge search
    spawn_recovery_worker(target, pins, 2, token.clone(), tx);

    // Cancel immediately (< 5ms)
    token.cancel(ttzip_glue::runtime::cancellation::CancellationReason::UserRequested);

    let start = std::time::Instant::now();
    let mut cancelled = false;
    while let Ok(event) = rx.recv_timeout(std::time::Duration::from_millis(500)) {
        if let AppEvent::RecoveryCompleted(Err(msg)) = event {
            assert!(msg.contains("cancelled"));
            cancelled = true;
            break;
        }
    }
    let elapsed = start.elapsed();
    assert!(cancelled);
    assert!(elapsed < std::time::Duration::from_millis(100));
}

#[test]
fn test_render_recovery_modal_widget_drawing() {
    let tmp = create_encrypted_zip_file("123456");
    let mut state = AppState::new(tmp.path().to_path_buf()).expect("init state");
    state.current_mode = AppMode::PasswordRecovery;
    state.recovery_modal_state = Some(RecoveryModalState::default());

    let backend = TestBackend::new(100, 30);
    let mut terminal = Terminal::new(backend).expect("create terminal");

    terminal
        .draw(|f| {
            crate::ui::modals::recovery::render_recovery_modal(f, f.area(), &state);
        })
        .expect("draw recovery modal");
}
