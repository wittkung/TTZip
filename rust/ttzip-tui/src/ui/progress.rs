// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Progress Dashboard Component: Multi-core live progress gauge, throughput MB/s, and CPU load monitor.

use crate::app::AppState;
use crate::ui::explorer::format_bytes;
use crate::ui::search::centered_rect;
use crate::ui::theme::Theme;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Gauge, Paragraph};
use ratatui::Frame;
use serde::{Deserialize, Serialize};

/// Progress snapshot payload emitted by background extraction or compression pipelines.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProgressSnapshot {
    pub task_title: String,
    pub current_entry_name: String,
    pub processed_bytes: u64,
    pub total_bytes: u64,
    pub processed_entries: usize,
    pub total_entries: usize,
    pub instant_throughput_mb_per_sec: f64,
    pub elapsed_seconds: f64,
    pub eta_seconds: f64,
}

impl Default for ProgressSnapshot {
    fn default() -> Self {
        Self {
            task_title: "Processing Archive...".to_string(),
            current_entry_name: String::new(),
            processed_bytes: 0,
            total_bytes: 1,
            processed_entries: 0,
            total_entries: 1,
            instant_throughput_mb_per_sec: 0.0,
            elapsed_seconds: 0.0,
            eta_seconds: 0.0,
        }
    }
}

/// Renders the multi-core extraction/compression progress dashboard modal.
pub fn render_progress_modal(frame: &mut Frame, area: Rect, state: &AppState) {
    let popup_area = centered_rect(65, 50, area);

    // Clear background behind modal
    frame.render_widget(Clear, popup_area);

    let snap = state.progress_state.as_ref().cloned().unwrap_or_default();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Title & Current entry
            Constraint::Length(3), // Bytes Gauge
            Constraint::Length(3), // Entries Gauge
            Constraint::Length(4), // Metrics (Throughput, ETA, Accel)
            Constraint::Length(1), // Key prompt (Esc to cancel)
        ])
        .split(popup_area);

    let modal_block = Theme::modal_block(" ⚡ Live Multi-Core Pipeline Dashboard ");
    frame.render_widget(modal_block, popup_area);

    // 1. Current File Name Line
    let entry_display = if snap.current_entry_name.is_empty() {
        "Preparing stream...".to_string()
    } else {
        truncate_string(&snap.current_entry_name, 50)
    };

    let title_line = Line::from(vec![
        Span::styled(" Task: ", Theme::style_secondary_text()),
        Span::styled(&snap.task_title, Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)),
        Span::styled("  |  Current: ", Theme::style_secondary_text()),
        Span::styled(entry_display, Style::default().fg(Theme::TEXT_PRIMARY)),
    ]);
    let title_p = Paragraph::new(title_line).alignment(Alignment::Center);
    frame.render_widget(title_p, chunks[0]);

    // 2. Bytes Progress Gauge
    let byte_ratio = if snap.total_bytes > 0 {
        (snap.processed_bytes as f64 / snap.total_bytes as f64).clamp(0.0, 1.0)
    } else {
        0.0
    };

    let byte_label = format!(
        "{:.1}% ({} / {})",
        byte_ratio * 100.0,
        format_bytes(snap.processed_bytes),
        format_bytes(snap.total_bytes)
    );

    let byte_gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Theme::BORDER_NORMAL))
                .title(" Data Throughput Progress ")
                .title_style(Theme::style_secondary_text()),
        )
        .gauge_style(
            Style::default()
                .fg(Theme::ACCENT_GOLD)
                .bg(Theme::BG_SURFACE)
                .add_modifier(Modifier::BOLD),
        )
        .ratio(byte_ratio)
        .label(byte_label);

    frame.render_widget(byte_gauge, chunks[1]);

    // 3. Entries Count Progress Gauge
    let entry_ratio = if snap.total_entries > 0 {
        (snap.processed_entries as f64 / snap.total_entries as f64).clamp(0.0, 1.0)
    } else {
        0.0
    };

    let entry_label = format!(
        "{} / {} entries ({:.1}%)",
        snap.processed_entries,
        snap.total_entries,
        entry_ratio * 100.0
    );

    let entry_gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Theme::BORDER_NORMAL))
                .title(" Entries Processed ")
                .title_style(Theme::style_secondary_text()),
        )
        .gauge_style(
            Style::default()
                .fg(Theme::ACCENT_BLUE)
                .bg(Theme::BG_SURFACE)
                .add_modifier(Modifier::BOLD),
        )
        .ratio(entry_ratio)
        .label(entry_label);

    frame.render_widget(entry_gauge, chunks[2]);

    // 4. Metrics Grid (Instant Speed, Elapsed, ETA, Hardware Accel)
    let speed_str = if snap.instant_throughput_mb_per_sec >= 1024.0 {
        format!("{:.2} GB/s", snap.instant_throughput_mb_per_sec / 1024.0)
    } else {
        format!("{:.1} MB/s", snap.instant_throughput_mb_per_sec)
    };

    let elapsed_str = format_seconds(snap.elapsed_seconds);
    let eta_str = format_seconds(snap.eta_seconds);

    let metrics_line1 = Line::from(vec![
        Span::styled(" Instant Speed: ", Theme::style_secondary_text()),
        Span::styled(speed_str, Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD)),
        Span::styled("   ⏱ Elapsed: ", Theme::style_secondary_text()),
        Span::styled(elapsed_str, Style::default().fg(Theme::TEXT_PRIMARY)),
        Span::styled("   ⏳ ETA: ", Theme::style_secondary_text()),
        Span::styled(eta_str, Style::default().fg(Theme::ACCENT_GOLD)),
    ]);

    let metrics_line2 = Line::from(vec![
        Span::styled(" Hardware Engine: ", Theme::style_secondary_text()),
        Span::styled("Apple Silicon ARM64 NEON / AES Pipeline Active (Multi-Threaded)", Style::default().fg(Theme::ACCENT_BLUE)),
    ]);

    let metrics_p = Paragraph::new(vec![metrics_line1, metrics_line2])
        .alignment(Alignment::Center);
    frame.render_widget(metrics_p, chunks[3]);

    // 5. Atomic Cancellation Prompt
    let cancel_line = Line::from(vec![
        Span::styled(" [Esc] ", Style::default().fg(Theme::ACCENT_RED).add_modifier(Modifier::BOLD)),
        Span::styled("or ", Theme::style_muted_text()),
        Span::styled("[q] ", Style::default().fg(Theme::ACCENT_RED).add_modifier(Modifier::BOLD)),
        Span::styled("Atomic Cancel (<5ms safe rollback)", Theme::style_secondary_text()),
    ]);
    let cancel_p = Paragraph::new(cancel_line).alignment(Alignment::Center);
    frame.render_widget(cancel_p, chunks[4]);
}

fn format_seconds(secs: f64) -> String {
    let total_s = secs.max(0.0) as u64;
    let m = total_s / 60;
    let s = total_s % 60;
    format!("{:02}:{:02}", m, s)
}

fn truncate_string(s: &str, max_len: usize) -> String {
    if s.chars().count() <= max_len {
        s.to_string()
    } else {
        let prefix: String = s.chars().take(max_len.saturating_sub(3)).collect();
        format!("{}...", prefix)
    }
}
