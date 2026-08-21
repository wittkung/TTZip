// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Interactive 2D Pareto Frontier Canvas & Multi-Codec Optimization Modal.

use crate::app::{AppState, ParetoFilter};
use crate::cli::braille_plotter::BenchmarkCodecItem;
use crate::ui::search::centered_rect;
use crate::ui::theme::Theme;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::symbols::Marker;
use ratatui::text::{Line, Span};
use ratatui::widgets::canvas::{Canvas, Line as CanvasLine, Points};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph, Row, Table, TableState};
use ratatui::Frame;

/// Renders interactive 2D Pareto Canvas modal with log10 throughput and upper convex hull.
pub fn render_pareto_modal(frame: &mut Frame, area: Rect, state: &AppState) {
    let popup_area = centered_rect(88, 86, area);
    frame.render_widget(Clear, popup_area);

    let modal_block = Theme::modal_block(" 📊 Interactive 2D Pareto Frontier & Codec Optimization Canvas ");
    frame.render_widget(modal_block, popup_area);

    let pareto = match &state.pareto_modal_state {
        Some(s) => s,
        None => return,
    };

    let inner = Rect {
        x: popup_area.x + 1,
        y: popup_area.y + 1,
        width: popup_area.width.saturating_sub(2),
        height: popup_area.height.saturating_sub(2),
    };

    let main_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Top Filter Bar & Zoom
            Constraint::Min(10),   // Canvas (Left) & Metrics/List (Right)
            Constraint::Length(2), // Bottom Keybinding Guide
        ])
        .split(inner);

    render_filter_bar(frame, main_chunks[0], pareto);

    let body_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(58), Constraint::Percentage(42)])
        .split(main_chunks[1]);

    render_canvas_pane(frame, body_chunks[0], pareto);
    render_details_pane(frame, body_chunks[1], pareto);
    render_footer_guide(frame, main_chunks[2]);
}

fn render_filter_bar(frame: &mut Frame, area: Rect, state: &crate::app::ParetoModalState) {
    let mut spans = vec![Span::styled(" Filter: ", Theme::style_secondary_text())];

    for filter in ParetoFilter::ALL.iter() {
        let is_active = state.filter == *filter;
        let count = state.items.iter().filter(|it| match filter {
            ParetoFilter::All => true,
            ParetoFilter::ParetoOptimal => it.raw.is_pareto_optimal,
            ParetoFilter::ConvexHull => it.raw.is_on_convex_envelope,
            ParetoFilter::TTZipOnly => it.name.starts_with("TTZip"),
        }).count();

        let label = format!(" [{}: {}] ", filter.label(), count);
        let style = if is_active {
            Style::default().fg(Theme::BG_BASE).bg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(Theme::TEXT_SECONDARY)
        };
        spans.push(Span::styled(label, style));
        spans.push(Span::raw(" "));
    }

    spans.push(Span::styled(
        format!("│ Zoom: {:.1}x ", state.zoom_level),
        Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD),
    ));

    let block = Block::default().borders(Borders::BOTTOM).border_style(Style::default().fg(Theme::BORDER_NORMAL));
    let p = Paragraph::new(Line::from(spans)).block(block);
    frame.render_widget(p, area);
}

