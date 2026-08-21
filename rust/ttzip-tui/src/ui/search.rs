// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Search Overlay Component: Real-time fuzzy query input and matched results rendering.

use crate::app::AppState;
use crate::ui::explorer::format_bytes;
use crate::ui::theme::Theme;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph, Row, Table, TableState};
use ratatui::Frame;

/// Renders the fuzzy search popup modal with real-time match highlighting.
pub fn render_search_modal(frame: &mut Frame, area: Rect, state: &AppState) {
    let popup_area = centered_rect(70, 60, area);

    // Clear background behind modal
    frame.render_widget(Clear, popup_area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Input box
            Constraint::Min(3),    // Results table
            Constraint::Length(1), // Key guide
        ])
        .split(popup_area);

    // 1. Search Query Input Box
    let input_text = Line::from(vec![
        Span::styled(" 🔍 ", Style::default().fg(Theme::ACCENT_GOLD)),
        Span::styled(&state.search_query, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
        Span::styled("▎", Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::RAPID_BLINK)),
    ]);

    let input_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::ACCENT_GOLD))
        .title(" Fuzzy Search (Instant) ")
        .title_style(Theme::style_title())
        .style(Style::default().bg(Theme::BG_OVERLAY));

    let input_paragraph = Paragraph::new(input_text).block(input_block);
    frame.render_widget(input_paragraph, chunks[0]);

    // 2. Search Results List
    let result_rows: Vec<Row> = state
        .search_results
        .iter()
        .enumerate()
        .map(|(idx, res)| {
            let is_selected = idx == state.search_selected_index;

            // Build highlighted path spans
            let path_chars: Vec<char> = res.relative_path.chars().collect();
            let mut spans = Vec::new();

            for (c_idx, &ch) in path_chars.iter().enumerate() {
                if res.match_indices.contains(&c_idx) {
                    spans.push(Span::styled(
                        ch.to_string(),
                        Style::default()
                            .fg(Theme::ACCENT_GOLD)
                            .add_modifier(Modifier::BOLD | Modifier::UNDERLINED),
                    ));
                } else {
                    spans.push(Span::styled(
                        ch.to_string(),
                        Style::default().fg(if res.is_dir { Theme::ACCENT_BLUE } else { Theme::TEXT_PRIMARY }),
                    ));
                }
            }

            let score_span = Span::styled(
                format!("+{}", res.score),
                Style::default().fg(Theme::ACCENT_GREEN),
            );

            let size_str = if res.is_dir {
                "-".to_string()
            } else {
                format_bytes(res.uncompressed_size)
            };

            let cells = vec![
                ratatui::widgets::Cell::from(score_span),
                ratatui::widgets::Cell::from(Line::from(spans)),
                ratatui::widgets::Cell::from(Span::styled(size_str, Theme::style_secondary_text())),
            ];

            let mut row = Row::new(cells).height(1);
            if is_selected {
                row = row.style(Theme::style_table_selected());
            }
            row
        })
        .collect();

    let result_block = Block::default()
        .borders(Borders::LEFT | Borders::RIGHT | Borders::BOTTOM)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL))
        .title(format!(" Matches ({}) ", state.search_results.len()))
        .title_style(Theme::style_secondary_text())
        .style(Style::default().bg(Theme::BG_OVERLAY));

    let widths = [
        Constraint::Length(8),      // Score
        Constraint::Percentage(75), // Path with highlight
        Constraint::Length(12),     // Size
    ];

    let result_table = Table::new(result_rows, widths)
        .block(result_block)
        .column_spacing(1);

    let mut result_table_state = TableState::default();
    if !state.search_results.is_empty() {
        result_table_state.select(Some(state.search_selected_index));
    }

    frame.render_stateful_widget(result_table, chunks[1], &mut result_table_state);

    // 3. Navigation guide footer
    let guide_line = Line::from(vec![
        Span::styled(" [↑/↓] ", Theme::style_key_shortcut()),
        Span::styled("Navigate  ", Theme::style_muted_text()),
        Span::styled("[Enter] ", Theme::style_key_shortcut()),
        Span::styled("Jump to Entry  ", Theme::style_muted_text()),
        Span::styled("[Esc] ", Theme::style_key_shortcut()),
        Span::styled("Close Search", Theme::style_muted_text()),
    ]);
    let guide_p = Paragraph::new(guide_line)
        .alignment(Alignment::Center)
        .style(Style::default().bg(Theme::BG_OVERLAY));
    frame.render_widget(guide_p, chunks[2]);
}

/// Helper function to create a centered Rect overlay.
pub fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}
