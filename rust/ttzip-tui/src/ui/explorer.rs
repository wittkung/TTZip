// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Explorer Table Component: Multi-level directory tree navigation with file metadata.

use crate::app::AppState;
use crate::ui::theme::Theme;
use ratatui::layout::{Constraint, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Cell, Row, Table, TableState};
use ratatui::Frame;

/// Renders the main file explorer directory tree table.
pub fn render_explorer(frame: &mut Frame, area: Rect, state: &AppState) {
    let header_cells = [
        " ",
        "Name",
        "Size",
        "Compressed",
        "Ratio",
        "CRC32",
        "Enc",
    ]
    .into_iter()
    .map(|h| Cell::from(Span::styled(h, Theme::style_table_header())));

    let header = Row::new(header_cells)
        .height(1)
        .bottom_margin(1)
        .style(Theme::style_table_header());

    let visible_items = state.vfs.flatten_visible();

    let rows: Vec<Row> = visible_items
        .iter()
        .enumerate()
        .map(|(idx, item)| {
            let is_selected_cursor = idx == state.selected_index;
            let node = item.node;

            // Selection mark column
            let sel_mark = if node.is_selected {
                Span::styled(" [x] ", Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD))
            } else {
                Span::styled(" [ ] ", Theme::style_muted_text())
            };

            let name_color = if node.is_dir {
                Theme::ACCENT_BLUE
            } else {
                Theme::TEXT_PRIMARY
            };

            let name_span = Span::styled(
                format!("{}{}{}", item.indent_prefix, node.icon(), node.name),
                Style::default().fg(name_color),
            );

            // File size formatting
            let uncomp_str = if node.is_dir {
                if node.uncompressed_size > 0 {
                    format_bytes(node.uncompressed_size)
                } else {
                    "-".to_string()
                }
            } else {
                format_bytes(node.uncompressed_size)
            };

            let comp_str = if node.is_dir {
                if node.compressed_size > 0 {
                    format_bytes(node.compressed_size)
                } else {
                    "-".to_string()
                }
            } else {
                format_bytes(node.compressed_size)
            };

            let ratio_str = if !node.is_dir && node.uncompressed_size > 0 {
                let r = (node.compressed_size as f64 / node.uncompressed_size as f64) * 100.0;
                format!("{:.1}%", r)
            } else {
                "-".to_string()
            };

            let crc_str = if !node.is_dir && node.crc32 != 0 {
                format!("{:08X}", node.crc32)
            } else {
                "-".to_string()
            };

            let enc_span = if node.is_encrypted {
                Span::styled("🔒", Style::default().fg(Theme::ACCENT_ORANGE))
            } else {
                Span::styled("-", Theme::style_muted_text())
            };

            let cells = vec![
                Cell::from(sel_mark),
                Cell::from(Line::from(name_span)),
                Cell::from(Span::styled(uncomp_str, Theme::style_secondary_text())),
                Cell::from(Span::styled(comp_str, Theme::style_muted_text())),
                Cell::from(Span::styled(ratio_str, Style::default().fg(Theme::ACCENT_GREEN))),
                Cell::from(Span::styled(crc_str, Theme::style_muted_text())),
                Cell::from(enc_span),
            ];

            let mut table_row = Row::new(cells).height(1);
            if is_selected_cursor {
                table_row = table_row.style(Theme::style_table_selected());
            }
            table_row
        })
        .collect();

    let widths = [
        Constraint::Length(5),          // Mark
        Constraint::Percentage(45),     // Name
        Constraint::Length(12),         // Size
        Constraint::Length(12),         // Comp Size
        Constraint::Length(8),          // Ratio
        Constraint::Length(10),         // CRC32
        Constraint::Length(5),          // Enc
    ];

    let block = Theme::default_block(" 🗂️ Archive Hierarchy Tree ");
    let table = Table::new(rows, widths)
        .header(header)
        .block(block)
        .column_spacing(1);

    let mut table_state = TableState::default();
    if !visible_items.is_empty() {
        table_state.select(Some(state.selected_index));
    }

    frame.render_stateful_widget(table, area, &mut table_state);
}

/// Helper to format raw bytes into human readable decimal string.
pub fn format_bytes(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;
    const TB: u64 = GB * 1024;

    if bytes >= TB {
        format!("{:.2} TB", bytes as f64 / TB as f64)
    } else if bytes >= GB {
        format!("{:.2} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{} B", bytes)
    }
}