fn render_canvas_pane(frame: &mut Frame, area: Rect, state: &crate::app::ParetoModalState) {
    let zoom = state.zoom_level.max(0.2);
    let (center_x, half_w) = (2.25_f64, 1.35_f64 / zoom);
    let x_bounds = [(center_x - half_w).max(0.5), center_x + half_w];

    let (center_y, half_h) = (42.5_f64, 45.0_f64 / zoom);
    let y_bounds = [(center_y - half_h).max(0.0), (center_y + half_h).min(100.0)];

    let filtered = state.filtered_items();
    let focused = state.current_focus_item();

    let mut hull_points: Vec<&BenchmarkCodecItem> = state.items.iter().filter(|it| it.raw.is_on_convex_envelope).collect();
    hull_points.sort_by(|a, b| a.throughput_mbs.partial_cmp(&b.throughput_mbs).unwrap_or(std::cmp::Ordering::Equal));

    let canvas = Canvas::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Theme::BORDER_NORMAL))
                .title(" 📈 Throughput (log10 MB/s) vs Space Savings (%) ")
                .title_style(Theme::style_title()),
        )
        .marker(Marker::Braille)
        .x_bounds(x_bounds)
        .y_bounds(y_bounds)
        .paint(move |ctx| {
            for w in hull_points.windows(2) {
                ctx.draw(&CanvasLine {
                    x1: w[0].throughput_mbs.log10(),
                    y1: w[0].space_savings_pct,
                    x2: w[1].throughput_mbs.log10(),
                    y2: w[1].space_savings_pct,
                    color: Theme::ACCENT_GOLD,
                });
            }
            for it in &filtered {
                let (x, y) = (it.throughput_mbs.log10(), it.space_savings_pct);
                let color = if it.raw.is_on_convex_envelope {
                    Theme::ACCENT_GOLD
                } else if it.raw.is_pareto_optimal {
                    Theme::ACCENT_BLUE
                } else {
                    Theme::TEXT_MUTED
                };
                ctx.draw(&Points { coords: &[(x, y)], color });
            }
            if let Some(fc) = focused {
                let (fx, fy) = (fc.throughput_mbs.log10(), fc.space_savings_pct);
                ctx.draw(&Points { coords: &[(fx, fy)], color: Theme::ACCENT_RED });
                ctx.print(fx + 0.05, fy, Span::styled(format!("◄ {} ({})", fc.name, fc.level), Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)));
            }
        });

    frame.render_widget(canvas, area);
}

fn render_details_pane(frame: &mut Frame, area: Rect, state: &crate::app::ParetoModalState) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(10), Constraint::Min(6)])
        .split(area);

    render_focus_metrics_card(frame, chunks[0], state);
    render_codec_table(frame, chunks[1], state);
}

fn render_focus_metrics_card(frame: &mut Frame, area: Rect, state: &crate::app::ParetoModalState) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::BORDER_FOCUSED))
        .title(" 🎯 Focus Codec Metrics ")
        .title_style(Theme::style_title());

    let lines = if let Some(fc) = state.current_focus_item() {
        let opt_badge = if fc.raw.is_pareto_optimal {
            Span::styled("🌟 Yes (Optimal Tier 1)", Style::default().fg(Theme::ACCENT_GREEN).add_modifier(Modifier::BOLD))
        } else {
            Span::styled("❌ No (Dominated)", Theme::style_muted_text())
        };
        let hull_badge = if fc.raw.is_on_convex_envelope {
            Span::styled("🏆 Yes (Upper Envelope)", Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD))
        } else {
            Span::styled("No", Theme::style_muted_text())
        };
        let ratio = 100.0 / (100.0 - fc.space_savings_pct).max(0.1);

        vec![
            Line::from(vec![
                Span::styled(" Codec & Level : ", Theme::style_secondary_text()),
                Span::styled(format!("{} ({})", fc.name, fc.level), Style::default().fg(Theme::TEXT_PRIMARY).add_modifier(Modifier::BOLD)),
            ]),
            Line::from(vec![
                Span::styled(" Throughput    : ", Theme::style_secondary_text()),
                Span::styled(format!("{:>7.1} MB/s", fc.throughput_mbs), Style::default().fg(Theme::ACCENT_BLUE).add_modifier(Modifier::BOLD)),
                Span::styled(format!(" (log10: {:.2})", fc.throughput_mbs.log10()), Theme::style_muted_text()),
            ]),
            Line::from(vec![
                Span::styled(" Space Savings : ", Theme::style_secondary_text()),
                Span::styled(format!("{:>5.1}%", fc.space_savings_pct), Style::default().fg(Theme::ACCENT_GOLD).add_modifier(Modifier::BOLD)),
                Span::styled(format!(" (Ratio: {:.2}x)", ratio), Theme::style_muted_text()),
            ]),
            Line::from(vec![
                Span::styled(" Pareto Optimal: ", Theme::style_secondary_text()),
                opt_badge,
                Span::styled(" | Convex Hull: ", Theme::style_secondary_text()),
                hull_badge,
            ]),
            Line::from(vec![
                Span::styled(" Pareto Tier   : ", Theme::style_secondary_text()),
                Span::styled(format!("Rank #{}", fc.raw.pareto_rank), Style::default().fg(Theme::ACCENT_PURPLE).add_modifier(Modifier::BOLD)),
                Span::styled(" | Accel: ", Theme::style_secondary_text()),
                Span::styled("NEON/AES Pipeline", Style::default().fg(Theme::ACCENT_BLUE)),
            ]),
        ]
    } else {
        vec![Line::from(Span::styled("No codecs matching active filter", Theme::style_muted_text()))]
    };

    let p = Paragraph::new(lines).block(block);
    frame.render_widget(p, area);
}

