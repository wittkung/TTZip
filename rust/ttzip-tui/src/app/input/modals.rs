// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Keyboard handlers for repair, benchmark, split, and search modals.

use crate::app::modal_state::{ParetoModalState, SplitModalState, SplitPreset};
use crate::app::state::AppState;
use crate::app::types::AppMode;
use crate::event::AppEvent;
use crossbeam_channel::Sender;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

impl AppState {
    pub fn handle_repair_input(&mut self, key: KeyEvent, _event_sender: Sender<AppEvent>) {
        let repair = match &mut self.repair_state {
            Some(r) => r,
            None => {
                self.current_mode = AppMode::Explorer;
                return;
            }
        };

        if repair.is_editing_path {
            match key.code {
                KeyCode::Esc | KeyCode::Tab | KeyCode::Enter => {
                    repair.is_editing_path = false;
                }
                KeyCode::Backspace => {
                    repair.output_path_input.pop();
                }
                KeyCode::Char(c)
                    if !key.modifiers.contains(KeyModifiers::CONTROL)
                        && !key.modifiers.contains(KeyModifiers::ALT) =>
                {
                    repair.output_path_input.push(c);
                }
                _ => {}
            }
            return;
        }

        let total_salvaged = repair.salvaged_entries.len();

        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => {
                self.repair_state = None;
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Tab => {
                repair.is_editing_path = true;
            }
            KeyCode::Char('j') | KeyCode::Down => {
                if total_salvaged > 0 {
                    repair.selected_table_index =
                        (repair.selected_table_index + 1).min(total_salvaged - 1);
                }
            }
            KeyCode::Char('k') | KeyCode::Up => {
                if total_salvaged > 0 {
                    repair.selected_table_index =
                        repair.selected_table_index.saturating_sub(1);
                }
            }
            KeyCode::Char('g') | KeyCode::Home => {
                repair.selected_table_index = 0;
            }
            KeyCode::Char('G') | KeyCode::End => {
                if total_salvaged > 0 {
                    repair.selected_table_index = total_salvaged - 1;
                }
            }
            KeyCode::Char(' ') => {
                if let Some(entry) = repair.salvaged_entries.get_mut(repair.selected_table_index) {
                    entry.is_selected = !entry.is_selected;
                }
            }
            KeyCode::Char('a') => {
                repair.all_selected_toggle = !repair.all_selected_toggle;
                let toggle = repair.all_selected_toggle;
                for e in &mut repair.salvaged_entries {
                    e.is_selected = toggle;
                }
            }
            KeyCode::Enter => {
                self.execute_repair_reconstruction();
            }
            _ => {}
        }
    }

    pub fn handle_pareto_input(&mut self, key: KeyEvent, _event_sender: Sender<AppEvent>) {
        if self.pareto_modal_state.is_none() {
            self.pareto_modal_state = Some(ParetoModalState::new());
        }

        let pareto = match &mut self.pareto_modal_state {
            Some(s) => s,
            None => return,
        };

        let filtered_count = pareto.filtered_items().len();

        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('b') | KeyCode::Char('B') => {
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Tab => {
                pareto.active_tab = (pareto.active_tab + 1) % 3;
                pareto.filter = pareto.filter.next();
                pareto.selected_index = 0;
            }
            KeyCode::Char('1') => {
                pareto.active_tab = 0;
            }
            KeyCode::Char('2') => {
                pareto.active_tab = 1;
            }
            KeyCode::Char('3') => {
                pareto.active_tab = 2;
            }
            KeyCode::Char('+') | KeyCode::Char('=') => {
                pareto.zoom_level = (pareto.zoom_level + 0.2).min(3.0);
            }
            KeyCode::Char('-') | KeyCode::Char('_') => {
                pareto.zoom_level = (pareto.zoom_level - 0.2).max(0.5);
            }
            KeyCode::Char('0') | KeyCode::Char('r') | KeyCode::Char('z') => {
                pareto.zoom_level = 1.0;
            }
            KeyCode::Char('j') | KeyCode::Down => {
                if filtered_count > 0 {
                    pareto.selected_index = (pareto.selected_index + 1).min(filtered_count - 1);
                }
            }
            KeyCode::Char('k') | KeyCode::Up => {
                pareto.selected_index = pareto.selected_index.saturating_sub(1);
            }
            KeyCode::Char('g') | KeyCode::Home => {
                pareto.selected_index = 0;
            }
            KeyCode::Char('G') | KeyCode::End => {
                if filtered_count > 0 {
                    pareto.selected_index = filtered_count - 1;
                }
            }
            _ => {}
        }
    }

