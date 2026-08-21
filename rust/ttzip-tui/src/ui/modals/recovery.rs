// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Interactive Password Recovery Modal with Live Speedometer and Auto-Unlock.

use super::centered_rect_adaptive;
use crate::app::modal_state::RecoveryModalState;
use crate::app::AppState;
use crate::ui::theme::Theme;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Gauge, Paragraph};
use ratatui::Frame;

/// Renders the interactive password recovery modal overlay.
pub fn render_recovery_modal(frame: &mut Frame, area: Rect, state: &AppState) {
    let popup_area = centered_rect_adaptive(64, 74, 14, 70, area);
    frame.render_widget(Clear, popup_area);

    let recovery_state = state
        .recovery_modal_state
        .as_ref()
        .cloned()
        .unwrap_or_default();

    let modal_title = if recovery_state.found_password.is_some() {
        " 🎉 TTZip Password Recovery: KEY FOUND! 🎉 "
    } else {
        " 🔑 Multi-Core Password Recovery (Rayon SIMD/NEON Engine) "
    };

    let border_color = if recovery_state.found_password.is_some() {
        Theme::ACCENT_GREEN
    } else if recovery_state.is_running {
        Theme::ACCENT_GOLD
    } else {
        Theme::BORDER_MODAL
    };

    let modal_block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Thick)
        .border_style(Style::default().fg(border_color))
        .title(modal_title)
        .title_style(Style::default().fg(border_color).add_modifier(Modifier::BOLD))
        .style(Style::default().bg(Theme::BG_OVERLAY));

    frame.render_widget(modal_block, popup_area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2), // Archive info summary
            Constraint::Length(4), // Dictionary Presets / Custom Input
            Constraint::Length(3), // Progress Gauge
            Constraint::Length(2), // Metrics Grid (Speed, Elapsed, ETA)
            Constraint::Length(4), // Status Banner / Password Hit Notice
            Constraint::Length(1), // Navigation guide footer
        ])
        .margin(1)
        .split(popup_area);

    // 1. Archive Header Info
    render_header_info(frame, chunks[0], state);

    // 2. Dictionary Presets Selector
    render_preset_selector(frame, chunks[1], &recovery_state);

    // 3. Progress Bar & Gauge
    render_speed_gauge(frame, chunks[2], &recovery_state);

    // 4. Metrics Grid
    render_metrics_grid(frame, chunks[3], &recovery_state);

    // 5. Password Hit or Status Banner
    render_status_banner(frame, chunks[4], &recovery_state);

    // 6. Navigation Footer
    render_footer_guide(frame, chunks[5], &recovery_state);
}

fn render_header_info(frame: &mut Frame, area: Rect, state: &AppState) {
    let archive_name = state
        .archive_path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Archive");

    let header_line = Line::from(vec![
        Span::styled("Target: ", Theme::style_secondary_text()),
        Span::styled(archive_name, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
        Span::styled(" │ Format: ", Theme::style_secondary_text()),
        Span::styled(&state.archive_format, Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD)),
        Span::styled(" │ Acceleration: ", Theme::style_secondary_text()),
        Span::styled("Rayon Multi-Core + NEON SIMD", Style::default().fg(Theme::ACCENT_GOLD)),
    ]);
    frame.render_widget(Paragraph::new(header_line).alignment(Alignment::Center), area);
}

