// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! UI Root Layout and Component Composition.

pub mod explorer;
pub mod modals;
pub mod progress;
pub mod search;
pub mod theme;

use crate::app::{AppMode, AppState};
use crate::preview::PreviewData;
use crate::ui::explorer::format_bytes;
use crate::ui::search::centered_rect;
use crate::ui::theme::Theme;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph, Wrap};
use ratatui::Frame;

/// Renders the full TUI root interface and active modals.
pub fn render(frame: &mut Frame, state: &mut AppState) {
    let size = frame.area();

    // 1. Root Vertical Layout: Header (3) | Body (Min) | Footer (2)
    let root_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Top Header Bar
            Constraint::Min(5),    // Main Body
            Constraint::Length(2), // Bottom Status / Keybinding Footer
        ])
        .split(size);

    // 2. Render Top Header Bar
    render_header(frame, root_chunks[0], state);

    // 3. Render Main Body
    if state.current_mode == AppMode::Preview && state.preview_content.is_some() {
        let body_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(55), // Explorer Tree
                Constraint::Percentage(45), // QuickLook Preview Pane
            ])
            .split(root_chunks[1]);

        explorer::render_explorer(frame, body_chunks[0], state);
        render_preview_pane(frame, body_chunks[1], state);
    } else {
        explorer::render_explorer(frame, root_chunks[1], state);
    }

    // 4. Render Bottom Footer
    render_footer(frame, root_chunks[2], state);

    // 5. Render Modal Overlays if active
    match state.current_mode {
        AppMode::Search => {
            search::render_search_modal(frame, size, state);
        }
        AppMode::Progress => {
            progress::render_progress_modal(frame, size, state);
        }
        AppMode::Help => {
            render_help_modal(frame, size);
        }
        AppMode::PasswordRecovery => {
            modals::render_recovery_modal(frame, size, state);
        }
        AppMode::RepairWizard => {
            modals::render_repair_modal(frame, size, state);
        }
        AppMode::ParetoBenchmark => {
            modals::render_pareto_modal(frame, size, state);
        }
        AppMode::SplitManager => {
            modals::render_split_modal(frame, size, state);
        }
        _ => {}
    }
}

/// Renders top status and archive metadata header.
fn render_header(frame: &mut Frame, area: Rect, state: &AppState) {
    let archive_name = state
        .archive_path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Archive");

    let header_line1 = Line::from(vec![
        Span::styled(" 📦 TTZip ", Theme::style_title()),
        Span::styled(format!("v{} ", env!("CARGO_PKG_VERSION")), Theme::style_muted_text()),
        Span::styled(" │ Archive: ", Theme::style_secondary_text()),
        Span::styled(archive_name, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
        Span::styled(format!(" [{}]", state.archive_format), Style::default().fg(Theme::ACCENT_BLUE)),
        Span::styled(" │ Size: ", Theme::style_secondary_text()),
        Span::styled(format_bytes(state.total_size_bytes), Theme::style_primary_text()),
        Span::styled(format!(" (Uncompressed: {})", format_bytes(state.uncompressed_size_bytes)), Theme::style_muted_text()),
        Span::styled(" │ Entries: ", Theme::style_secondary_text()),
        Span::styled(state.entries_count.to_string(), Style::default().fg(Theme::ACCENT_GOLD)),
    ]);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL))
        .style(Theme::style_header_bar());

    let p = Paragraph::new(header_line1).block(block);
    frame.render_widget(p, area);
}

/// Renders bottom shortcut guide and status messages.
fn render_footer(frame: &mut Frame, area: Rect, state: &AppState) {
    let shortcuts = Line::from(vec![
        Span::styled(" [j/k] ", Theme::style_key_shortcut()),
        Span::styled("Move  ", Theme::style_muted_text()),
        Span::styled("[Space] ", Theme::style_key_shortcut()),
        Span::styled("Mark  ", Theme::style_muted_text()),
        Span::styled("[Enter] ", Theme::style_key_shortcut()),
        Span::styled("Extract  ", Theme::style_muted_text()),
        Span::styled("[/] ", Theme::style_key_shortcut()),
        Span::styled("Search  ", Theme::style_muted_text()),
        Span::styled("[p] ", Theme::style_key_shortcut()),
        Span::styled("Preview  ", Theme::style_muted_text()),
        Span::styled("[r] ", Theme::style_key_shortcut()),
        Span::styled("Recover  ", Theme::style_muted_text()),
        Span::styled("[R] ", Theme::style_key_shortcut()),
        Span::styled("Repair  ", Theme::style_muted_text()),
        Span::styled("[B] ", Theme::style_key_shortcut()),
        Span::styled("Bench  ", Theme::style_muted_text()),
        Span::styled("[S] ", Theme::style_key_shortcut()),
        Span::styled("Split  ", Theme::style_muted_text()),
        Span::styled("[?] ", Theme::style_key_shortcut()),
        Span::styled("Help  ", Theme::style_muted_text()),
        Span::styled("[q] ", Theme::style_key_shortcut()),
        Span::styled("Quit", Theme::style_muted_text()),
    ]);

    let status_line = if let Some((msg, _)) = &state.status_message {
        Line::from(vec![
            Span::styled(" 💡 ", Style::default().fg(Theme::ACCENT_GOLD)),
            Span::styled(msg, Style::default().fg(Theme::TEXT_PRIMARY)),
        ])
    } else {
        Line::from(vec![
            Span::styled(" ⚡ Apple Silicon ARM64 Accelerated Engine", Theme::style_muted_text()),
        ])
    };

    let p = Paragraph::new(vec![shortcuts, status_line])
        .style(Theme::style_footer_bar());
    frame.render_widget(p, area);
}

