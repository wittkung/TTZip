// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Keyboard event handling and operational mode dispatch.

use super::state::AppState;
use super::types::AppMode;
use crate::event::AppEvent;
use crossbeam_channel::Sender;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ttzip_glue::runtime::cancellation::CancellationReason;

impl AppState {
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
}
