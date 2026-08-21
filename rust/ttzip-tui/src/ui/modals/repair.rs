// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Interactive Corrupted Archive Repair & Salvage Wizard Modal View Component.

use super::centered_rect_adaptive;
use crate::app::repair_runner::RepairStatus;
use crate::app::AppState;
use crate::ui::explorer::format_bytes;
use crate::ui::theme::Theme;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Cell, Clear, Paragraph, Row, Table, TableState};
use ratatui::Frame;

/// Renders the Interactive Corrupted Archive Repair & Salvage Wizard modal.
pub fn render_repair_modal(frame: &mut Frame, area: Rect, state: &AppState) {
    let repair = match &state.repair_state {
        Some(r) => r,
        None => return,
    };

    let popup_area = centered_rect_adaptive(70, 82, 16, 85, area);
    frame.render_widget(Clear, popup_area);

    let modal_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(Theme::ACCENT_GOLD))
        .title(" 🛠️ TTZip Self-Healing Corrupted Archive Repair & Salvage Wizard ")
        .title_style(Theme::style_title())
        .style(Style::default().bg(Theme::BG_OVERLAY));

    let inner_area = modal_block.inner(popup_area);
    frame.render_widget(modal_block, popup_area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(4), // 1. Diagnostic Banner
            Constraint::Min(6),    // 2. Salvageable Entries Table
            Constraint::Length(3), // 3. Output Path Input Box
            Constraint::Length(2), // 4. Action & Key Guide Footer
        ])
        .split(inner_area);

    // 1. Diagnostic Banner
    render_diagnostic_banner(frame, chunks[0], repair);

    // 2. Salvageable Entries Table
    render_salvage_table(frame, chunks[1], repair);

    // 3. Target Path Input Box
    render_path_input(frame, chunks[2], repair);

    // 4. Action / Status Guide Footer
    render_footer_guide(frame, chunks[3], repair);
}

fn render_diagnostic_banner(frame: &mut Frame, area: Rect, repair: &crate::app::repair_runner::RepairState) {
    let damaged_file_name = repair
        .damaged_path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Source");

    let count = repair.salvaged_entries.len();
    let selected_count = repair.salvaged_entries.iter().filter(|e| e.is_selected).count();
    let total_salvage_uncomp: u64 = repair.salvaged_entries.iter().map(|e| e.uncompressed_size).sum();

    let banner_lines = vec![
        Line::from(vec![
            Span::styled(" ⚠️ Corrupt Archive Detected: ", Style::default().fg(Theme::ACCENT_ORANGE).add_modifier(Modifier::BOLD)),
            Span::styled(damaged_file_name, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
            Span::styled(format!(" [{}]", repair.detected_format), Style::default().fg(Theme::ACCENT_BLUE)),
            Span::styled(format!(" (Stream Size: {})", format_bytes(repair.damaged_bytes)), Theme::style_muted_text()),
        ]),
        Line::from(vec![
            Span::styled("   ⚡ NEON SIMD Salvage Scanner: ", Theme::style_secondary_text()),
            Span::styled(format!("{} entries found", count), Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)),
            Span::styled(format!(" ({} selected, {})", selected_count, format_bytes(total_salvage_uncomp)), Theme::style_muted_text()),
            Span::styled(" — TOC Central Directory will be reconstructed.", Theme::style_secondary_text()),
        ]),
    ];

    let banner_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::ACCENT_GOLD))
        .style(Style::default().bg(Theme::BG_SURFACE));

    let banner_p = Paragraph::new(banner_lines).block(banner_block);
    frame.render_widget(banner_p, area);
}

fn render_salvage_table(frame: &mut Frame, area: Rect, repair: &crate::app::repair_runner::RepairState) {
    let header_cells = [
        " SEL ",
        "Salvaged Entry Path",
        "Comp Size",
        "Uncomp Size",
        "CRC32",
        "Method",
    ]
    .into_iter()
    .map(|h| Cell::from(Span::styled(h, Theme::style_table_header())));

    let header = Row::new(header_cells)
        .height(1)
        .bottom_margin(1)
        .style(Theme::style_table_header());

    let rows: Vec<Row> = repair
        .salvaged_entries
        .iter()
        .enumerate()
        .map(|(idx, entry)| {
            let is_cursor = idx == repair.selected_table_index;

            let check_span = if entry.is_selected {
                Span::styled(" [x] ", Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD))
            } else {
                Span::styled(" [ ] ", Theme::style_muted_text())
            };

            let icon = if entry.is_directory { "📁 " } else { "📄 " };
            let name_span = Span::styled(
                format!("{}{}", icon, entry.rel_path),
                Style::default().fg(if entry.is_directory { Theme::ACCENT_BLUE } else { Theme::TEXT_PRIMARY }),
            );

            let comp_str = format_bytes(entry.compressed_size);
            let uncomp_str = format_bytes(entry.uncompressed_size);
            let crc_str = if entry.crc32 != 0 {
                format!("{:08X}", entry.crc32)
            } else {
                "-".to_string()
            };
            let method_str = entry.method_name();

            let cells = vec![
                Cell::from(check_span),
                Cell::from(Line::from(name_span)),
                Cell::from(Span::styled(comp_str, Theme::style_muted_text())),
                Cell::from(Span::styled(uncomp_str, Theme::style_secondary_text())),
                Cell::from(Span::styled(crc_str, Theme::style_muted_text())),
                Cell::from(Span::styled(method_str, Style::default().fg(Theme::ACCENT_GREEN))),
            ];

            let mut row = Row::new(cells).height(1);
            if is_cursor {
                row = row.style(Theme::style_table_selected());
            }
            row
        })
        .collect();

    let widths = [
        Constraint::Length(6),          // SEL
        Constraint::Percentage(45),     // Path
        Constraint::Length(12),         // Comp Size
        Constraint::Length(12),         // Uncomp Size
        Constraint::Length(10),         // CRC32
        Constraint::Length(10),         // Method
    ];

    let count_info = format!(" Salvageable Local File Headers ({}) ", repair.salvaged_entries.len());
    let table_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL))
        .title(count_info)
        .title_style(Theme::style_title())
        .style(Style::default().bg(Theme::BG_SURFACE));

    let table = Table::new(rows, widths)
        .header(header)
        .block(table_block)
        .column_spacing(1);

    let mut table_state = TableState::default();
    if !repair.salvaged_entries.is_empty() {
        table_state.select(Some(repair.selected_table_index));
    }

    frame.render_stateful_widget(table, area, &mut table_state);
}