/// Renders QuickLook stream preview pane.
fn render_preview_pane(frame: &mut Frame, area: Rect, state: &AppState) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::ACCENT_GOLD))
        .title(" 👁️ In-Terminal QuickLook Preview (Press [Esc]/[p] to close) ")
        .title_style(Theme::style_title())
        .style(Style::default().bg(Theme::BG_SURFACE));

    match &state.preview_content {
        Some(PreviewData::Text { lines, syntax_language, is_truncated }) => {
            let mut text_lines: Vec<Line> = lines
                .iter()
                .skip(state.preview_scroll)
                .take(area.height.saturating_sub(2) as usize)
                .map(|l| Line::from(l.as_str()))
                .collect();

            if *is_truncated {
                text_lines.push(Line::from(Span::styled(
                    " [Preview 64KB Limit Reached] ",
                    Style::default().fg(Theme::ACCENT_ORANGE),
                )));
            }

            let title_info = format!(" Language: {} ", syntax_language);
            let p = Paragraph::new(text_lines)
                .block(block.title(title_info))
                .wrap(Wrap { trim: false });
            frame.render_widget(p, area);
        }
        Some(PreviewData::HexDump { offset_hex_pairs, total_bytes_displayed }) => {
            let dump_lines: Vec<Line> = offset_hex_pairs
                .iter()
                .skip(state.preview_scroll)
                .take(area.height.saturating_sub(2) as usize)
                .map(|(offset, hex, ascii)| {
                    Line::from(vec![
                        Span::styled(format!("{} ", offset), Theme::style_muted_text()),
                        Span::styled(format!("{:48} ", hex), Style::default().fg(Theme::ACCENT_BLUE)),
                        Span::styled(format!("|{}|", ascii), Style::default().fg(Theme::ACCENT_GREEN)),
                    ])
                })
                .collect();

            let title_info = format!(" Hex Dump ({} bytes) ", total_bytes_displayed);
            let p = Paragraph::new(dump_lines)
                .block(block.title(title_info));
            frame.render_widget(p, area);
        }
        Some(PreviewData::Unsupported { reason, file_size_bytes }) => {
            let line = Line::from(vec![
                Span::styled(format!("Preview Unavailable: {} (Size: {})", reason, format_bytes(*file_size_bytes)), Theme::style_secondary_text()),
            ]);
            let p = Paragraph::new(vec![line]).block(block);
            frame.render_widget(p, area);
        }
        None => {
            let p = Paragraph::new("No preview available").block(block);
            frame.render_widget(p, area);
        }
    }
}

/// Renders Help Keyboard Shortcuts Modal.
fn render_help_modal(frame: &mut Frame, area: Rect) {
    let popup_area = centered_rect(60, 65, area);
    frame.render_widget(Clear, popup_area);

    let block = Theme::modal_block(" 📖 TTZip Keyboard Shortcuts & Navigation Reference ");
    let help_text = vec![
        Line::from(vec![
            Span::styled(" Navigation:", Theme::style_title()),
        ]),
        Line::from(vec![
            Span::styled("   j / ↓             ", Theme::style_key_shortcut()),
            Span::styled("Move cursor down", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   k / ↑             ", Theme::style_key_shortcut()),
            Span::styled("Move cursor up", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   g / Home          ", Theme::style_key_shortcut()),
            Span::styled("Jump to top of archive", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   G / End           ", Theme::style_key_shortcut()),
            Span::styled("Jump to bottom of archive", Theme::style_primary_text()),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled(" Selection & Extraction:", Theme::style_title()),
        ]),
        Line::from(vec![
            Span::styled("   Space             ", Theme::style_key_shortcut()),
            Span::styled("Toggle selection mark [x] on file/directory", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   a                 ", Theme::style_key_shortcut()),
            Span::styled("Select all / Deselect all entries", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   Enter             ", Theme::style_key_shortcut()),
            Span::styled("Expand/Collapse folder or Extract selected items", Theme::style_primary_text()),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled(" Preview & Search:", Theme::style_title()),
        ]),
        Line::from(vec![
            Span::styled("   p / Tab           ", Theme::style_key_shortcut()),
            Span::styled("Toggle in-terminal QuickLook stream preview", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   /                 ", Theme::style_key_shortcut()),
            Span::styled("Open instant fuzzy search bar", Theme::style_primary_text()),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled(" Modals & Recovery Tools:", Theme::style_title()),
        ]),
        Line::from(vec![
            Span::styled("   r                 ", Theme::style_key_shortcut()),
            Span::styled("Password recovery dictionary wizard", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   R                 ", Theme::style_key_shortcut()),
            Span::styled("Self-healing corrupt archive repair wizard", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   B                 ", Theme::style_key_shortcut()),
            Span::styled("Pareto frontier & hardware benchmark engine", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   S                 ", Theme::style_key_shortcut()),
            Span::styled("Multi-volume archive split & join manager", Theme::style_primary_text()),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled(" Control & Cancellation:", Theme::style_title()),
        ]),
        Line::from(vec![
            Span::styled("   Esc / q           ", Theme::style_key_shortcut()),
            Span::styled("Atomic cancel background task or Quit application", Theme::style_primary_text()),
        ]),
        Line::from(vec![
            Span::styled("   ? / h             ", Theme::style_key_shortcut()),
            Span::styled("Show / hide this help dialog", Theme::style_primary_text()),
        ]),
    ];

    let p = Paragraph::new(help_text).block(block);
    frame.render_widget(p, popup_area);
}

#[cfg(test)]
mod tests;