fn render_preset_selector(frame: &mut Frame, area: Rect, state: &RecoveryModalState) {
    let is_focused = state.selected_field == 0;
    let focus_style = if is_focused {
        Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)
    } else {
        Theme::style_secondary_text()
    };

    let opt0 = if state.dict_choice == 0 { "[•] 1. Top 10K Dictionary" } else { "[ ] 1. Top 10K Dictionary" };
    let opt1 = if state.dict_choice == 1 { "[•] 2. Numeric PIN (4-6 Digits)" } else { "[ ] 2. Numeric PIN (4-6 Digits)" };
    let opt2 = if state.dict_choice == 2 { "[•] 3. Custom Wordlist" } else { "[ ] 3. Custom Wordlist" };

    let opt0_style = if state.dict_choice == 0 { Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD) } else { Theme::style_muted_text() };
    let opt1_style = if state.dict_choice == 1 { Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD) } else { Theme::style_muted_text() };
    let opt2_style = if state.dict_choice == 2 { Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD) } else { Theme::style_muted_text() };

    let preset_line = Line::from(vec![
        Span::styled("Dictionary Preset: ", focus_style),
        Span::styled(format!("  {}  ", opt0), opt0_style),
        Span::styled(format!("  {}  ", opt1), opt1_style),
        Span::styled(format!("  {}  ", opt2), opt2_style),
    ]);

    let detail_line = match state.dict_choice {
        0 => Line::from(vec![
            Span::styled("   → High-frequency common passwords with capitalization and digit variations", Theme::style_muted_text()),
        ]),
        1 => Line::from(vec![
            Span::styled("   → Exhaustive 4-digit (0000..9999) & 6-digit (000000..999999) numeric space", Theme::style_muted_text()),
        ]),
        2 => {
            let path_display = if state.custom_dict_path.is_empty() {
                &state.dictionary_path
            } else {
                &state.custom_dict_path
            };
            Line::from(vec![
                Span::styled("   Wordlist Path: [", Theme::style_secondary_text()),
                Span::styled(path_display, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
                Span::styled(if state.selected_field == 1 { "▎]" } else { "]" }, Style::default().fg(Theme::ACCENT_GOLD)),
                Span::styled(" (Type path or Tab to edit)", Theme::style_muted_text()),
            ])
        }
        _ => Line::from(""),
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(if is_focused { Style::default().fg(Theme::ACCENT_GOLD) } else { Style::default().fg(Theme::BORDER_NORMAL) })
        .title(" Dictionary Attack Strategy ")
        .title_style(focus_style)
        .style(Style::default().bg(Theme::BG_SURFACE));

    let p = Paragraph::new(vec![preset_line, detail_line]).block(block);
    frame.render_widget(p, area);
}

fn render_speed_gauge(frame: &mut Frame, area: Rect, state: &RecoveryModalState) {
    let ratio = if state.total_keys > 0 {
        (state.tested_keys as f64 / state.total_keys as f64).clamp(0.0, 1.0)
    } else {
        0.0
    };

    let label = if state.total_keys > 0 {
        format!("{:.1}% ({}/{} keys)", ratio * 100.0, state.tested_keys, state.total_keys)
    } else {
        "0.0% (0 keys tested)".to_string()
    };

    let gauge_color = if state.found_password.is_some() {
        Theme::ACCENT_GREEN
    } else {
        Theme::ACCENT_BLUE
    };

    let gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Theme::BORDER_NORMAL))
                .title(" Live Candidate Verification Gauge ")
                .title_style(Theme::style_secondary_text()),
        )
        .gauge_style(Style::default().fg(gauge_color).bg(Theme::BG_SURFACE).add_modifier(Modifier::BOLD))
        .ratio(ratio)
        .label(label);

    frame.render_widget(gauge, area);
}

fn render_metrics_grid(frame: &mut Frame, area: Rect, state: &RecoveryModalState) {
    let speed_str = format_keys_per_sec(state.speed_keys_per_sec);
    let elapsed_str = format_seconds(state.elapsed_secs);
    let eta_str = if state.eta_secs > 0.0 && state.is_running {
        format_seconds(state.eta_secs)
    } else {
        "--:--".to_string()
    };

    let metrics_line = Line::from(vec![
        Span::styled(" Speedometer: ", Theme::style_secondary_text()),
        Span::styled(speed_str, Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD)),
        Span::styled("  │  Elapsed: ", Theme::style_secondary_text()),
        Span::styled(elapsed_str, Style::default().fg(Theme::TEXT_PRIMARY)),
        Span::styled("  │  ETA: ", Theme::style_secondary_text()),
        Span::styled(eta_str, Style::default().fg(Theme::ACCENT_GOLD)),
        Span::styled("  │  Workers: ", Theme::style_secondary_text()),
        Span::styled(format!("{} Rayon Threads", state.threads), Style::default().fg(Theme::ACCENT_BLUE)),
    ]);

    frame.render_widget(Paragraph::new(metrics_line).alignment(Alignment::Center), area);
}