fn render_codec_table(frame: &mut Frame, area: Rect, state: &crate::app::ParetoModalState) {
    let filtered = state.filtered_items();
    let rows: Vec<Row> = filtered
        .iter()
        .enumerate()
        .map(|(idx, it)| {
            let is_sel = idx == state.selected_index.min(filtered.len().saturating_sub(1));
            let rank_color = if it.raw.is_on_convex_envelope {
                Theme::ACCENT_GOLD
            } else if it.raw.is_pareto_optimal {
                Theme::ACCENT_BLUE
            } else {
                Theme::TEXT_MUTED
            };

            let cells = vec![
                ratatui::widgets::Cell::from(Span::styled(format!("#{}", it.raw.pareto_rank), Style::default().fg(rank_color))),
                ratatui::widgets::Cell::from(Span::styled(it.name.clone(), Style::default().fg(Theme::TEXT_PRIMARY))),
                ratatui::widgets::Cell::from(Span::styled(it.level.clone(), Theme::style_secondary_text())),
                ratatui::widgets::Cell::from(Span::styled(format!("{:.0}", it.throughput_mbs), Style::default().fg(Theme::ACCENT_BLUE))),
                ratatui::widgets::Cell::from(Span::styled(format!("{:.1}%", it.space_savings_pct), Style::default().fg(Theme::ACCENT_GOLD))),
            ];

            let mut row = Row::new(cells).height(1);
            if is_sel {
                row = row.style(Theme::style_table_selected());
            }
            row
        })
        .collect();

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Theme::BORDER_NORMAL))
        .title(" 📋 Codec Rankings ");

    let widths = [
        Constraint::Length(5),
        Constraint::Percentage(40),
        Constraint::Length(7),
        Constraint::Length(9),
        Constraint::Length(8),
    ];

    let table = Table::new(rows, widths)
        .header(Row::new(vec!["Rank", "Codec", "Lvl", "MB/s", "Sav%"]).style(Theme::style_table_header()))
        .block(block)
        .column_spacing(1);

    let mut table_state = TableState::default();
    if !filtered.is_empty() {
        table_state.select(Some(state.selected_index.min(filtered.len() - 1)));
    }

    frame.render_stateful_widget(table, area, &mut table_state);
}

fn render_footer_guide(frame: &mut Frame, area: Rect) {
    let guide_line = Line::from(vec![
        Span::styled(" [j/k/↑/↓] ", Theme::style_key_shortcut()),
        Span::styled("Roam Focus  ", Theme::style_muted_text()),
        Span::styled("[Tab] ", Theme::style_key_shortcut()),
        Span::styled("Filter  ", Theme::style_muted_text()),
        Span::styled("[+/-] ", Theme::style_key_shortcut()),
        Span::styled("Zoom  ", Theme::style_muted_text()),
        Span::styled("[0/r] ", Theme::style_key_shortcut()),
        Span::styled("Reset  ", Theme::style_muted_text()),
        Span::styled("[Esc/q/b] ", Theme::style_key_shortcut()),
        Span::styled("Close", Theme::style_muted_text()),
    ]);
    let guide_p = Paragraph::new(guide_line).alignment(Alignment::Center);
    frame.render_widget(guide_p, area);
}