fn render_path_input(frame: &mut Frame, area: Rect, repair: &crate::app::repair_runner::RepairState) {
    let border_color = if repair.is_editing_path {
        Theme::BORDER_FOCUSED
    } else {
        Theme::BORDER_NORMAL
    };

    let title = if repair.is_editing_path {
        " 🎯 Target Output Archive Path (EDITING - Press [Tab]/[Enter] to confirm) "
    } else {
        " 🎯 Target Output Archive Path (Press [Tab] to edit) "
    };

    let input_line = if repair.is_editing_path {
        Line::from(vec![
            Span::styled(" > ", Style::default().fg(Theme::ACCENT_GOLD)),
            Span::styled(&repair.output_path_input, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
            Span::styled("█", Style::default().fg(Theme::ACCENT_BLUE)),
        ])
    } else {
        Line::from(vec![
            Span::styled("   ", Theme::style_muted_text()),
            Span::styled(&repair.output_path_input, Theme::style_secondary_text()),
        ])
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color))
        .title(title)
        .title_style(if repair.is_editing_path { Theme::style_title() } else { Theme::style_secondary_text() })
        .style(Style::default().bg(Theme::BG_SURFACE));

    let p = Paragraph::new(input_line).block(block);
    frame.render_widget(p, area);
}

fn render_footer_guide(frame: &mut Frame, area: Rect, repair: &crate::app::repair_runner::RepairState) {
    match &repair.status {
        RepairStatus::Ready => {
            let guide_line = Line::from(vec![
                Span::styled(" [Enter] ", Theme::style_key_shortcut()),
                Span::styled("Reconstruct & Load  ", Theme::style_primary_text()),
                Span::styled("[Space] ", Theme::style_key_shortcut()),
                Span::styled("Toggle  ", Theme::style_muted_text()),
                Span::styled("[a] ", Theme::style_key_shortcut()),
                Span::styled("All  ", Theme::style_muted_text()),
                Span::styled("[Tab] ", Theme::style_key_shortcut()),
                Span::styled("Edit Path  ", Theme::style_muted_text()),
                Span::styled("[j/k/↑/↓] ", Theme::style_key_shortcut()),
                Span::styled("Scroll  ", Theme::style_muted_text()),
                Span::styled("[Esc] ", Theme::style_key_shortcut()),
                Span::styled("Cancel", Theme::style_muted_text()),
            ]);
            let p = Paragraph::new(guide_line)
                .alignment(Alignment::Center)
                .style(Style::default().bg(Theme::BG_OVERLAY));
            frame.render_widget(p, area);
        }
        RepairStatus::Rebuilding => {
            let line = Line::from(vec![
                Span::styled(" ⚙️ Rebuilding TOC Central Directory & Synthesizing Archive Stream... ", Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)),
            ]);
            let p = Paragraph::new(line).alignment(Alignment::Center);
            frame.render_widget(p, area);
        }
        RepairStatus::Success(count) => {
            let line = Line::from(vec![
                Span::styled(format!(" ✅ Successfully repaired and recovered {} entries! Press [Enter] to load.", count), Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD)),
            ]);
            let p = Paragraph::new(line).alignment(Alignment::Center);
            frame.render_widget(p, area);
        }
        RepairStatus::Error(msg) => {
            let line = Line::from(vec![
                Span::styled(format!(" ❌ Repair failed: {}. Press [Esc] to return.", msg), Style::default().fg(Theme::ACCENT_RED).add_modifier(Modifier::BOLD)),
            ]);
            let p = Paragraph::new(line).alignment(Alignment::Center);
            frame.render_widget(p, area);
        }
    }
}