fn render_status_banner(frame: &mut Frame, area: Rect, state: &RecoveryModalState) {
    if let Some(ref pwd) = state.found_password {
        let block = Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Double)
            .border_style(Style::default().fg(Theme::ACCENT_GREEN))
            .style(Style::default().bg(Theme::BG_SURFACE));

        let lines = vec![
            Line::from(vec![
                Span::styled(" 🎉 MATCH FOUND: \"", Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD)),
                Span::styled(pwd, Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD | Modifier::UNDERLINED)),
                Span::styled("\" 🎉", Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD)),
            ]),
            Line::from(vec![
                Span::styled(" Press ", Theme::style_secondary_text()),
                Span::styled("[Enter]", Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)),
                Span::styled(" to auto-unlock archive and decrypt selected entries with 0 friction!", Theme::style_secondary_text()),
            ]),
        ];

        let p = Paragraph::new(lines).block(block).alignment(Alignment::Center);
        frame.render_widget(p, area);
    } else {
        let block = Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Theme::BORDER_NORMAL))
            .style(Style::default().bg(Theme::BG_SURFACE));

        let status_text = if state.is_running {
            "⚡ Parallel Rayon search actively running in background... Press [Esc] to stop."
        } else if let Some(ref err) = state.error_message {
            err.as_str()
        } else if let Some(ref msg) = state.status_message {
            msg.as_str()
        } else {
            "Ready. Press [Enter] or [Space] to start multi-threaded password recovery."
        };

        let status_color = if state.error_message.is_some() {
            Theme::ACCENT_RED
        } else if state.is_running {
            Theme::ACCENT_GOLD
        } else {
            Theme::TEXT_PRIMARY
        };

        let p = Paragraph::new(Line::from(vec![
            Span::styled("Status: ", Theme::style_secondary_text()),
            Span::styled(status_text, Style::default().fg(status_color)),
        ]))
        .block(block)
        .alignment(Alignment::Center);

        frame.render_widget(p, area);
    }
}

fn render_footer_guide(frame: &mut Frame, area: Rect, state: &RecoveryModalState) {
    let enter_action = if state.found_password.is_some() {
        "Unlock & Decrypt"
    } else if state.is_running {
        "Stop Recovery"
    } else {
        "Start Recovery"
    };

    let guide_line = Line::from(vec![
        Span::styled(" [Tab/BackTab] ", Theme::style_key_shortcut()),
        Span::styled("Focus  ", Theme::style_muted_text()),
        Span::styled("[1/2/3/←/→] ", Theme::style_key_shortcut()),
        Span::styled("Preset  ", Theme::style_muted_text()),
        Span::styled("[Enter] ", Theme::style_key_shortcut()),
        Span::styled(format!("{}  ", enter_action), Style::default().fg(Theme::ACCENT_GREEN)),
        Span::styled("[Esc/q] ", Theme::style_key_shortcut()),
        Span::styled("Cancel", Theme::style_muted_text()),
    ]);

    frame.render_widget(Paragraph::new(guide_line).alignment(Alignment::Center), area);
}

fn format_seconds(secs: f64) -> String {
    let total_s = secs.max(0.0) as u64;
    let m = total_s / 60;
    let s = total_s % 60;
    format!("{:02}:{:02}", m, s)
}

fn format_keys_per_sec(speed: f64) -> String {
    if speed >= 1_000_000.0 {
        format!("{:.2} M keys/s", speed / 1_000_000.0)
    } else if speed >= 1_000.0 {
        format!("{:.1} k keys/s", speed / 1_000.0)
    } else {
        format!("{:.0} keys/s", speed)
    }
}
