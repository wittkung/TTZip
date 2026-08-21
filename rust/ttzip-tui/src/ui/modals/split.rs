// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Multi-Volume Split Manager & Physical Segment Planner Modal.

use crate::app::{AppState, SplitPreset};
use crate::cli::format::format_bytes;
use crate::ui::search::centered_rect;
use crate::ui::theme::Theme;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph, Row, Table, TableState};
use ratatui::Frame;
use std::path::Path;
use ttzip_glue::archive::split::{compute_volume_path, VolumeNamingScheme};

/// Derived volume breakdown entry for real-time split projection.
#[derive(Debug, Clone, PartialEq)]
pub struct SplitVolumeInfo {
    pub index: usize,
    pub filename: String,
    pub size_bytes: u64,
    pub range_display: String,
    pub percentage: f64,
}

/// Derives physical volume files, sizes, and byte offset boundaries in real time.
pub fn derive_split_volumes(
    archive_path: &Path,
    total_bytes: u64,
    chunk_size_bytes: u64,
    naming_scheme: VolumeNamingScheme,
) -> Vec<SplitVolumeInfo> {
    if total_bytes == 0 || chunk_size_bytes == 0 {
        return Vec::new();
    }

    let mut volumes = Vec::new();
    let count = ((total_bytes + chunk_size_bytes - 1) / chunk_size_bytes) as usize;
    let mut remaining = total_bytes;
    let mut offset = 0u64;

    for i in 1..=count {
        let vol_size = remaining.min(chunk_size_bytes);
        let start_offset = offset;
        let end_offset = offset + vol_size;
        offset = end_offset;
        remaining = remaining.saturating_sub(vol_size);

        let path = if naming_scheme == VolumeNamingScheme::PkzipSpanned && i == count && count > 1 {
            archive_path.to_path_buf()
        } else {
            compute_volume_path(archive_path, i, naming_scheme)
        };

        let filename = path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("volume")
            .to_string();

        let pct = if total_bytes > 0 {
            (vol_size as f64 / total_bytes as f64) * 100.0
        } else {
            100.0
        };

        let range_display = format!("{} .. {}", format_bytes(start_offset), format_bytes(end_offset));

        volumes.push(SplitVolumeInfo {
            index: i,
            filename,
            size_bytes: vol_size,
            range_display,
            percentage: pct,
        });
    }

    volumes
}

/// Renders the interactive Multi-Volume Split Manager Modal.
pub fn render_split_modal(frame: &mut Frame, area: Rect, state: &AppState) {
    let popup_area = centered_rect(84, 80, area);
    frame.render_widget(Clear, popup_area);

    let modal_block = Theme::modal_block(" ✂️ Multi-Volume Split Manager & Physical Segment Planner ");
    frame.render_widget(modal_block, popup_area);

    let split = match &state.split_modal_state {
        Some(s) => s,
        None => return,
    };

    let inner = Rect {
        x: popup_area.x + 1,
        y: popup_area.y + 1,
        width: popup_area.width.saturating_sub(2),
        height: popup_area.height.saturating_sub(2),
    };

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Preset tabs
            Constraint::Length(3), // Scheme & Output Info
            Constraint::Min(8),    // Volumes Derivation Table
            Constraint::Length(2), // Action footer
        ])
        .split(inner);

    // 1. Preset Selector Tabs & Custom Input Bar
    render_presets_bar(frame, chunks[0], split);

    // 2. Naming Scheme & Output Metadata Bar
    render_config_bar(frame, chunks[1], state, split);

    // 3. Real-Time Physical Volume Derivation Table
    render_volumes_table(frame, chunks[2], state, split);

    // 4. Action Guide & Shortcuts
    render_footer_guide(frame, chunks[3]);
}

fn render_presets_bar(frame: &mut Frame, area: Rect, split: &crate::app::SplitModalState) {
    let mut spans = vec![
        Span::styled(" Preset: ", Theme::style_secondary_text()),
    ];

    for (idx, preset) in SplitPreset::ALL.iter().enumerate() {
        let is_active = idx == split.preset_index;
        let prefix = format!("{}. ", idx + 1);
        let mut label = format!(" {}{} ", prefix, preset.label());

        if *preset == SplitPreset::Custom && is_active {
            label = format!(" 6. Custom: [{}] ", split.custom_size_str);
        }

        if is_active {
            spans.push(Span::styled(
                label,
                Style::default()
                    .fg(Theme::BG_BASE)
                    .bg(Theme::ACCENT_GOLD)
                    .add_modifier(Modifier::BOLD),
            ));
        } else {
            spans.push(Span::styled(
                label,
                Style::default().fg(Theme::TEXT_SECONDARY),
            ));
        }
        spans.push(Span::raw(" "));
    }

    let block = Block::default()
        .borders(Borders::BOTTOM)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL));

    let p = Paragraph::new(Line::from(spans)).block(block);
    frame.render_widget(p, area);
}

