// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Password recovery modal keyboard interaction and runner dispatch.

use crate::app::modal_state::RecoveryModalState;
use crate::app::state::AppState;
use crate::app::types::AppMode;
use crate::event::AppEvent;
use crossbeam_channel::Sender;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ttzip_glue::runtime::cancellation::CancellationReason;

impl AppState {
    /// Handles keyboard events when in Password Recovery mode.
    pub fn handle_recovery_input(&mut self, key: KeyEvent, event_sender: Sender<AppEvent>) {
        if self.recovery_modal_state.is_none() {
            self.recovery_modal_state = Some(RecoveryModalState::default());
        }

        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => {
                let is_running = self.recovery_modal_state.as_ref().map(|s| s.is_running).unwrap_or(false);
                if is_running {
                    self.cancellation_token.cancel(CancellationReason::UserRequested);
                    if let Some(ref mut s) = self.recovery_modal_state {
                        s.is_running = false;
                        s.status_message = Some("Recovery cancelled".to_string());
                    }
                } else {
                    self.current_mode = AppMode::Explorer;
                }
            }
            KeyCode::Tab => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    let max_f = if state.dict_choice == 2 { 2 } else { 1 };
                    state.selected_field = (state.selected_field + 1) % max_f;
                }
            }
            KeyCode::BackTab => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    let max_f = if state.dict_choice == 2 { 2 } else { 1 };
                    state.selected_field = if state.selected_field == 0 {
                        max_f - 1
                    } else {
                        state.selected_field - 1
                    };
                }
            }
            KeyCode::Left | KeyCode::Char('h') => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 0 {
                        state.dict_choice = if state.dict_choice == 0 {
                            2
                        } else {
                            state.dict_choice - 1
                        };
                    }
                }
            }
            KeyCode::Right | KeyCode::Char('l') => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 0 {
                        state.dict_choice = (state.dict_choice + 1) % 3;
                    }
                }
            }
            KeyCode::Char('1') => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 0 {
                        state.dict_choice = 0;
                    }
                }
            }
            KeyCode::Char('2') => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 0 {
                        state.dict_choice = 1;
                    }
                }
            }
            KeyCode::Char('3') => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 0 {
                        state.dict_choice = 2;
                    }
                }
            }
            KeyCode::Backspace => {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 1 {
                        state.custom_dict_path.pop();
                    }
                }
            }
            KeyCode::Char(c)
                if !key.modifiers.contains(KeyModifiers::CONTROL)
                    && !key.modifiers.contains(KeyModifiers::ALT) =>
            {
                if let Some(ref mut state) = self.recovery_modal_state {
                    if state.selected_field == 1 {
                        state.custom_dict_path.push(c);
                    }
                }
            }
            KeyCode::Enter | KeyCode::Char(' ') => {
                let found_pwd = self
                    .recovery_modal_state
                    .as_ref()
                    .and_then(|s| s.found_password.clone());
                let is_running = self
                    .recovery_modal_state
                    .as_ref()
                    .map(|s| s.is_running)
                    .unwrap_or(false);

                if let Some(pwd) = found_pwd {
                    self.recovered_password = Some(pwd.clone());
                    self.set_status(format!("Archive unlocked with password: \"{}\"", pwd));
                    self.current_mode = AppMode::Explorer;
                } else if is_running {
                    self.cancellation_token.cancel(CancellationReason::UserRequested);
                    if let Some(ref mut s) = self.recovery_modal_state {
                        s.is_running = false;
                        s.status_message = Some("Recovery stopped by user".to_string());
                    }
                } else {
                    self.start_recovery_runner(event_sender);
                }
            }
            _ => {}
        }
    }
}