    pub fn handle_split_input(&mut self, key: KeyEvent, event_sender: Sender<AppEvent>) {
        if self.split_modal_state.is_none() {
            let default_dir = self
                .archive_path
                .parent()
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_else(|| ".".to_string());
            self.split_modal_state = Some(SplitModalState::new(default_dir));
        }

        let is_custom = self
            .split_modal_state
            .as_ref()
            .map(|s| s.active_preset() == SplitPreset::Custom)
            .unwrap_or(false);

        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('s') if !is_custom => {
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Esc => {
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Tab | KeyCode::Right => {
                if let Some(ref mut s) = self.split_modal_state {
                    s.preset_index = (s.preset_index + 1) % SplitPreset::ALL.len();
                }
            }
            KeyCode::BackTab | KeyCode::Left => {
                if let Some(ref mut s) = self.split_modal_state {
                    s.preset_index = (s.preset_index + SplitPreset::ALL.len() - 1) % SplitPreset::ALL.len();
                }
            }
            KeyCode::Char(c) if ('1'..='6').contains(&c) && !is_custom => {
                let idx = (c as usize) - ('1' as usize);
                if let Some(ref mut s) = self.split_modal_state {
                    s.preset_index = idx;
                }
            }
            KeyCode::Char('n') => {
                if let Some(ref mut s) = self.split_modal_state {
                    s.naming_scheme_idx = (s.naming_scheme_idx + 1) % 3;
                }
            }
            KeyCode::Char('j') | KeyCode::Down => {
                if let Some(ref mut s) = self.split_modal_state {
                    s.table_scroll = s.table_scroll.saturating_add(1);
                }
            }
            KeyCode::Char('k') | KeyCode::Up => {
                if let Some(ref mut s) = self.split_modal_state {
                    s.table_scroll = s.table_scroll.saturating_sub(1);
                }
            }
            KeyCode::Backspace if is_custom => {
                if let Some(ref mut s) = self.split_modal_state {
                    s.custom_size_str.pop();
                }
            }
            KeyCode::Char(c) if is_custom => {
                if !key.modifiers.contains(KeyModifiers::CONTROL) && (c.is_ascii_alphanumeric() || c == '.') {
                    if let Some(ref mut s) = self.split_modal_state {
                        s.custom_size_str.push(c);
                    }
                }
            }
            KeyCode::Enter => {
                self.trigger_split(event_sender);
            }
            _ => {}
        }
    }

    pub fn handle_search_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Esc => {
                self.current_mode = AppMode::Explorer;
            }
            KeyCode::Enter => {
                if let Some(matched) = self.search_results.get(self.search_selected_index) {
                    let target_path = matched.relative_path.clone();
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
                    self.search_selected_index =
                        (self.search_selected_index + 1).min(self.search_results.len() - 1);
                }
            }
            KeyCode::Backspace => {
                self.search_query.pop();
                self.update_search_results();
            }
            KeyCode::Char(c)
                if !key.modifiers.contains(KeyModifiers::CONTROL)
                    && !key.modifiers.contains(KeyModifiers::ALT) =>
            {
                self.search_query.push(c);
                self.update_search_results();
            }
            _ => {}
        }
    }

    pub fn update_search_results(&mut self) {
        self.search_results = self.vfs.fuzzy_search(&self.search_query);
        self.search_selected_index = 0;
    }
}