fn render_config_bar(frame: &mut Frame, area: Rect, state: &AppState, split: &crate::app::SplitModalState) {
    let scheme_names = ["1. Numbered (.001)", "2. PKZip Spanned (.z01)", "3. Raw (.001)"];
    let mut scheme_spans = vec![
        Span::styled(" Naming Scheme [n]: ", Theme::style_secondary_text()),
    ];

    for (i, name) in scheme_names.iter().enumerate() {
        if i == split.naming_scheme_idx % 3 {
            scheme_spans.push(Span::styled(
                format!(" [{}] ", name),
                Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD),
            ));
        } else {
            scheme_spans.push(Span::styled(
                format!("  {}  ", name),
                Theme::style_muted_text(),
            ));
        }
    }

    let archive_name = state.archive_path.file_name().and_then(|s| s.to_str()).unwrap_or("archive");
    scheme_spans.push(Span::styled(
        format!(" │ Target Archive: {} ({})", archive_name, format_bytes(state.total_size_bytes)),
        Style::default().fg(Theme::TEXT_PRIMARY),
    ));

    let block = Block::default()
        .borders(Borders::BOTTOM)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL));

    let p = Paragraph::new(Line::from(scheme_spans)).block(block);
    frame.render_widget(p, area);
}

fn render_volumes_table(frame: &mut Frame, area: Rect, state: &AppState, split: &crate::app::SplitModalState) {
    let chunk_size = split.current_chunk_size_bytes().unwrap_or(700 * 1024 * 1024);
    let volumes = derive_split_volumes(&state.archive_path, state.total_size_bytes, chunk_size, split.naming_scheme());

    let rows: Vec<Row> = volumes
        .iter()
        .skip(split.table_scroll)
        .enumerate()
        .map(|(idx, vol)| {
            let cells = vec![
                ratatui::widgets::Cell::from(Span::styled(format!("Vol #{}", vol.index), Style::default().fg(Theme::ACCENT_GOLD))),
                ratatui::widgets::Cell::from(Span::styled(vol.filename.clone(), Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD))),
                ratatui::widgets::Cell::from(Span::styled(format_bytes(vol.size_bytes), Style::default().fg(Theme::ACCENT_BLUE))),
                ratatui::widgets::Cell::from(Span::styled(vol.range_display.clone(), Theme::style_secondary_text())),
                ratatui::widgets::Cell::from(Span::styled(format!("{:.1}%", vol.percentage), Style::default().fg(Theme::ACCENT_GREEN))),
            ];
            let mut r = Row::new(cells).height(1);
            if idx == 0 {
                r = r.style(Style::default().bg(Theme::BG_SURFACE));
            }
            r
        })
        .collect();

    let title_info = format!(" 📋 Physical Volumes Breakdown (Total: {} volumes, Chunk: {}) ", volumes.len(), format_bytes(chunk_size));
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL))
        .title(title_info)
        .title_style(Theme::style_title());

    let widths = [
        Constraint::Length(9),
        Constraint::Percentage(35),
        Constraint::Length(14),
        Constraint::Percentage(30),
        Constraint::Length(9),
    ];

    let table = Table::new(rows, widths)
        .header(Row::new(vec!["Volume", "Physical Filename", "Segment Size", "Byte Offset Range", "Share%"]).style(Theme::style_table_header()))
        .block(block)
        .column_spacing(1);

    let mut table_state = TableState::default();
    if !volumes.is_empty() {
        table_state.select(Some(0));
    }

    frame.render_stateful_widget(table, area, &mut table_state);
}

fn render_footer_guide(frame: &mut Frame, area: Rect) {
    let guide_line = Line::from(vec![
        Span::styled(" [Tab/1-6] ", Theme::style_key_shortcut()),
        Span::styled("Preset  ", Theme::style_muted_text()),
        Span::styled("[n] ", Theme::style_key_shortcut()),
        Span::styled("Scheme  ", Theme::style_muted_text()),
        Span::styled("[j/k/↑/↓] ", Theme::style_key_shortcut()),
        Span::styled("Scroll Table  ", Theme::style_muted_text()),
        Span::styled("[Enter] ", Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD)),
        Span::styled("Execute Split  ", Theme::style_secondary_text()),
        Span::styled("[Esc/q] ", Theme::style_key_shortcut()),
        Span::styled("Cancel", Theme::style_muted_text()),
    ]);
    let guide_p = Paragraph::new(guide_line).alignment(Alignment::Center);
    frame.render_widget(guide_p, area);
}
